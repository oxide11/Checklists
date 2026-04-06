import Foundation
import SwiftData

@Model
final class Folder {
    var id: UUID = UUID()
    var name: String = ""
    var systemImage: String = "folder.fill"
    var sortOrder: Int = 0

    @Relationship(inverse: \Checklist.folder)
    var checklists: [Checklist]? = []

    var safeChecklists: [Checklist] { checklists ?? [] }

    init(
        name: String = "",
        systemImage: String = "folder.fill",
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.systemImage = systemImage
        self.sortOrder = sortOrder
    }
}
