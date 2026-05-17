import Foundation
import SwiftData

@Model
final class Workflow {
    var id: UUID = UUID()
    var name: String = ""
    var sortOrder: Int = 0
    var createdDate: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Checklist.workflow)
    var procedures: [Checklist]? = []

    var safeProcedures: [Checklist] { procedures ?? [] }

    var orderedProcedures: [Checklist] {
        safeProcedures.sorted { $0.workflowOrder < $1.workflowOrder }
    }

    init(name: String = "", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.sortOrder = sortOrder
        self.createdDate = Date()
    }
}
