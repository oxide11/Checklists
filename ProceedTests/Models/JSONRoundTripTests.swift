import Testing
import Foundation
@testable import Proceed

// MARK: - Checklist.requiredEquipment JSON Round-Trip

@Suite("Checklist.requiredEquipment JSON")
@MainActor
struct ChecklistRequiredEquipmentTests {

    @Test("Empty array round-trip")
    func emptyArray() {
        let checklist = Checklist(title: "Test")
        checklist.requiredEquipment = []
        #expect(checklist.requiredEquipment.isEmpty)
    }

    @Test("Non-empty array round-trip")
    func nonEmptyArray() {
        let checklist = Checklist(title: "Test")
        checklist.requiredEquipment = ["Wrench", "Hammer", "Safety goggles"]
        #expect(checklist.requiredEquipment == ["Wrench", "Hammer", "Safety goggles"])
    }

    @Test("Nil data returns empty array")
    func nilData() {
        let checklist = Checklist(title: "Test")
        checklist.requiredEquipmentData = nil
        #expect(checklist.requiredEquipment.isEmpty)
    }

    @Test("Corrupted data returns empty array")
    func corruptedData() {
        let checklist = Checklist(title: "Test")
        checklist.requiredEquipmentData = Data("not json".utf8)
        #expect(checklist.requiredEquipment.isEmpty)
    }

    @Test("Special characters preserved")
    func specialCharacters() {
        let checklist = Checklist(title: "Test")
        let items = ["Tool (3/8\")", "Résistance côté", "日本語", "emoji 🔧"]
        checklist.requiredEquipment = items
        #expect(checklist.requiredEquipment == items)
    }
}

// MARK: - ChecklistStep.branchOptions JSON Round-Trip

@Suite("ChecklistStep.branchOptions JSON")
@MainActor
struct StepBranchOptionsTests {

    @Test("Empty array round-trip")
    func emptyArray() {
        let step = ChecklistStep(stepType: .decision, text: "Choose")
        step.branchOptions = []
        #expect(step.branchOptions.isEmpty)
    }

    @Test("Options with targetStepID round-trip")
    func withTargetStepID() {
        let step = ChecklistStep(stepType: .decision, text: "Choose")
        let targetID = UUID()
        step.branchOptions = [BranchOption(label: "Yes", targetStepID: targetID)]
        let loaded = step.branchOptions
        #expect(loaded.count == 1)
        #expect(loaded[0].label == "Yes")
        #expect(loaded[0].targetStepID == targetID)
    }

    @Test("Options with nil targetStepID round-trip")
    func withNilTarget() {
        let step = ChecklistStep(stepType: .decision, text: "Choose")
        step.branchOptions = [BranchOption(label: "Unlinked", targetStepID: nil)]
        let loaded = step.branchOptions
        #expect(loaded.count == 1)
        #expect(loaded[0].targetStepID == nil)
    }

    @Test("Multiple options preserve order")
    func multipleOptionsOrder() {
        let step = ChecklistStep(stepType: .decision, text: "Choose")
        let options = [
            BranchOption(label: "Alpha", targetStepID: nil),
            BranchOption(label: "Bravo", targetStepID: nil),
            BranchOption(label: "Charlie", targetStepID: nil)
        ]
        step.branchOptions = options
        let loaded = step.branchOptions
        #expect(loaded.count == 3)
        #expect(loaded[0].label == "Alpha")
        #expect(loaded[1].label == "Bravo")
        #expect(loaded[2].label == "Charlie")
    }

    @Test("Nil data returns empty array")
    func nilData() {
        let step = ChecklistStep(stepType: .decision, text: "Choose")
        step.branchOptionsData = nil
        #expect(step.branchOptions.isEmpty)
    }

    @Test("Corrupted data returns empty array")
    func corruptedData() {
        let step = ChecklistStep(stepType: .decision, text: "Choose")
        step.branchOptionsData = Data("bad json".utf8)
        #expect(step.branchOptions.isEmpty)
    }
}

// MARK: - ChecklistStep.requiredEquipmentIDs JSON Round-Trip

@Suite("ChecklistStep.requiredEquipmentIDs JSON")
@MainActor
struct StepEquipmentIDsTests {

    @Test("UUID array round-trip")
    func uuidArrayRoundTrip() {
        let step = ChecklistStep(stepType: .action, text: "Step")
        let ids = [UUID(), UUID(), UUID()]
        step.requiredEquipmentIDs = ids
        #expect(step.requiredEquipmentIDs == ids)
    }

    @Test("Empty array round-trip")
    func emptyArray() {
        let step = ChecklistStep(stepType: .action, text: "Step")
        step.requiredEquipmentIDs = []
        #expect(step.requiredEquipmentIDs.isEmpty)
    }

    @Test("Nil data returns empty array")
    func nilData() {
        let step = ChecklistStep(stepType: .action, text: "Step")
        step.requiredEquipmentIDsData = nil
        #expect(step.requiredEquipmentIDs.isEmpty)
    }
}

// MARK: - ChangeLogEntry.fieldChanges JSON Round-Trip

@Suite("ChangeLogEntry.fieldChanges JSON")
@MainActor
struct ChangeLogFieldChangesTests {

    @Test("Single entry round-trip")
    func singleEntry() {
        let entry = ChangeLogEntry(changeType: .edited, summary: "Test", authorName: "Tester")
        entry.fieldChanges = [FieldChange(fieldName: "Title", oldValue: "A", newValue: "B")]
        let loaded = entry.fieldChanges
        #expect(loaded.count == 1)
        #expect(loaded[0].fieldName == "Title")
        #expect(loaded[0].oldValue == "A")
        #expect(loaded[0].newValue == "B")
    }

    @Test("Multiple entries preserve order")
    func multipleEntries() {
        let entry = ChangeLogEntry(changeType: .edited, summary: "Test", authorName: "Tester")
        let changes = [
            FieldChange(fieldName: "Title", oldValue: "A", newValue: "B"),
            FieldChange(fieldName: "Emergency", oldValue: "false", newValue: "true"),
            FieldChange(fieldName: "Steps", oldValue: "3 steps", newValue: "5 steps")
        ]
        entry.fieldChanges = changes
        let loaded = entry.fieldChanges
        #expect(loaded.count == 3)
        #expect(loaded[0].fieldName == "Title")
        #expect(loaded[1].fieldName == "Emergency")
        #expect(loaded[2].fieldName == "Steps")
    }

    @Test("Nil data returns empty array")
    func nilData() {
        let entry = ChangeLogEntry(changeType: .edited, summary: "Test", authorName: "Tester")
        entry.fieldChangesData = nil
        #expect(entry.fieldChanges.isEmpty)
    }
}
