import SwiftUI
import SwiftData

struct ApprovalView: View {
    let checklist: Checklist
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var comments = ""

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
        }
    }

    private func approve() {
        checklist.procedureStatus = .published

        let logEntry = ChangeLogEntry(
            changeType: .approved,
            summary: comments.isEmpty ? "Procedure approved and published" : "Approved: \(comments)",
            previousVersionNumber: checklist.versionNumber,
            newVersionNumber: checklist.versionNumber
        )
        logEntry.checklist = checklist
        modelContext.insert(logEntry)

        dismiss()
    }

    private func reject() {
        checklist.procedureStatus = .rejected

        let logEntry = ChangeLogEntry(
            changeType: .rejected,
            summary: comments.isEmpty ? "Procedure rejected" : "Rejected: \(comments)",
            previousVersionNumber: checklist.versionNumber,
            newVersionNumber: checklist.versionNumber
        )
        logEntry.checklist = checklist
        modelContext.insert(logEntry)

        dismiss()
    }
}
