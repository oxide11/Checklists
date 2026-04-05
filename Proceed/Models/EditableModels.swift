import Foundation
import SwiftData

// MARK: - Editable Checklist

/// Lightweight value-type mirror of `Checklist` used as @State in editors.
/// Only persisted to SwiftData on explicit save.
struct EditableChecklist {
    var title: String = ""
    var category: ChecklistCategory = .custom
    var versionNumber: String = "v1.0"
    var isEmergency: Bool = false
    var steps: [EditableStep] = []

    init() {}

    init(from checklist: Checklist) {
        self.title = checklist.title
        self.category = checklist.category
        self.versionNumber = checklist.versionNumber
        self.isEmergency = checklist.isEmergency
        self.steps = checklist.orderedSteps.map { EditableStep(from: $0) }
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !steps.isEmpty
    }

    /// Persists editable state to SwiftData. Pass `existing` to update; nil to create new.
    func save(to context: ModelContext, updating existing: Checklist? = nil) {
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
        checklist.category = category
        checklist.versionNumber = versionNumber
        checklist.isEmergency = isEmergency
        checklist.lastUpdatedDate = Date()

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
        self.mediaAttachments = (step.mediaAttachments ?? []).map { EditableMediaAttachment(from: $0) }
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
