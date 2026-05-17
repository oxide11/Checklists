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
    var status: ProcedureStatus = ProcedureStatus.published

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
    var workflow: Workflow? = nil
    var workflowOrder: Int = 0

    var isInWorkflow: Bool { workflow != nil }

    // Preparation
    var preparationNotes: String? = nil
    var requiredEquipmentData: Data? = nil

    var requiredEquipment: [String] {
        get {
            guard let data = requiredEquipmentData else { return [] }
            do {
                return try JSONDecoder().decode([String].self, from: data)
            } catch {
                ProceedLog.persistence.error("Checklist.requiredEquipment decode failed for \(self.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return []
            }
        }
        set {
            do {
                requiredEquipmentData = try JSONEncoder().encode(newValue)
            } catch {
                ProceedLog.persistence.error("Checklist.requiredEquipment encode failed: \(error.localizedDescription, privacy: .public)")
                requiredEquipmentData = nil
            }
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

    /// Returns true if the procedure hasn't been updated or reviewed in over 12 months.
    var isOutdated: Bool {
        guard let cutoff = Calendar.current.date(byAdding: .month, value: -12, to: Date()) else {
            return false
        }
        return lastReviewedDate < cutoff || lastUpdatedDate < cutoff
    }

    /// Ordered steps sorted by orderIndex, with step id as a deterministic
    /// tiebreaker so concurrent CloudKit edits that collide on orderIndex
    /// don't produce a non-deterministic execution order.
    var orderedSteps: [ChecklistStep] {
        safeSteps.sorted { lhs, rhs in
            if lhs.orderIndex != rhs.orderIndex {
                return lhs.orderIndex < rhs.orderIndex
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
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

    /// Creates a new Workflow grouping the given procedures, in order, and inserts it
    /// into the supplied context. Each procedure's `workflow` and `workflowOrder` are
    /// updated to reflect membership.
    @discardableResult
    static func createWorkflow(
        name: String,
        procedures: [Checklist],
        in context: ModelContext
    ) -> Workflow {
        let workflow = Workflow(name: name)
        context.insert(workflow)
        for (index, procedure) in procedures.enumerated() {
            procedure.workflow = workflow
            procedure.workflowOrder = index
        }
        return workflow
    }

    /// Removes this checklist from its workflow. If the workflow ends up empty, it is
    /// deleted from the supplied context.
    func removeFromWorkflow(in context: ModelContext) {
        let oldWorkflow = workflow
        workflow = nil
        workflowOrder = 0
        if let oldWorkflow, oldWorkflow.safeProcedures.isEmpty {
            context.delete(oldWorkflow)
        }
    }
}
