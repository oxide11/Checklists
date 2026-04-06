import Testing
import SwiftData
@testable import Proceed

// MARK: - In-Memory Container

/// Creates a SwiftData ModelContainer stored entirely in memory — no disk, no CloudKit.
@MainActor
func makeTestContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Checklist.self, ChecklistStep.self, MediaAttachment.self,
             ProcedureCategory.self, Folder.self, Equipment.self,
             ChangeLogEntry.self, IssueReport.self, ProcedureRole.self,
        configurations: config
    )
}

// MARK: - Checklist Builders

/// Builds a Checklist with a linear chain of steps linked by nextStepID.
@MainActor
func makeChecklist(
    title: String = "Test Procedure",
    versionNumber: String = "v1.0",
    isEmergency: Bool = false,
    steps: [ChecklistStep] = []
) -> Checklist {
    let checklist = Checklist(title: title, versionNumber: versionNumber, isEmergency: isEmergency)

    // Link steps linearly via nextStepID and assign orderIndex
    for (index, step) in steps.enumerated() {
        step.orderIndex = index
        step.checklist = checklist
        if index + 1 < steps.count {
            step.nextStepID = steps[index + 1].id
        } else {
            step.nextStepID = nil
        }
    }
    checklist.steps = steps
    return checklist
}

// MARK: - Step Builders

@MainActor
func makeActionStep(text: String = "Do something") -> ChecklistStep {
    ChecklistStep(stepType: .action, text: text)
}

@MainActor
func makeWarningStep(text: String = "Be careful") -> ChecklistStep {
    let step = ChecklistStep(stepType: .warning, text: text)
    step.requiresAcknowledgment = true
    return step
}

@MainActor
func makeCautionStep(text: String = "Proceed with caution") -> ChecklistStep {
    let step = ChecklistStep(stepType: .caution, text: text)
    step.requiresAcknowledgment = true
    return step
}

@MainActor
func makeDecisionStep(
    text: String = "Which path?",
    question: String? = nil,
    branchOptions: [BranchOption] = []
) -> ChecklistStep {
    let step = ChecklistStep(stepType: .decision, text: text)
    step.question = question ?? text
    step.branchOptions = branchOptions
    return step
}
