import Foundation
import Observation

@MainActor
@Observable
final class ExecutionEngine {

    // MARK: - Inputs

    /// Strong reference to the source checklist. The engine snapshots the step
    /// graph at init for determinism during a run, but keeps the reference so
    /// it can detect (via sourceHasChanged) when an external edit or CloudKit
    /// sync has invalidated the snapshot, and so adoptLatestSource() can
    /// rebuild against the new version on operator request.
    private let checklist: Checklist
    private var snapshotVersion: String
    private var snapshotUpdatedAt: Date
    private var stepsByID: [UUID: ChecklistStep]
    private var allOrderedSteps: [ChecklistStep]
    private var firstStepID: UUID?

    // MARK: - Execution State

    private(set) var completedStepIDs: Set<UUID> = []
    private(set) var branchSelections: [UUID: UUID] = [:]
    private(set) var currentStepID: UUID?

    /// True when the underlying Checklist has been edited (locally or via
    /// CloudKit sync) since this engine was constructed. UIs should surface
    /// this to the operator and offer to restart against the new version
    /// rather than silently continue with stale steps.
    var sourceHasChanged: Bool {
        checklist.versionNumber != snapshotVersion
            || checklist.lastUpdatedDate != snapshotUpdatedAt
    }

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
        self.checklist = checklist
        self.snapshotVersion = checklist.versionNumber
        self.snapshotUpdatedAt = checklist.lastUpdatedDate
        self.allOrderedSteps = ordered
        // Use last-wins merge to avoid crash if SwiftData sync produces duplicate IDs
        self.stepsByID = Dictionary(ordered.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        self.firstStepID = ordered.first?.id
        self.currentStepID = ordered.first?.id
    }

    // MARK: - Actions

    /// Complete an action, warning, or caution step — advances to the next linear step.
    /// Decision steps must be resolved via `selectBranch` and are rejected here.
    /// Only the current frontier step can be completed; out-of-order calls are
    /// rejected to defend against UI bugs marking upcoming or completed steps.
    func completeStep(_ stepID: UUID) {
        guard stepID == currentStepID,
              let step = stepsByID[stepID],
              step.stepType != .decision else { return }
        completedStepIDs.insert(stepID)
        advanceFrom(step: step, selectedTargetID: nil)
    }

    /// Select a branch on a decision step — advances to the branch target.
    /// Rejects calls for any step other than the current frontier.
    func selectBranch(on decisionStepID: UUID, targetStepID: UUID) {
        guard decisionStepID == currentStepID,
              let step = stepsByID[decisionStepID],
              step.stepType == .decision,
              stepsByID[targetStepID] != nil else { return }
        completedStepIDs.insert(decisionStepID)
        branchSelections[decisionStepID] = targetStepID
        advanceFrom(step: step, selectedTargetID: targetStepID)
    }

    /// Reset execution to the first step of the current snapshot.
    func reset() {
        completedStepIDs.removeAll()
        branchSelections.removeAll()
        currentStepID = firstStepID
    }

    /// Rebuilds the snapshot from the live Checklist and resets run state.
    /// Use when the source has changed mid-execution and the operator wants
    /// to restart against the updated procedure.
    func adoptLatestSource() {
        let ordered = checklist.orderedSteps
        allOrderedSteps = ordered
        stepsByID = Dictionary(ordered.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        firstStepID = ordered.first?.id
        snapshotVersion = checklist.versionNumber
        snapshotUpdatedAt = checklist.lastUpdatedDate
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
