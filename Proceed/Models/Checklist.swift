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
    var status: String = "published"  // draft, pendingReview, approved, rejected, published

    // Relationships
    @Relationship(inverse: \ProcedureCategory.checklists)
    var category: ProcedureCategory? = nil
    var folder: Folder? = nil

    @Relationship(deleteRule: .cascade, inverse: \ChecklistStep.checklist)
    var steps: [ChecklistStep]? = []

    @Relationship
    var requiredEquipmentItems: [Equipment]? = []

    @Relationship(deleteRule: .cascade, inverse: \ChangeLogEntry.checklist)
    var changeLog: [ChangeLogEntry]? = []

    @Relationship(deleteRule: .cascade, inverse: \IssueReport.checklist)
    var issueReports: [IssueReport]? = []

    @Relationship(deleteRule: .cascade, inverse: \ProcedureRole.checklist)
    var roles: [ProcedureRole]? = []

    // Workflow (procedure chaining)
    var workflowID: UUID? = nil
    var workflowOrder: Int = 0
    var workflowName: String? = nil

    var isInWorkflow: Bool { workflowID != nil }

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

    // MARK: - Safe Relationship Accessors (nil-coalescing for SwiftData optionals)

    var safeSteps: [ChecklistStep] { steps ?? [] }
    var safeRoles: [ProcedureRole] { roles ?? [] }
    var safeChangeLog: [ChangeLogEntry] { changeLog ?? [] }
    var safeIssueReports: [IssueReport] { issueReports ?? [] }
    var safeEquipmentItems: [Equipment] { requiredEquipmentItems ?? [] }

    var hasPreparation: Bool {
        if let notes = preparationNotes, !notes.isEmpty { return true }
        if !requiredEquipment.isEmpty { return true }
        if !safeEquipmentItems.isEmpty { return true }
        return false
    }

    var procedureStatus: ProcedureStatus {
        get { ProcedureStatus(rawValue: status) ?? .published }
        set { status = newValue.rawValue }
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
        safeSteps.sorted { $0.orderIndex < $1.orderIndex }
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

    // MARK: - Workflow Helpers

    static func createWorkflow(name: String, procedures: [Checklist]) {
        let id = UUID()
        for (index, procedure) in procedures.enumerated() {
            procedure.workflowID = id
            procedure.workflowOrder = index
            procedure.workflowName = name
        }
    }

    func removeFromWorkflow() {
        workflowID = nil
        workflowOrder = 0
        workflowName = nil
    }
}
