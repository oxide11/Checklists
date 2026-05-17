import Testing
import Foundation
@testable import Proceed

// MARK: - Initialization

@Suite("ExecutionEngine Initialization")
@MainActor
struct ExecutionEngineInitTests {

    @Test("Empty checklist has no current step and is not complete")
    func emptyChecklist() {
        let checklist = makeChecklist(steps: [])
        let engine = ExecutionEngine(checklist: checklist)
        #expect(engine.currentStepID == nil)
        #expect(engine.isComplete == false)
    }

    @Test("Single step: currentStepID is the step's ID")
    func singleStep() {
        let step = makeActionStep(text: "Only step")
        let checklist = makeChecklist(steps: [step])
        let engine = ExecutionEngine(checklist: checklist)
        #expect(engine.currentStepID == step.id)
        #expect(engine.isComplete == false)
    }

    @Test("Multi-step: currentStepID is first step")
    func multiStep() {
        let step1 = makeActionStep(text: "First")
        let step2 = makeActionStep(text: "Second")
        let step3 = makeActionStep(text: "Third")
        let checklist = makeChecklist(steps: [step1, step2, step3])
        let engine = ExecutionEngine(checklist: checklist)
        #expect(engine.currentStepID == step1.id)
    }
}

// MARK: - Linear Execution

@Suite("ExecutionEngine Linear Execution")
@MainActor
struct ExecutionEngineLinearTests {

    @Test("Complete advances to next step")
    func completeAdvances() {
        let step1 = makeActionStep(text: "First")
        let step2 = makeActionStep(text: "Second")
        let checklist = makeChecklist(steps: [step1, step2])
        let engine = ExecutionEngine(checklist: checklist)

        engine.completeStep(step1.id)
        #expect(engine.currentStepID == step2.id)
        #expect(engine.completedStepIDs.contains(step1.id))
    }

    @Test("Complete last step marks execution complete")
    func completeLastStep() {
        let step1 = makeActionStep(text: "First")
        let step2 = makeActionStep(text: "Last")
        let checklist = makeChecklist(steps: [step1, step2])
        let engine = ExecutionEngine(checklist: checklist)

        engine.completeStep(step1.id)
        engine.completeStep(step2.id)
        #expect(engine.currentStepID == nil)
        #expect(engine.isComplete == true)
    }

    @Test("visibleSteps grows as steps are completed")
    func visibleStepsGrow() {
        let step1 = makeActionStep(text: "A")
        let step2 = makeActionStep(text: "B")
        let step3 = makeActionStep(text: "C")
        let checklist = makeChecklist(steps: [step1, step2, step3])
        let engine = ExecutionEngine(checklist: checklist)

        // Initially only step1 visible (the frontier)
        #expect(engine.visibleSteps.count == 1)
        #expect(engine.visibleSteps[0].id == step1.id)

        engine.completeStep(step1.id)
        #expect(engine.visibleSteps.count == 2)

        engine.completeStep(step2.id)
        #expect(engine.visibleSteps.count == 3)
    }

    @Test("Progress goes from 0 to 1")
    func progressZeroToOne() {
        let step1 = makeActionStep(text: "A")
        let step2 = makeActionStep(text: "B")
        let checklist = makeChecklist(steps: [step1, step2])
        let engine = ExecutionEngine(checklist: checklist)

        #expect(engine.progress == 0.0)

        engine.completeStep(step1.id)
        #expect(engine.progress == 0.5)

        engine.completeStep(step2.id)
        #expect(engine.progress == 1.0)
    }

    @Test("progressLabel format is 'N / M'")
    func progressLabelFormat() {
        let step1 = makeActionStep(text: "A")
        let step2 = makeActionStep(text: "B")
        let step3 = makeActionStep(text: "C")
        let checklist = makeChecklist(steps: [step1, step2, step3])
        let engine = ExecutionEngine(checklist: checklist)

        #expect(engine.progressLabel == "0 / 1")  // Only 1 visible step (frontier)

        engine.completeStep(step1.id)
        #expect(engine.progressLabel == "1 / 2")
    }

    @Test("Unknown step ID is a no-op")
    func unknownStepNoOp() {
        let step = makeActionStep(text: "Only")
        let checklist = makeChecklist(steps: [step])
        let engine = ExecutionEngine(checklist: checklist)

        let unknownID = UUID()
        engine.completeStep(unknownID)
        #expect(engine.currentStepID == step.id)
        #expect(engine.completedStepIDs.isEmpty)
    }
}

// MARK: - Branching Execution

@Suite("ExecutionEngine Branching")
@MainActor
struct ExecutionEngineBranchingTests {

    @Test("selectBranch advances to target step")
    func selectBranchAdvances() {
        let targetStep = makeActionStep(text: "Branch target")
        let decisionStep = makeDecisionStep(
            text: "Choose",
            branchOptions: [BranchOption(label: "Go", targetStepID: targetStep.id)]
        )
        let middleStep = makeActionStep(text: "Not taken")
        let checklist = makeChecklist(steps: [decisionStep, middleStep, targetStep])
        let engine = ExecutionEngine(checklist: checklist)

        engine.selectBranch(on: decisionStep.id, targetStepID: targetStep.id)
        #expect(engine.currentStepID == targetStep.id)
        #expect(engine.completedStepIDs.contains(decisionStep.id))
        #expect(engine.branchSelections[decisionStep.id] == targetStep.id)
    }

    @Test("visibleSteps follows branch path, not linear")
    func visibleFollowsBranch() {
        let targetStep = makeActionStep(text: "Branch target")
        let decisionStep = makeDecisionStep(
            text: "Choose",
            branchOptions: [BranchOption(label: "Go", targetStepID: targetStep.id)]
        )
        let skippedStep = makeActionStep(text: "Skipped")
        let checklist = makeChecklist(steps: [decisionStep, skippedStep, targetStep])
        let engine = ExecutionEngine(checklist: checklist)

        engine.selectBranch(on: decisionStep.id, targetStepID: targetStep.id)
        let visibleTexts = engine.visibleSteps.map(\.text)
        #expect(visibleTexts.contains("Branch target"))
        #expect(!visibleTexts.contains("Skipped"))
    }

    @Test("completeStep on decision is rejected — must use selectBranch")
    func decisionCompleteRejected() {
        let step1 = makeDecisionStep(text: "Choose")
        let step2 = makeActionStep(text: "Next")
        let checklist = makeChecklist(steps: [step1, step2])
        let engine = ExecutionEngine(checklist: checklist)

        engine.completeStep(step1.id)
        // Decision step must be resolved via selectBranch; completeStep is a no-op
        #expect(!engine.completedStepIDs.contains(step1.id))
        #expect(engine.currentStepID == step1.id)
    }

    @Test("selectBranch with unknown decisionStepID is no-op")
    func unknownDecisionNoOp() {
        let step = makeActionStep(text: "Step")
        let checklist = makeChecklist(steps: [step])
        let engine = ExecutionEngine(checklist: checklist)

        engine.selectBranch(on: UUID(), targetStepID: UUID())
        #expect(engine.currentStepID == step.id)
        #expect(engine.branchSelections.isEmpty)
    }

    @Test("Cycle guard prevents infinite loop in visibleSteps")
    func cycleGuard() {
        // Create a step that branches to itself
        let step = makeDecisionStep(text: "Loop")
        let checklist = makeChecklist(steps: [step])
        let engine = ExecutionEngine(checklist: checklist)

        // Select branch targeting the same step
        engine.selectBranch(on: step.id, targetStepID: step.id)
        // Should not hang — visited set prevents re-processing
        let visible = engine.visibleSteps
        #expect(visible.count <= 1)
    }
}

// MARK: - Reset

@Suite("ExecutionEngine Reset")
@MainActor
struct ExecutionEngineResetTests {

    @Test("Reset clears state and returns to first step")
    func resetClearsState() {
        let step1 = makeActionStep(text: "A")
        let step2 = makeActionStep(text: "B")
        let checklist = makeChecklist(steps: [step1, step2])
        let engine = ExecutionEngine(checklist: checklist)

        engine.completeStep(step1.id)
        #expect(engine.currentStepID == step2.id)

        engine.reset()
        #expect(engine.currentStepID == step1.id)
        #expect(engine.completedStepIDs.isEmpty)
        #expect(engine.branchSelections.isEmpty)
    }

    @Test("Reset after completion restores progress to 0")
    func resetAfterCompletion() {
        let step = makeActionStep(text: "Only")
        let checklist = makeChecklist(steps: [step])
        let engine = ExecutionEngine(checklist: checklist)

        engine.completeStep(step.id)
        #expect(engine.isComplete == true)

        engine.reset()
        #expect(engine.isComplete == false)
        #expect(engine.progress == 0.0)
    }

    @Test("Reset on empty checklist is safe")
    func resetEmptyChecklist() {
        let checklist = makeChecklist(steps: [])
        let engine = ExecutionEngine(checklist: checklist)

        engine.reset()
        #expect(engine.currentStepID == nil)
        #expect(engine.completedStepIDs.isEmpty)
    }
}

// MARK: - Decision Gating

@Suite("ExecutionEngine Decision Gating")
@MainActor
struct ExecutionEngineDecisionGatingTests {

    @Test("Decision is still resolvable via selectBranch after a completeStep attempt")
    func decisionStillResolvableAfterCompleteAttempt() {
        let target = makeActionStep(text: "Target")
        let decision = makeDecisionStep(
            text: "Pick",
            branchOptions: [BranchOption(label: "Go", targetStepID: target.id)]
        )
        let checklist = makeChecklist(steps: [decision, target])
        let engine = ExecutionEngine(checklist: checklist)

        engine.completeStep(decision.id)  // rejected
        engine.selectBranch(on: decision.id, targetStepID: target.id)
        #expect(engine.currentStepID == target.id)
        #expect(engine.completedStepIDs.contains(decision.id))
    }
}

// MARK: - Source-Change Detection

@Suite("ExecutionEngine Source Change")
@MainActor
struct ExecutionEngineSourceChangeTests {

    @Test("sourceHasChanged is false right after init")
    func initiallyUnchanged() {
        let checklist = makeChecklist(steps: [makeActionStep()])
        let engine = ExecutionEngine(checklist: checklist)
        #expect(engine.sourceHasChanged == false)
    }

    @Test("Mutating checklist.versionNumber flips sourceHasChanged")
    func versionBumpFlipsFlag() {
        let checklist = makeChecklist(steps: [makeActionStep()])
        let engine = ExecutionEngine(checklist: checklist)
        checklist.versionNumber = "v9.9"
        #expect(engine.sourceHasChanged == true)
    }

    @Test("Mutating checklist.lastUpdatedDate flips sourceHasChanged")
    func updatedDateFlipsFlag() {
        let checklist = makeChecklist(steps: [makeActionStep()])
        let engine = ExecutionEngine(checklist: checklist)
        checklist.lastUpdatedDate = Date().addingTimeInterval(60)
        #expect(engine.sourceHasChanged == true)
    }

    @Test("adoptLatestSource picks up new steps and clears the flag")
    func adoptLatestRebuildsSnapshot() {
        let original = makeActionStep(text: "Old only")
        let checklist = makeChecklist(steps: [original])
        let engine = ExecutionEngine(checklist: checklist)
        engine.completeStep(original.id)

        // Simulate an external edit: add a step, bump the version + date.
        let added = makeActionStep(text: "New")
        added.orderIndex = 1
        added.checklist = checklist
        checklist.steps = [original, added]
        checklist.versionNumber = "v2.0"
        checklist.lastUpdatedDate = Date().addingTimeInterval(60)

        #expect(engine.sourceHasChanged == true)
        engine.adoptLatestSource()
        #expect(engine.sourceHasChanged == false)
        #expect(engine.currentStepID == original.id)
        #expect(engine.completedStepIDs.isEmpty)
        #expect(engine.visibleSteps.count == 1)  // back at the frontier
    }
}

// MARK: - Edge Cases

@Suite("ExecutionEngine Edge Cases")
@MainActor
struct ExecutionEngineEdgeCaseTests {

    @Test("Completing the same step twice does not advance past the next step")
    func doubleCompleteIsIdempotent() {
        let a = makeActionStep(text: "A")
        let b = makeActionStep(text: "B")
        let c = makeActionStep(text: "C")
        let checklist = makeChecklist(steps: [a, b, c])
        let engine = ExecutionEngine(checklist: checklist)

        engine.completeStep(a.id)
        engine.completeStep(a.id)  // re-issued — should not advance to C
        #expect(engine.currentStepID == b.id)
    }

    @Test("Branch to a non-existent step yields no current step (frontier ends)")
    func branchToMissingTargetEndsFrontier() {
        let phantomID = UUID()
        let decision = makeDecisionStep(
            text: "Choose",
            branchOptions: [BranchOption(label: "Nowhere", targetStepID: phantomID)]
        )
        let checklist = makeChecklist(steps: [decision])
        let engine = ExecutionEngine(checklist: checklist)

        engine.selectBranch(on: decision.id, targetStepID: phantomID)
        #expect(engine.currentStepID == nil)
        #expect(engine.completedStepIDs.contains(decision.id))
    }

    @Test("selectBranch on a non-decision step still records selection and advances")
    func selectBranchOnActionStep() {
        // Defensive behavior — UI shouldn't call selectBranch on actions, but engine
        // shouldn't crash either. Document the actual behavior so we notice if it
        // changes accidentally.
        let target = makeActionStep(text: "Target")
        let other = makeActionStep(text: "Other")
        let checklist = makeChecklist(steps: [other, target])
        let engine = ExecutionEngine(checklist: checklist)

        engine.selectBranch(on: other.id, targetStepID: target.id)
        #expect(engine.currentStepID == target.id)
        #expect(engine.completedStepIDs.contains(other.id))
    }
}
