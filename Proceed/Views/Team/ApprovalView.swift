import SwiftUI
import SwiftData

struct ApprovalView: View {
    let checklist: Checklist
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var comments = ""
    @State private var saveError: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Procedure") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(checklist.title)
                            .font(.headline)
                        HStack {
                            Label(checklist.versionNumber, systemImage: "tag")
                            Spacer()
                            Label(checklist.category?.name ?? "Uncategorized", systemImage: checklist.category?.systemImage ?? "folder.fill")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        Text("\(checklist.orderedSteps.count) steps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Change Summary") {
                    let recentChanges = checklist.safeChangeLog
                        .sorted { $0.timestamp > $1.timestamp }
                        .prefix(3)

                    if recentChanges.isEmpty {
                        Text("No recent changes recorded.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(recentChanges)) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.summary)
                                    .font(.subheadline)
                                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Review Comments") {
                    TextField("Add comments (optional)...", text: $comments, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button {
                        approve()
                    } label: {
                        Label("Approve & Publish", systemImage: "checkmark.seal.fill")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button(role: .destructive) {
                        reject()
                    } label: {
                        Label("Reject", systemImage: "xmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .navigationTitle("Review Procedure")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert(
                "Couldn\u{2019}t Save Decision",
                isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
            ) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    private func approve() {
        applyDecision(
            newStatus: .published,
            changeType: .approved,
            summaryFallback: "Procedure approved and published",
            summaryWithComments: "Approved: \(comments)"
        )
    }

    private func reject() {
        applyDecision(
            newStatus: .rejected,
            changeType: .rejected,
            summaryFallback: "Procedure rejected",
            summaryWithComments: "Rejected: \(comments)"
        )
    }

    private func applyDecision(
        newStatus: ProcedureStatus,
        changeType: ChangeType,
        summaryFallback: String,
        summaryWithComments: String
    ) {
        let previousStatus = checklist.status
        checklist.status = newStatus

        let logEntry = ChangeLogEntry(
            changeType: changeType,
            summary: comments.isEmpty ? summaryFallback : summaryWithComments,
            previousVersionNumber: checklist.versionNumber,
            newVersionNumber: checklist.versionNumber
        )
        logEntry.checklist = checklist
        modelContext.insert(logEntry)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            checklist.status = previousStatus
            modelContext.delete(logEntry)
            saveError = error.localizedDescription
        }
    }
}
