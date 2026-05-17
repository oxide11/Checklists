import Foundation
import SwiftData

// MARK: - Editable Checklist

/// Lightweight value-type mirror of `Checklist` used as @State in editors.
/// Only persisted to SwiftData on explicit save.
struct EditableChecklist {
    var title: String = ""
    var categoryID: UUID? = nil
    var folderID: UUID? = nil
    var versionNumber: String = "v1.0"
    var isEmergency: Bool = false
    var steps: [EditableStep] = []
    var preparationNotes: String = ""
    var requiredEquipment: [String] = []

    init() {}

    init(from checklist: Checklist) {
        self.title = checklist.title
        self.categoryID = checklist.category?.id
        self.folderID = checklist.folder?.id
        self.versionNumber = checklist.versionNumber
        self.isEmergency = checklist.isEmergency
        self.steps = checklist.orderedSteps.map { EditableStep(from: $0) }
        self.preparationNotes = checklist.preparationNotes ?? ""
        self.requiredEquipment = checklist.requiredEquipment
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !steps.isEmpty
    }

    /// Parses "vX.Y" and returns (major, minor). Defaults to (1, 0) if unparseable.
    private func parseVersion() -> (Int, Int) {
        let cleaned = versionNumber.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "v", with: "")
            .replacingOccurrences(of: "V", with: "")
        let parts = cleaned.split(separator: ".").compactMap { Int($0) }
        let major = parts.count > 0 ? parts[0] : 1
        let minor = parts.count > 1 ? parts[1] : 0
        return (major, minor)
    }

    mutating func autoIncrementPatch() {
        let (major, minor) = parseVersion()
        versionNumber = "v\(major).\(minor + 1)"
    }

    mutating func bumpMajorVersion() {
        let (major, _) = parseVersion()
        versionNumber = "v\(major + 1).0"
    }

    /// Persists editable state to SwiftData. Pass `existing` to update; nil to create new.
    /// Throws if the underlying ModelContext save fails.
    mutating func save(to context: ModelContext, updating existing: Checklist? = nil) throws {
        let previousVersion = existing?.versionNumber
        let isUpdate = existing != nil
        if isUpdate {
            autoIncrementPatch()
        }

        // Detect field changes for audit log
        var fieldChanges: [FieldChange] = []
        if let existing {
            if existing.title != title {
                fieldChanges.append(FieldChange(fieldName: "Title", oldValue: existing.title, newValue: title))
            }
            if existing.isEmergency != isEmergency {
                fieldChanges.append(FieldChange(fieldName: "Emergency", oldValue: "\(existing.isEmergency)", newValue: "\(isEmergency)"))
            }
            let oldStepCount = existing.orderedSteps.count
            if oldStepCount != steps.count {
                fieldChanges.append(FieldChange(fieldName: "Steps", oldValue: "\(oldStepCount) steps", newValue: "\(steps.count) steps"))
            }
        }

        let checklist: Checklist
        if let existing {
            checklist = existing
            // Remove old steps (cascade deletes media attachments)
            for step in existing.orderedSteps {
                context.delete(step)
            }
        } else {
            checklist = Checklist()
            context.insert(checklist)
        }

        checklist.title = title
        checklist.versionNumber = versionNumber
        checklist.isEmergency = isEmergency
        checklist.lastUpdatedDate = Date()
        checklist.preparationNotes = preparationNotes.isEmpty ? nil : preparationNotes
        checklist.requiredEquipment = requiredEquipment.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        // Resolve category by ID
        if let categoryID {
            let descriptor = FetchDescriptor<ProcedureCategory>(predicate: #Predicate { $0.id == categoryID })
            checklist.category = try? context.fetch(descriptor).first
        } else {
            checklist.category = nil
        }

        // Resolve folder by ID
        if let folderID {
            let descriptor = FetchDescriptor<Folder>(predicate: #Predicate { $0.id == folderID })
            checklist.folder = try? context.fetch(descriptor).first
        } else {
            checklist.folder = nil
        }

        // Create fresh steps with preserved IDs for branch targeting
        for (index, editable) in steps.enumerated() {
            let step = ChecklistStep(
                stepType: editable.stepType,
                text: editable.text,
                orderIndex: index
            )
            step.id = editable.id
            step.note = editable.note.isEmpty ? nil : editable.note
            step.nextStepID = index + 1 < steps.count ? steps[index + 1].id : nil

            // Decision-specific
            if editable.stepType == .decision {
                step.question = editable.question.isEmpty ? nil : editable.question
                step.branchOptions = editable.branchOptions.map {
                    BranchOption(id: $0.id, label: $0.label, targetStepID: $0.targetStepID)
                }
            }

            step.requiresAcknowledgment = editable.requiresAcknowledgment
            step.timerDuration = editable.timerDuration
            step.hardwarePartLink = editable.hardwarePartLink.isEmpty ? nil : editable.hardwarePartLink
            step.isCriticalFailure = editable.isCriticalFailure
            step.requiredEquipmentIDs = editable.requiredEquipmentIDs
            step.referenceFileData = editable.referenceFileData
            step.referenceFileName = editable.referenceFileName.isEmpty ? nil : editable.referenceFileName
            step.checklist = checklist
            context.insert(step)

            // Media attachments
            for editableMedia in editable.mediaAttachments {
                let attachment = MediaAttachment(
                    mediaType: editableMedia.mediaType,
                    fileName: editableMedia.fileName,
                    fileData: editableMedia.fileData,
                    caption: editableMedia.caption.isEmpty ? nil : editableMedia.caption
                )
                attachment.id = editableMedia.id
                attachment.step = step
                context.insert(attachment)
            }
        }

        // If checklist has approvers and this is an update, set to draft for review
        if isUpdate {
            let hasApprovers = checklist.safeRoles.contains { $0.userRole == .approver }
            if hasApprovers {
                checklist.status = .draft
            }
        }

        // Create change log entry
        let changeType: ChangeType = isUpdate ? .edited : .created
        let summary = isUpdate
            ? (fieldChanges.isEmpty ? "Procedure updated" : fieldChanges.map(\.fieldName).joined(separator: ", ") + " changed")
            : "Procedure created"
        let logEntry = ChangeLogEntry(
            changeType: changeType,
            summary: summary,
            previousVersionNumber: previousVersion,
            newVersionNumber: versionNumber
        )
        logEntry.fieldChanges = fieldChanges
        logEntry.checklist = checklist
        context.insert(logEntry)

        try context.save()
    }
}

// MARK: - Editable Step

struct EditableStep: Identifiable {
    var id: UUID = UUID()
    var stepType: StepType = .action
    var text: String = ""
    var note: String = ""
    var question: String = ""
    var branchOptions: [EditableBranchOption] = []
    var requiresAcknowledgment: Bool = false
    var timerDuration: Double? = nil
    var hardwarePartLink: String = ""
    var isCriticalFailure: Bool = false
    var requiredEquipmentIDs: [UUID] = []
    var referenceFileData: Data? = nil
    var referenceFileName: String = ""
    var mediaAttachments: [EditableMediaAttachment] = []

    init() {}

    init(from step: ChecklistStep) {
        self.id = step.id
        self.stepType = step.stepType
        self.text = step.text
        self.note = step.note ?? ""
        self.question = step.question ?? ""
        self.branchOptions = step.branchOptions.map { EditableBranchOption(from: $0) }
        self.requiresAcknowledgment = step.requiresAcknowledgment
        self.timerDuration = step.timerDuration
        self.hardwarePartLink = step.hardwarePartLink ?? ""
        self.isCriticalFailure = step.isCriticalFailure
        self.requiredEquipmentIDs = step.requiredEquipmentIDs
        self.referenceFileData = step.referenceFileData
        self.referenceFileName = step.referenceFileName ?? ""
        self.mediaAttachments = step.safeMediaAttachments.map { EditableMediaAttachment(from: $0) }
    }
}

// MARK: - Editable Branch Option

struct EditableBranchOption: Identifiable {
    var id: UUID = UUID()
    var label: String = ""
    var targetStepID: UUID? = nil

    init(label: String = "", targetStepID: UUID? = nil) {
        self.label = label
        self.targetStepID = targetStepID
    }

    init(from option: BranchOption) {
        self.id = option.id
        self.label = option.label
        self.targetStepID = option.targetStepID
    }
}

// MARK: - Editable Media Attachment

struct EditableMediaAttachment: Identifiable {
    var id: UUID = UUID()
    var mediaType: MediaType = .image
    var fileName: String = ""
    var fileData: Data? = nil
    var caption: String = ""

    init(mediaType: MediaType = .image, fileName: String = "", fileData: Data? = nil, caption: String = "") {
        self.mediaType = mediaType
        self.fileName = fileName
        self.fileData = fileData
        self.caption = caption
    }

    init(from attachment: MediaAttachment) {
        self.id = attachment.id
        self.mediaType = attachment.mediaType
        self.fileName = attachment.fileName
        self.fileData = attachment.fileData
        self.caption = attachment.caption ?? ""
    }
}
