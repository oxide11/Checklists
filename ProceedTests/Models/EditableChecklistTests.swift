import Testing
import Foundation
@testable import Proceed

// MARK: - EditableChecklist.isValid

@Suite("EditableChecklist.isValid")
struct EditableChecklistIsValidTests {

    @Test("Valid with title and steps")
    func validWithTitleAndSteps() {
        var ec = EditableChecklist()
        ec.title = "My Procedure"
        ec.steps = [EditableStep()]
        #expect(ec.isValid == true)
    }

    @Test("Invalid with empty title")
    func invalidEmptyTitle() {
        var ec = EditableChecklist()
        ec.title = ""
        ec.steps = [EditableStep()]
        #expect(ec.isValid == false)
    }

    @Test("Invalid with whitespace-only title")
    func invalidWhitespaceTitle() {
        var ec = EditableChecklist()
        ec.title = "   "
        ec.steps = [EditableStep()]
        #expect(ec.isValid == false)
    }

    @Test("Invalid with no steps")
    func invalidNoSteps() {
        var ec = EditableChecklist()
        ec.title = "Has Title"
        ec.steps = []
        #expect(ec.isValid == false)
    }

    @Test("Invalid with both empty")
    func invalidBothEmpty() {
        let ec = EditableChecklist()
        #expect(ec.isValid == false)
    }

    @Test("Invalid when a decision step has no targeted branch")
    func invalidDecisionWithoutTargetedBranch() {
        var decision = EditableStep()
        decision.stepType = .decision
        decision.text = "Pick"
        decision.branchOptions = [
            EditableBranchOption(label: "Yes"),
            EditableBranchOption(label: "No")
        ]
        var ec = EditableChecklist()
        ec.title = "Test"
        ec.steps = [decision]
        #expect(ec.isValid == false)
        #expect(ec.validationError?.contains("Decision step") == true)
    }

    @Test("Valid when a decision step has at least one targeted, labeled branch")
    func validDecisionWithTargetedBranch() {
        let targetID = UUID()
        var target = EditableStep()
        target.id = targetID
        target.text = "Target"

        var decision = EditableStep()
        decision.stepType = .decision
        decision.text = "Pick"
        decision.branchOptions = [
            EditableBranchOption(label: "Go", targetStepID: targetID),
            EditableBranchOption(label: "Stay")  // unlabeled-target branch is fine if another has one
        ]
        var ec = EditableChecklist()
        ec.title = "Test"
        ec.steps = [decision, target]
        #expect(ec.isValid == true)
    }
}

// MARK: - EditableChecklist.autoIncrementPatch

@Suite("EditableChecklist.autoIncrementPatch")
struct AutoIncrementPatchTests {

    @Test("v1.0 becomes v1.1")
    func v1_0() {
        var ec = EditableChecklist()
        ec.versionNumber = "v1.0"
        ec.autoIncrementPatch()
        #expect(ec.versionNumber == "v1.1")
    }

    @Test("v1.9 becomes v1.10")
    func v1_9() {
        var ec = EditableChecklist()
        ec.versionNumber = "v1.9"
        ec.autoIncrementPatch()
        #expect(ec.versionNumber == "v1.10")
    }

    @Test("Capital V handled")
    func capitalV() {
        var ec = EditableChecklist()
        ec.versionNumber = "V2.3"
        ec.autoIncrementPatch()
        #expect(ec.versionNumber == "v2.4")
    }

    @Test("Bad format defaults to v1.1")
    func badFormat() {
        var ec = EditableChecklist()
        ec.versionNumber = "garbage"
        ec.autoIncrementPatch()
        #expect(ec.versionNumber == "v1.1")
    }

    @Test("Missing minor defaults to v1.1")
    func missingMinor() {
        var ec = EditableChecklist()
        ec.versionNumber = "v1"
        ec.autoIncrementPatch()
        #expect(ec.versionNumber == "v1.1")
    }
}

// MARK: - EditableChecklist.bumpMajorVersion

@Suite("EditableChecklist.bumpMajorVersion")
struct BumpMajorVersionTests {

    @Test("v1.9 becomes v2.0")
    func v1_9() {
        var ec = EditableChecklist()
        ec.versionNumber = "v1.9"
        ec.bumpMajorVersion()
        #expect(ec.versionNumber == "v2.0")
    }

    @Test("v2.5 becomes v3.0")
    func v2_5() {
        var ec = EditableChecklist()
        ec.versionNumber = "v2.5"
        ec.bumpMajorVersion()
        #expect(ec.versionNumber == "v3.0")
    }

    @Test("v1.0 becomes v2.0")
    func v1_0() {
        var ec = EditableChecklist()
        ec.versionNumber = "v1.0"
        ec.bumpMajorVersion()
        #expect(ec.versionNumber == "v2.0")
    }

    @Test("Capital V handled")
    func capitalV() {
        var ec = EditableChecklist()
        ec.versionNumber = "V3.2"
        ec.bumpMajorVersion()
        #expect(ec.versionNumber == "v4.0")
    }

    @Test("Bad format defaults to v2.0")
    func badFormat() {
        var ec = EditableChecklist()
        ec.versionNumber = "xyz"
        ec.bumpMajorVersion()
        #expect(ec.versionNumber == "v2.0")
    }
}

// MARK: - EditableChecklist init from Checklist

@Suite("EditableChecklist init from Checklist")
@MainActor
struct EditableChecklistInitTests {

    @Test("Preserves title, version, emergency flag")
    func preservesBasicFields() {
        let checklist = Checklist(title: "My Proc", versionNumber: "v3.2", isEmergency: true)
        let ec = EditableChecklist(from: checklist)
        #expect(ec.title == "My Proc")
        #expect(ec.versionNumber == "v3.2")
        #expect(ec.isEmergency == true)
    }

    @Test("Maps steps in order")
    func mapsStepsInOrder() {
        let step1 = ChecklistStep(stepType: .action, text: "First", orderIndex: 0)
        let step2 = ChecklistStep(stepType: .warning, text: "Second", orderIndex: 1)
        let checklist = makeChecklist(steps: [step1, step2])
        let ec = EditableChecklist(from: checklist)
        #expect(ec.steps.count == 2)
        #expect(ec.steps[0].text == "First")
        #expect(ec.steps[1].text == "Second")
    }

    @Test("Preserves step IDs")
    func preservesStepIDs() {
        let step = ChecklistStep(stepType: .action, text: "Step")
        let originalID = step.id
        let checklist = makeChecklist(steps: [step])
        let ec = EditableChecklist(from: checklist)
        #expect(ec.steps[0].id == originalID)
    }

    @Test("Maps preparation notes")
    func mapsPreparationNotes() {
        let checklist = Checklist(title: "Test")
        checklist.preparationNotes = "Wear PPE"
        let ec = EditableChecklist(from: checklist)
        #expect(ec.preparationNotes == "Wear PPE")
    }

    @Test("Nil preparation notes becomes empty string")
    func nilNotesBecomesEmpty() {
        let checklist = Checklist(title: "Test")
        checklist.preparationNotes = nil
        let ec = EditableChecklist(from: checklist)
        #expect(ec.preparationNotes == "")
    }
}
