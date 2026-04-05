import Foundation
import SwiftData

@Model
final class Equipment {
    var id: UUID = UUID()
    var name: String = ""
    var storageLocation: String = ""
    var equipmentCategory: String = ""
    var notes: String? = nil
    var lastInspectedDate: Date? = nil

    @Relationship(inverse: \Checklist.requiredEquipmentItems)
    var checklists: [Checklist]? = []

    init(
        name: String = "",
        storageLocation: String = "",
        equipmentCategory: String = "",
        notes: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.storageLocation = storageLocation
        self.equipmentCategory = equipmentCategory
        self.notes = notes
    }
}
