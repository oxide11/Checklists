import SwiftUI
import SwiftData

struct ChecklistEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let existingChecklist: Checklist?
    @State private var editable: EditableChecklist

    init(checklist: Checklist? = nil) {
        self.existingChecklist = checklist
        self._editable = State(
            initialValue: checklist.map { EditableChecklist(from: $0) } ?? EditableChecklist()
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                stepsSection
            }
            .navigationTitle(existingChecklist == nil ? "New Procedure" : "Edit Procedure")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        editable.save(to: modelContext, updating: existingChecklist)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!editable.isValid)
                }
            }
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        Section {
            TextField("Procedure Title", text: $editable.title)

            Picker("Category", selection: $editable.category) {
                ForEach(ChecklistCategory.allCases) { cat in
                    Label(cat.displayName, systemImage: cat.systemImage)
                        .tag(cat)
                }
            }

            TextField("Version", text: $editable.versionNumber)

            Toggle(isOn: $editable.isEmergency) {
                Label("Emergency Procedure", systemImage: "exclamationmark.triangle.fill")
            }
        } header: {
            Text("Details")
        }
    }

    // MARK: - Steps Section

    private var stepsSection: some View {
        Section {
            if editable.steps.isEmpty {
                Text("No steps yet. Add your first step below.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach($editable.steps) { $step in
                    NavigationLink {
                        StepEditorView(step: $step, allSteps: editable.steps)
                    } label: {
                        stepSummaryRow(step: step)
                    }
                }
                .onMove { from, to in
                    editable.steps.move(fromOffsets: from, toOffset: to)
                }
                .onDelete { offsets in
                    let deletedIDs = Set(offsets.map { editable.steps[$0].id })
                    editable.steps.remove(atOffsets: offsets)
                    cleanupBranchReferences(deletedIDs: deletedIDs)
                }
            }

            Button {
                withAnimation {
                    editable.steps.append(EditableStep())
                }
            } label: {
                Label("Add Step", systemImage: "plus.circle.fill")
            }
        } header: {
            HStack {
                Text("Steps (\(editable.steps.count))")
                Spacer()
                if !editable.steps.isEmpty {
                    EditButton()
                        .font(.subheadline)
                }
            }
        } footer: {
            if !editable.steps.isEmpty {
                Text("Tap a step to edit. Use Edit to reorder or delete.")
            }
        }
    }

    // MARK: - Step Summary Row

    @ViewBuilder
    private func stepSummaryRow(step: EditableStep) -> some View {
        let index = (editable.steps.firstIndex(where: { $0.id == step.id }) ?? 0) + 1

        HStack(spacing: 10) {
            VStack(spacing: 2) {
                Text("\(index)")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
                stepTypeIcon(step.stepType)
                    .font(.body)
            }
            .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text(step.text.isEmpty ? "Untitled Step" : step.text)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundStyle(step.text.isEmpty ? .secondary : .primary)

                HStack(spacing: 6) {
                    Text(step.stepType.rawValue.capitalized)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(colorForStepType(step.stepType))

                    if step.stepType == .decision && !step.branchOptions.isEmpty {
                        Text("\u{00B7} \(step.branchOptions.count) branches")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if step.timerDuration != nil {
                        Image(systemName: "timer")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }

                    if step.isCriticalFailure {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func stepTypeIcon(_ type: StepType) -> some View {
        switch type {
        case .action:
            Image(systemName: "circle")
                .foregroundStyle(.primary)
        case .decision:
            Image(systemName: "arrow.triangle.branch")
                .foregroundStyle(.cyan)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        case .caution:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        }
    }

    private func colorForStepType(_ type: StepType) -> Color {
        switch type {
        case .action: .primary
        case .decision: .cyan
        case .warning: .red
        case .caution: .orange
        }
    }

    private func cleanupBranchReferences(deletedIDs: Set<UUID>) {
        for i in editable.steps.indices {
            for j in editable.steps[i].branchOptions.indices {
                if let target = editable.steps[i].branchOptions[j].targetStepID,
                   deletedIDs.contains(target) {
                    editable.steps[i].branchOptions[j].targetStepID = nil
                }
            }
        }
    }
}
