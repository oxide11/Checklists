import SwiftUI
import SwiftData

struct WorkflowEditorView: View {
    @Query(sort: \Checklist.title) private var allChecklists: [Checklist]
    @Environment(\.dismiss) private var dismiss
    @State private var workflowName = ""
    @State private var selectedIDs: [UUID] = []

    /// Only show checklists not already in a workflow
    private var availableChecklists: [Checklist] {
        allChecklists.filter { $0.workflowID == nil }
    }

    private var canCreate: Bool {
        !workflowName.trimmingCharacters(in: .whitespaces).isEmpty && selectedIDs.count >= 2
    }

    var body: some View {
        Form {
            Section("Workflow Name") {
                TextField("e.g. Engine Start Sequence", text: $workflowName)
            }

            Section {
                if availableChecklists.isEmpty {
                    Text("No available procedures")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(availableChecklists) { checklist in
                        Button {
                            toggleSelection(checklist.id)
                        } label: {
                            HStack {
                                if let index = selectedIDs.firstIndex(of: checklist.id) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.accentColor)
                                            .frame(width: 24, height: 24)
                                        Text("\(index + 1)")
                                            .font(.caption.weight(.bold).monospacedDigit())
                                            .foregroundStyle(.white)
                                    }
                                } else {
                                    Circle()
                                        .strokeBorder(.secondary.opacity(0.4), lineWidth: 1.5)
                                        .frame(width: 24, height: 24)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(checklist.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text("\(checklist.orderedSteps.count) steps")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Select Procedures (tap in order)")
            } footer: {
                Text("Tap procedures in the order you want them executed. Tap again to deselect. At least 2 procedures are required.")
            }

            if !selectedIDs.isEmpty {
                Section("Order Preview") {
                    ForEach(Array(selectedIDs.enumerated()), id: \.element) { index, id in
                        if let checklist = availableChecklists.first(where: { $0.id == id }) {
                            HStack(spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(Color.accentColor)
                                Text(checklist.title)
                                    .font(.body)
                                if index < selectedIDs.count - 1 {
                                    Spacer()
                                    Image(systemName: "arrow.down")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("New Workflow")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    createWorkflow()
                }
                .disabled(!canCreate)
            }
        }
    }

    private func toggleSelection(_ id: UUID) {
        if let index = selectedIDs.firstIndex(of: id) {
            selectedIDs.remove(at: index)
        } else {
            selectedIDs.append(id)
        }
    }

    private func createWorkflow() {
        let procedures = selectedIDs.compactMap { id in
            availableChecklists.first { $0.id == id }
        }
        guard procedures.count >= 2 else { return }

        Checklist.createWorkflow(
            name: workflowName.trimmingCharacters(in: .whitespaces),
            procedures: procedures
        )
        dismiss()
    }
}
