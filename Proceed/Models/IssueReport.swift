import Foundation
import SwiftData

@Model
final class IssueReport {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var issueDescription: String = ""
    var reason: String = ""
    var severity: String = IssueSeverity.medium.rawValue
    var stepID: UUID? = nil
    var stepText: String? = nil
    @Attribute(.externalStorage) var photoData: Data? = nil
    var status: String = IssueStatus.open.rawValue
    var authorName: String = ""

    var checklist: Checklist? = nil

    /// Typed access to the issue status
    var issueStatus: IssueStatus {
        get { IssueStatus(rawValue: status) ?? .open }
        set { status = newValue.rawValue }
    }

    /// Typed access to the issue severity
    var issueSeverity: IssueSeverity {
        get { IssueSeverity(rawValue: severity) ?? .medium }
        set { severity = newValue.rawValue }
    }

    init(
        issueDescription: String = "",
        reason: String = "",
        severity: IssueSeverity = .medium,
        stepID: UUID? = nil,
        stepText: String? = nil,
        authorName: String = ""
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.issueDescription = issueDescription
        self.reason = reason
        self.severity = severity.rawValue
        self.stepID = stepID
        self.stepText = stepText
        self.authorName = authorName.isEmpty ? ChangeLogEntry.deviceName : authorName
    }
}
