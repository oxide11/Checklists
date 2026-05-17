import Testing
import Foundation
import SwiftData
@testable import Proceed

// MARK: - Folder/Category/Equipment delete rules

@Suite("Relationship Delete Rules")
@MainActor
struct RelationshipDeleteRuleTests {

    @Test("Deleting a Folder nullifies the back-pointer on its checklists")
    func folderDeleteNullifies() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let folder = Folder(name: "Bin")
        context.insert(folder)
        let checklist = Checklist(title: "Inside")
        checklist.folder = folder
        context.insert(checklist)
        try context.save()

        context.delete(folder)
        try context.save()

        let stored = try context.fetch(FetchDescriptor<Checklist>())
        #expect(stored.count == 1)
        #expect(stored[0].folder == nil)
    }

    @Test("Deleting a Category nullifies the back-pointer on its checklists")
    func categoryDeleteNullifies() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let category = ProcedureCategory(name: "Safety")
        context.insert(category)
        let checklist = Checklist(title: "In category")
        checklist.category = category
        context.insert(checklist)
        try context.save()

        context.delete(category)
        try context.save()

        let stored = try context.fetch(FetchDescriptor<Checklist>())
        #expect(stored.count == 1)
        #expect(stored[0].category == nil)
    }

    @Test("Deleting Equipment removes it from the checklist's required items")
    func equipmentDeleteRemovesLink() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let wrench = Equipment(name: "Wrench")
        context.insert(wrench)
        let checklist = Checklist(title: "Needs wrench")
        context.insert(checklist)
        checklist.requiredEquipmentItems = [wrench]
        try context.save()

        context.delete(wrench)
        try context.save()

        let stored = try context.fetch(FetchDescriptor<Checklist>())
        #expect(stored.count == 1)
        #expect(stored[0].safeEquipmentItems.isEmpty)
    }
}

// MARK: - Workflow entity

@Suite("Workflow Model")
@MainActor
struct WorkflowModelTests {

    @Test("createWorkflow groups procedures and assigns order")
    func createWorkflowAssignsOrder() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let a = Checklist(title: "A")
        let b = Checklist(title: "B")
        let c = Checklist(title: "C")
        context.insert(a); context.insert(b); context.insert(c)

        let workflow = Checklist.createWorkflow(name: "Startup", procedures: [a, b, c], in: context)
        try context.save()

        #expect(a.workflow?.id == workflow.id)
        #expect(a.workflowOrder == 0)
        #expect(b.workflowOrder == 1)
        #expect(c.workflowOrder == 2)
        #expect(workflow.orderedProcedures.map(\.title) == ["A", "B", "C"])
    }

    @Test("removeFromWorkflow deletes the workflow when it becomes empty")
    func removeFromWorkflowDeletesEmpty() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let only = Checklist(title: "Solo")
        context.insert(only)
        _ = Checklist.createWorkflow(name: "Tiny", procedures: [only], in: context)
        try context.save()

        only.removeFromWorkflow(in: context)
        try context.save()

        let workflows = try context.fetch(FetchDescriptor<Workflow>())
        #expect(workflows.isEmpty)
        #expect(only.workflow == nil)
    }

    @Test("Deleting a Workflow does not delete its procedures")
    func deletingWorkflowKeepsProcedures() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let a = Checklist(title: "A")
        let b = Checklist(title: "B")
        context.insert(a); context.insert(b)
        let workflow = Checklist.createWorkflow(name: "Pair", procedures: [a, b], in: context)
        try context.save()

        context.delete(workflow)
        try context.save()

        let checklists = try context.fetch(FetchDescriptor<Checklist>())
        #expect(checklists.count == 2)
        #expect(checklists.allSatisfy { $0.workflow == nil })
    }
}
