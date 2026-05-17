import Foundation
import SwiftData

@Model
final class ProcedureCategory {
    var id: UUID = UUID()
    var name: String = ""
    var systemImage: String = "folder.fill"
    var sortOrder: Int = 0
    var isDefault: Bool = false
    var emoji: String? = nil

    @Relationship(deleteRule: .nullify)
    var checklists: [Checklist]? = []

    init(
        name: String = "",
        systemImage: String = "folder.fill",
        sortOrder: Int = 0,
        isDefault: Bool = false,
        emoji: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.systemImage = systemImage
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.emoji = emoji
    }
}
