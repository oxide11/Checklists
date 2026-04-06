import SwiftUI
import SwiftData

struct PendingApprovalsView: View {
    // Note: #Predicate requires a string literal; matches ProcedureStatus.pendingReview.rawValue
    @Query(
        filter: #Predicate<Checklist> { $0.status == "pendingReview" },
        sort: \Checklist.lastUpdatedDate,
        order: .reverse
    ) private var pendingChecklists: [Checklist]

    @State private var selectedChecklist: Checklist? = nil

    var body: some View {
        List {
            if pendingChecklists.isEmpty {
                ContentUnavailableView(
                    "No Pending Reviews",
                    systemImage: "checkmark.seal",
                    description: Text("All procedures are up to date. Procedures submitted for review will appear here.")
                )
            } else {
                ForEach(pendingChecklists) { checklist in
                    Button {
                        selectedChecklist = checklist
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.orange)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(checklist.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)

                                HStack(spacing: 6) {
                                    Text(checklist.versionNumber)
                                    Text("\u{00B7}")
                                    Text(checklist.lastUpdatedDate.formatted(date: .abbreviated, time: .omitted))
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .navigationTitle("Pending Approvals")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $selectedChecklist) { checklist in
            ApprovalView(checklist: checklist)
        }
    }
}
