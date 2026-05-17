import Foundation
import SwiftData

// MARK: - Editable Checklist

/// Lightweight value-type mirror of `Checklist` used as @State in editors.
/// Only persisted to SwiftData on explicit save. Equatable so the editor can
/// detect unsaved changes against the originally-loaded snapshot.
struct EditableChecklist: Equatable {
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
        validationError == nil
    }

    /// Human-readable validation error for the Save button's disabled-state
    /// tooltip / future inline display. Nil when the procedure is savable.
    var validationError: String? {
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Procedure needs a title"
        }
        if steps.isEmpty {
            return "Add at least one step"
        }
        // Decision steps must have at least one branch with a target — otherwise
        // the operator hits a dead end at runtime with no way to advance.
        for (index, step) in steps.enumerated() where step.stepType == .decision {
            let hasUsableBranch = step.branchOptions.contains { option in
                option.targetStepID != nil
                    && !option.label.trimmingCharacters(in: .whitespaces).isEmpty
            }
            if !hasUsableBranch {
                return "Decision step \(index + 1) needs at least one labeled branch with a target"
            }
        }
        return nil
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

        // Partial-update step graph: reuse existing ChecklistStep instances by
        // id so a small edit produces a small set of CloudKit updates instead
        // of a full delete-and-recreate. Steps no longer present in the
        // editable list are deleted (cascading to their media).
        let existingStepsByID: [UUID: ChecklistStep] = Dictionary(
            uniqueKeysWithValues: checklist.safeSteps.map { ($0.id, $0) }
        )
        let editableStepIDs = Set(steps.map(\.id))

        for (id, existingStep) in existingStepsByID where !editableStepIDs.contains(id) {
            context.delete(existingStep)
        }

        for (index, editable) in steps.enumerated() {
            let step: ChecklistStep
            if let reused = existingStepsByID[editable.id] {
                step = reused
            } else {
                step = ChecklistStep()
                step.id = editable.id
                step.checklist = checklist
                context.insert(step)
            }

            step.stepType = editable.stepType
            step.text = editable.text
            step.orderIndex = index
            step.note = editable.note.isEmpty ? nil : editable.note
            step.nextStepID = index + 1 < steps.count ? steps[index + 1].id : nil

            // Decision-specific — clear when the type was changed away from decision.
            if editable.stepType == .decision {
                step.question = editable.question.isEmpty ? nil : editable.question
                step.branchOptions = editable.branchOptions.map {
                    BranchOption(id: $0.id, label: $0.label, targetStepID: $0.targetStepID)
                }
            } else {
                step.question = nil
                step.branchOptions = []
            }

            step.requiresAcknowledgment = editable.requiresAcknowledgment
            step.timerDuration = editable.timerDuration
            step.hardwarePartLink = editable.hardwarePartLink.isEmpty ? nil : editable.hardwarePartLink
            step.isCriticalFailure = editable.isCriticalFailure
            step.requiredEquipmentIDs = editable.requiredEquipmentIDs
            step.referenceFileData = editable.referenceFileData
            step.referenceFileName = editable.referenceFileName.isEmpty ? nil : editable.referenceFileName

            // Media attachments — same id-keyed diff so the externalStorage
            // blobs that didn't change aren't rewritten.
            let existingMediaByID: [UUID: MediaAttachment] = Dictionary(
                uniqueKeysWithValues: step.safeMediaAttachments.map { ($0.id, $0) }
            )
            let editableMediaIDs = Set(editable.mediaAttachments.map(\.id))

            for (id, media) in existingMediaByID where !editableMediaIDs.contains(id) {
                context.delete(media)
            }

            for editableMedia in editable.mediaAttachments {
                let media: MediaAttachment
                if let reused = existingMediaByID[editableMedia.id] {
                    media = reused
                } else {
                    media = MediaAttachment()
                    media.id = editableMedia.id
                    media.step = step
                    context.insert(media)
                }
                media.mediaType = editableMedia.mediaType
                media.fileName = editableMedia.fileName
                media.fileData = editableMedia.fileData
                media.caption = editableMedia.caption.isEmpty ? nil : editableMedia.caption
            }
        }

        // If checklist has approvers and this is an update, set to draft for review
        if isUpdate {
            let hasApprovers = checklist.safeRoles.contains { $0.role == .approver }
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

struct EditableStep: Identifiable, Equatable {
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

struct EditableBranchOption: Identifiable, Equatable {
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

struct EditableMediaAttachment: Identifiable, Equatable {
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
