import SwiftUI
import SwiftData

struct ChangeLogView: View {
    let checklist: Checklist

    private var entries: [ChangeLogEntry] {
        checklist.safeChangeLog.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Changes to this procedure will appear here.")
                )
            } else {
                ForEach(entries) { entry in
                    ChangeLogEntryRow(entry: entry)
                }
            }
        }
        .navigationTitle("Change History")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Entry Row

struct ChangeLogEntryRow: View {
    let entry: ChangeLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForType)
                    .foregroundStyle(colorForType)
                    .font(.title3)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.change.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let prev = entry.previousVersionNumber, let next = entry.newVersionNumber {
                    HStack(spacing: 4) {
                        Text(prev)
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(next)
                            .foregroundStyle(.primary)
                    }
                    .font(.caption.weight(.medium).monospacedDigit())
                }
            }

            if !entry.summary.isEmpty {
                Text(entry.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("by \(entry.authorName)")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            // Field changes
            let changes = entry.fieldChanges
            if !changes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(changes) { change in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(change.fieldName)
                                .font(.caption.weight(.medium))
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconForType: String {
        entry.change.systemImage
    }

    private var colorForType: Color {
        entry.change.color
    }
}
