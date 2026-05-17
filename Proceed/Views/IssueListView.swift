import SwiftUI
import SwiftData

struct IssueListView: View {
    let checklist: Checklist
    @Environment(\.modelContext) private var modelContext
    @State private var pendingDelete: [IssueReport] = []

    private var issues: [IssueReport] {
        checklist.safeIssueReports.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        List {
            if issues.isEmpty {
                ContentUnavailableView(
                    "No Reported Issues",
                    systemImage: "checkmark.circle",
                    description: Text("No one has reported an issue for this procedure yet.")
                )
            } else {
                ForEach(issues) { issue in
                    IssueRow(issue: issue)
                }
                .onDelete { offsets in
                    let snapshot = issues
                    pendingDelete = offsets.compactMap { snapshot.indices.contains($0) ? snapshot[$0] : nil }
                }
            }
        }
        .navigationTitle("Reported Issues")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .confirmationDialog(
            pendingDelete.count == 1 ? "Delete this issue report?" : "Delete \(pendingDelete.count) reports?",
            isPresented: Binding(get: { !pendingDelete.isEmpty }, set: { if !$0 { pendingDelete = [] } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                for item in pendingDelete { modelContext.delete(item) }
                pendingDelete = []
            }
            Button("Cancel", role: .cancel) { pendingDelete = [] }
        } message: {
            Text("Deleted issue reports cannot be recovered.")
        }
    }
}

// MARK: - Issue Row

struct IssueRow: View {
    let issue: IssueReport
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: severityIcon)
                    .foregroundStyle(severityColor)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(issue.issueDescription)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)

                    Text(issue.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    if issue.status == .open {
                        Button {
                            issue.status = .acknowledged
                        } label: {
                            Label("Acknowledge", systemImage: "eye")
                        }
                    }
                    if issue.status != .resolved {
                        Button {
                            issue.status = .resolved
                        } label: {
                            Label("Mark Resolved", systemImage: "checkmark.circle")
                        }
                    }
                    if issue.status == .resolved {
                        Button {
                            issue.status = .open
                        } label: {
                            Label("Reopen", systemImage: "arrow.uturn.backward")
                        }
                    }
                } label: {
                    Text(issue.status.displayName)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(issue.status.color.opacity(0.15), in: Capsule())
                        .foregroundStyle(issue.status.color)
                }
            }

            if !issue.reason.isEmpty {
                Text("Reason: \(issue.reason)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let stepText = issue.stepText {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle")
                        .font(.caption2)
                    Text("At step: \(stepText)")
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }

            if let data = issue.photoData {
                CachedImage(data: data)
                    .scaledToFit()
                    .frame(maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Text("by \(issue.authorName)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var severityIcon: String {
        issue.severity.filledSystemImage
    }

    private var severityColor: Color {
        issue.severity.color
    }
}
