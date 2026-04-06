import Foundation
import SwiftData

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
            return (try? JSONDecoder().decode([UUID].self, from: data)) ?? []
        }
        set {
            requiredEquipmentIDsData = try? JSONEncoder().encode(newValue)
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
            return (try? JSONDecoder().decode([BranchOption].self, from: data)) ?? []
        }
        set {
            branchOptionsData = try? JSONEncoder().encode(newValue)
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
