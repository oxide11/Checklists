import SwiftUI
import SwiftData

struct WorkflowDetailView: View {
    let workflow: Workflow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showDissolveConfirmation = false

    private var procedures: [Checklist] {
        workflow.orderedProcedures
    }

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
        .navigationTitle(workflow.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .confirmationDialog(
            "Dissolve Workflow?",
            isPresented: $showDissolveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Dissolve", role: .destructive) {
                let captured = procedures
                for procedure in captured {
                    procedure.workflow = nil
                    procedure.workflowOrder = 0
                }
                modelContext.delete(workflow)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will unlink all \(procedures.count) procedures from this workflow. The procedures themselves will not be deleted.")
        }
    }
}
