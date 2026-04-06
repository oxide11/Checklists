import SwiftUI

struct WorkflowDetailView: View {
    let workflowID: UUID
    let workflowName: String
    let procedures: [Checklist]
    @Environment(\.dismiss) private var dismiss
    @State private var showDissolveConfirmation = false

    var body: some View {
        List {
            Section {
                Text("\(procedures.count) procedures in this workflow")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Procedures") {
                ForEach(Array(procedures.enumerated()), id: \.element.id) { index, procedure in
                    NavigationLink {
                        ChecklistDetailView(checklist: procedure)
                    } label: {
                        HStack(spacing: 12) {
                            // Numbered circle
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Text("\(index + 1)")
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(Color.accentColor)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(procedure.title)
                                    .font(.body.weight(.medium))

                                Text("\(procedure.orderedSteps.count) steps")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if index < procedures.count - 1 {
                                Image(systemName: "arrow.down")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            } else {
                                Image(systemName: "flag.checkered")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showDissolveConfirmation = true
                } label: {
                    Label("Dissolve Workflow", systemImage: "trash")
                }
            }
        }
        .navigationTitle(workflowName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .confirmationDialog(
            "Dissolve Workflow?",
            isPresented: $showDissolveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Dissolve", role: .destructive) {
                for procedure in procedures {
                    procedure.removeFromWorkflow()
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will unlink all \(procedures.count) procedures from this workflow. The procedures themselves will not be deleted.")
        }
    }
}
