import Foundation
import SwiftData

@Model
final class ProcedureRole {
    var id: UUID = UUID()
    var userIdentifier: String = ""
    var displayName: String = ""
    var role: UserRole = UserRole.viewer

    var checklist: Checklist? = nil

    init(
        userIdentifier: String = "",
        displayName: String = "",
        role: UserRole = .viewer
    ) {
        self.id = UUID()
        self.userIdentifier = userIdentifier
        self.displayName = displayName
        self.role = role
    }
}
