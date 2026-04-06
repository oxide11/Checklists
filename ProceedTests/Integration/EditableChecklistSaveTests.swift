import Testing
import Foundation
import SwiftData
@testable import Proceed

// MARK: - Create Flow

@Suite("EditableChecklist Save — Create")
@MainActor
struct EditableChecklistCreateTests {

    @Test("Saves title and version")
    func savesBasicFields() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        var ec = EditableChecklist()
        ec.title = "New Procedure"
        ec.versionNumber = "v1.0"
        ec.steps = [EditableStep()]
        ec.save(to: context, updating: nil)

        let checklists = try context.fetch(FetchDescriptor<Checklist>())
        #expect(checklists.count == 1)
        #expect(checklists[0].title == "New Procedure")
        #expect(checklists[0].versionNumber == "v1.0")
    }

    @Test("Saves steps with orderIndex")
    func savesStepsWithOrderIndex() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        var step1 = EditableStep()
        step1.text = "First"
        var step2 = EditableStep()
        step2.text = "Second"

        var ec = EditableChecklist()
        ec.title = "Test"
        ec.steps = [step1, step2]
        ec.save(to: context, updating: nil)

        let steps = try context.fetch(FetchDescriptor<ChecklistStep>())
            .sorted { $0.orderIndex < $1.orderIndex }
        #expect(steps.count == 2)
        #expect(steps[0].text == "First")
        #expect(steps[0].orderIndex == 0)
        #expect(steps[1].text == "Second")
        #expect(steps[1].orderIndex == 1)
    }

    @Test("Creates nextStepID chain")
    func createsNextStepIDChain() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        var step1 = EditableStep()
        step1.text = "A"
        var step2 = EditableStep()
        step2.text = "B"
        var step3 = EditableStep()
        step3.text = "C"

        var ec = EditableChecklist()
        ec.title = "Test"
        ec.steps = [step1, step2, step3]
        ec.save(to: context, updating: nil)

        let steps = try context.fetch(FetchDescriptor<ChecklistStep>())
            .sorted { $0.orderIndex < $1.orderIndex }

        #expect(steps[0].nextStepID == steps[1].id)
        #expect(steps[1].nextStepID == steps[2].id)
        #expect(steps[2].nextStepID == nil)
    }

    @Test("Creates ChangeLogEntry with 'created' type")
    func createsChangeLogEntry() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        var ec = EditableChecklist()
        ec.title = "Test"
        ec.steps = [EditableStep()]
        ec.save(to: context, updating: nil)

        let entries = try context.fetch(FetchDescriptor<ChangeLogEntry>())
        #expect(entries.count == 1)
        #expect(entries[0].change == .created)
        #expect(entries[0].summary == "Procedure created")
    }

    @Test("Resolves category by ID")
    func resolvesCategoryByID() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let category = ProcedureCategory(name: "Safety")
        context.insert(category)

        var ec = EditableChecklist()
        ec.title = "Test"
        ec.steps = [EditableStep()]
        ec.categoryID = category.id
        ec.save(to: context, updating: nil)

        let checklists = try context.fetch(FetchDescriptor<Checklist>())
        #expect(checklists[0].category?.name == "Safety")
    }

    @Test("Resolves folder by ID")
    func resolvesFolderByID() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let folder = Folder(name: "Operations")
        context.insert(folder)

        var ec = EditableChecklist()
        ec.title = "Test"
        ec.steps = [EditableStep()]
        ec.folderID = folder.id
        ec.save(to: context, updating: nil)

        let checklists = try context.fetch(FetchDescriptor<Checklist>())
        #expect(checklists[0].folder?.name == "Operations")
    }

    @Test("Nil category leaves nil")
    func nilCategoryLeavesNil() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        var ec = EditableChecklist()
        ec.title = "Test"
        ec.steps = [EditableStep()]
        ec.categoryID = nil
        ec.save(to: context, updating: nil)

        let checklists = try context.fetch(FetchDescriptor<Checklist>())
        #expect(checklists[0].category == nil)
    }

    @Test("Strips whitespace-only equipment")
    func stripsWhitespaceEquipment() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        var ec = EditableChecklist()
        ec.title = "Test"
        ec.steps = [EditableStep()]
        ec.requiredEquipment = ["Wrench", "  ", "", "Hammer"]
        ec.save(to: context, updating: nil)

        let checklists = try context.fetch(FetchDescriptor<Checklist>())
        #expect(checklists[0].requiredEquipment == ["Wrench", "Hammer"])
    }
}

// MARK: - Update Flow

@Suite("EditableChecklist Save — Update")
@MainActor
struct EditableChecklistUpdateTests {

    @Test("Auto-increments patch version")
    func autoIncrementsPatch() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let existing = Checklist(title: "Old", versionNumber: "v1.0")
        context.insert(existing)

        var ec = EditableChecklist(from: existing)
        ec.steps = [EditableStep()]
        ec.save(to: context, updating: existing)

        #expect(existing.versionNumber == "v1.1")
    }

    @Test("Replaces old steps with new")
    func replacesOldSteps() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let existing = Checklist(title: "Test")
        context.insert(existing)
        let oldStep = ChecklistStep(stepType: .action, text: "Old step", orderIndex: 0)
        oldStep.checklist = existing
        context.insert(oldStep)
        existing.steps = [oldStep]

        var ec = EditableChecklist(from: existing)
        var newStep = EditableStep()
        newStep.text = "New step"
        ec.steps = [newStep]
        ec.save(to: context, updating: existing)

        let steps = try context.fetch(FetchDescriptor<ChecklistStep>())
            .filter { $0.checklist?.id == existing.id }
        #expect(steps.count == 1)
        #expect(steps[0].text == "New step")
    }

    @Test("Sets status to draft when approver present")
    func setsDraftWithApprover() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let existing = Checklist(title: "Test")
        existing.status = ProcedureStatus.published.rawValue
        context.insert(existing)

        let role = ProcedureRole(userIdentifier: "user1", displayName: "Approver", role: .approver)
        role.checklist = existing
        context.insert(role)
        existing.roles = [role]

        var ec = EditableChecklist(from: existing)
        ec.steps = [EditableStep()]
        ec.save(to: context, updating: existing)

        #expect(existing.status == ProcedureStatus.draft.rawValue)
    }

    @Test("Does NOT change status without approver")
    func doesNotChangeStatusWithoutApprover() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let existing = Checklist(title: "Test")
        existing.status = ProcedureStatus.published.rawValue
        context.insert(existing)
        existing.roles = []

        var ec = EditableChecklist(from: existing)
        ec.steps = [EditableStep()]
        ec.save(to: context, updating: existing)

        #expect(existing.status == ProcedureStatus.published.rawValue)
    }

    @Test("Creates ChangeLogEntry with field changes")
    func createsChangeLogWithFieldChanges() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let existing = Checklist(title: "Old Title")
        context.insert(existing)

        var ec = EditableChecklist(from: existing)
        ec.title = "New Title"
        ec.steps = [EditableStep()]
        ec.save(to: context, updating: existing)

        let entries = try context.fetch(FetchDescriptor<ChangeLogEntry>())
        #expect(entries.count == 1)
        #expect(entries[0].change == .edited)
        #expect(entries[0].summary.contains("Title"))
    }

    @Test("Preserves step IDs for branch targeting")
    func preservesStepIDs() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let existing = Checklist(title: "Test")
        context.insert(existing)

        let specificID = UUID()
        var editableStep = EditableStep()
        editableStep.id = specificID
        editableStep.text = "Targeted step"

        var ec = EditableChecklist(from: existing)
        ec.steps = [editableStep]
        ec.save(to: context, updating: existing)

        let steps = try context.fetch(FetchDescriptor<ChecklistStep>())
            .filter { $0.checklist?.id == existing.id }
        #expect(steps.count == 1)
        #expect(steps[0].id == specificID)
    }
}
