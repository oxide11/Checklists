import Foundation
import SwiftData

@Model
final class Checklist {
    var id: UUID = UUID()
    var title: String = ""
    var versionNumber: String = "v1.0"
    var lastUpdatedDate: Date = Date()
    var lastReviewedDate: Date = Date()
    var createdDate: Date = Date()
    var sortOrder: Int = 0
    var isEmergency: Bool = false

    // Relationships
    @Relationship(inverse: \ProcedureCategory.checklists)
    var category: ProcedureCategory? = nil
    var folder: Folder? = nil

    @Relationship(deleteRule: .cascade, inverse: \ChecklistStep.checklist)
    var steps: [ChecklistStep]? = []

    @Relationship
    var requiredEquipmentItems: [Equipment]? = []

    // Preparation
    var preparationNotes: String? = nil
    var requiredEquipmentData: Data? = nil

    var requiredEquipment: [String] {
        get {
            guard let data = requiredEquipmentData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            requiredEquipmentData = try? JSONEncoder().encode(newValue)
        }
    }

    var hasPreparation: Bool {
        (preparationNotes != nil && !preparationNotes!.isEmpty) ||
        !requiredEquipment.isEmpty ||
        !(requiredEquipmentItems ?? []).isEmpty
    }

    /// Returns true if the procedure hasn't been updated or reviewed in over 12 months.
    var isOutdated: Bool {
        guard let cutoff = Calendar.current.date(byAdding: .month, value: -12, to: Date()) else {
            return false
        }
        return lastReviewedDate < cutoff || lastUpdatedDate < cutoff
    }

    /// Ordered steps sorted by orderIndex.
    var orderedSteps: [ChecklistStep] {
        (steps ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    init(
        title: String = "",
        versionNumber: String = "v1.0",
        isEmergency: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.versionNumber = versionNumber
        self.isEmergency = isEmergency
        self.lastUpdatedDate = Date()
        self.lastReviewedDate = Date()
        self.createdDate = Date()
    }
}
