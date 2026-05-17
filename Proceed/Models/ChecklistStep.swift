import Foundation
import SwiftData
import os

@Model
final class ChecklistStep {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var stepType: StepType = StepType.action
    var text: String = ""
    var note: String? = nil
    var nextStepID: UUID? = nil

    // MARK: Decision-specific

    var question: String? = nil
    var branchOptionsData: Data? = nil

    // MARK: Warning / Caution

    var requiresAcknowledgment: Bool = false
    var isAcknowledged: Bool = false

    // MARK: Metadata & Triggers

    var timerDuration: Double? = nil
    var hardwarePartLink: String? = nil
    var isCriticalFailure: Bool = false

    // MARK: Per-Step Equipment
    var requiredEquipmentIDsData: Data? = nil

    var requiredEquipmentIDs: [UUID] {
        get {
            guard let data = requiredEquipmentIDsData else { return [] }
            do {
                return try JSONDecoder().decode([UUID].self, from: data)
            } catch {
                ProceedLog.persistence.error("ChecklistStep.requiredEquipmentIDs decode failed for step \(self.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return []
            }
        }
        set {
            do {
                requiredEquipmentIDsData = try JSONEncoder().encode(newValue)
            } catch {
                ProceedLog.persistence.error("ChecklistStep.requiredEquipmentIDs encode failed: \(error.localizedDescription, privacy: .public)")
                requiredEquipmentIDsData = nil
            }
        }
    }

    // MARK: Reference Files
    @Attribute(.externalStorage) var referenceFileData: Data? = nil
    var referenceFileName: String? = nil

    // MARK: Relationships

    var checklist: Checklist? = nil

    @Relationship(deleteRule: .cascade, inverse: \MediaAttachment.step)
    var mediaAttachments: [MediaAttachment]? = []

    var safeMediaAttachments: [MediaAttachment] { mediaAttachments ?? [] }

    // MARK: Computed — Branch Options

    var branchOptions: [BranchOption] {
        get {
            guard let data = branchOptionsData else { return [] }
            do {
                return try JSONDecoder().decode([BranchOption].self, from: data)
            } catch {
                ProceedLog.persistence.error("ChecklistStep.branchOptions decode failed for step \(self.id, privacy: .public): \(error.localizedDescription, privacy: .public) — branch routing may be lost")
                return []
            }
        }
        set {
            do {
                branchOptionsData = try JSONEncoder().encode(newValue)
            } catch {
                ProceedLog.persistence.error("ChecklistStep.branchOptions encode failed: \(error.localizedDescription, privacy: .public)")
                branchOptionsData = nil
            }
        }
    }

    init(
        stepType: StepType = .action,
        text: String = "",
        orderIndex: Int = 0
    ) {
        self.id = UUID()
        self.stepType = stepType
        self.text = text
        self.orderIndex = orderIndex
    }
}
