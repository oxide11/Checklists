import Foundation
import SwiftData

@Model
final class ProcedureRole {
    var id: UUID = UUID()
    var userIdentifier: String = ""
    var displayName: String = ""
    var role: String = "viewer"  // viewer, editor, approver

    var checklist: Checklist? = nil

    var userRole: UserRole {
        get { UserRole(rawValue: role) ?? .viewer }
        set { role = newValue.rawValue }
    }

    init(
        userIdentifier: String = "",
        displayName: String = "",
        role: UserRole = .viewer
    ) {
        self.id = UUID()
        self.userIdentifier = userIdentifier
        self.displayName = displayName
        self.role = role.rawValue
    }
}
