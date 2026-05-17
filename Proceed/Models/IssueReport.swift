import Foundation
import SwiftData

@Model
final class IssueReport {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var issueDescription: String = ""
    var reason: String = ""
    var severity: IssueSeverity = IssueSeverity.medium
    var stepID: UUID? = nil
    var stepText: String? = nil
    @Attribute(.externalStorage) var photoData: Data? = nil
    var status: IssueStatus = IssueStatus.open
    var authorName: String = ""

    var checklist: Checklist? = nil

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
        self.severity = severity
        self.stepID = stepID
        self.stepText = stepText
        self.authorName = authorName.isEmpty ? ChangeLogEntry.deviceName : authorName
    }
}
