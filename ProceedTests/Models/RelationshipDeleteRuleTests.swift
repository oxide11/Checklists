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
