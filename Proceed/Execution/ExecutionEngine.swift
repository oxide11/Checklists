import Foundation
import Observation

@Observable
final class ExecutionEngine {

    // MARK: - Inputs

    private let stepsByID: [UUID: ChecklistStep]
    private let allOrderedSteps: [ChecklistStep]
    private let firstStepID: UUID?

    // MARK: - Execution State

    private(set) var completedStepIDs: Set<UUID> = []
    private(set) var branchSelections: [UUID: UUID] = [:]
    private(set) var currentStepID: UUID?

    // MARK: - Computed

    /// Whether every reachable step has been completed.
    var isComplete: Bool {
        currentStepID == nil && !completedStepIDs.isEmpty
    }

    /// Ordered steps visible along the current execution path.
    /// Follows the DAG from step 0, through branch selections, stopping at the frontier.
    var visibleSteps: [ChecklistStep] {
        computeVisiblePath()
    }

    /// Fraction of visible steps that are completed (0.0 ... 1.0).
    var progress: Double {
        let visible = visibleSteps
        guard !visible.isEmpty else { return 0 }
        let completed = visible.filter { completedStepIDs.contains($0.id) }.count
        return Double(completed) / Double(visible.count)
    }

    /// Human-readable progress label, e.g. "3 / 7".
    var progressLabel: String {
        let visible = visibleSteps
        let completed = visible.filter { completedStepIDs.contains($0.id) }.count
        return "\(completed) / \(visible.count)"
    }

    // MARK: - Init

    init(checklist: Checklist) {
        let ordered = checklist.orderedSteps
        self.allOrderedSteps = ordered
        self.stepsByID = Dictionary(uniqueKeysWithValues: ordered.map { ($0.id, $0) })
        self.firstStepID = ordered.first?.id
        self.currentStepID = ordered.first?.id
    }

    // MARK: - Actions

    /// Complete an action, warning, or caution step — advances to the next linear step.
    func completeStep(_ stepID: UUID) {
        guard let step = stepsByID[stepID] else { return }
        completedStepIDs.insert(stepID)
        if step.stepType != .decision {
            advanceFrom(step: step, selectedTargetID: nil)
        }
    }

    /// Select a branch on a decision step — advances to the branch target.
    func selectBranch(on decisionStepID: UUID, targetStepID: UUID) {
        guard let step = stepsByID[decisionStepID] else { return }
        completedStepIDs.insert(decisionStepID)
        branchSelections[decisionStepID] = targetStepID
        advanceFrom(step: step, selectedTargetID: targetStepID)
    }

    /// Reset execution to the first step.
    func reset() {
        completedStepIDs.removeAll()
        branchSelections.removeAll()
        currentStepID = firstStepID
    }

    // MARK: - DAG Traversal

    /// Walks from the first step through the DAG, following branch selections
    /// where they exist, and stopping at the first uncompleted step (the frontier).
    private func computeVisiblePath() -> [ChecklistStep] {
        guard let startID = firstStepID, let _ = stepsByID[startID] else {
            return []
        }

        var path: [ChecklistStep] = []
        var visited: Set<UUID> = []
        var currentID: UUID? = startID

        while let id = currentID, let step = stepsByID[id], !visited.contains(id) {
            visited.insert(id)
            path.append(step)

            // If this step isn't completed, it's the frontier — stop here
            guard completedStepIDs.contains(id) else { break }

            // Follow the appropriate next pointer
            if step.stepType == .decision, let selectedTarget = branchSelections[id] {
                currentID = selectedTarget
            } else if let nextID = step.nextStepID {
                currentID = nextID
            } else {
                currentID = findNextByOrderIndex(after: step)
            }
        }

        return path
    }

    private func advanceFrom(step: ChecklistStep, selectedTargetID: UUID?) {
        let nextID: UUID?

        if step.stepType == .decision, let target = selectedTargetID {
            nextID = target
        } else if let linkedNext = step.nextStepID {
            nextID = linkedNext
        } else {
            nextID = findNextByOrderIndex(after: step)
        }

        if let nextID, stepsByID[nextID] != nil {
            currentStepID = nextID
        } else {
            currentStepID = nil // Execution complete
        }
    }

    private func findNextByOrderIndex(after step: ChecklistStep) -> UUID? {
        guard let idx = allOrderedSteps.firstIndex(where: { $0.id == step.id }),
              idx + 1 < allOrderedSteps.count else { return nil }
        return allOrderedSteps[idx + 1].id
    }
}
