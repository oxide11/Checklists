import SwiftUI

struct ChecklistDetailView: View {
    let checklist: Checklist
    @State private var showEditor = false
    @State private var showExecution = false
    @State private var showPreparation = false

    var body: some View {
        List {
            // MARK: Metadata Header
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(checklist.versionNumber, systemImage: "tag")
                        Spacer()
                        Label(checklist.category?.name ?? "Uncategorized", systemImage: checklist.category?.systemImage ?? "folder.fill")
                    }
                    .font(.subheadline)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Updated")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(checklist.lastUpdatedDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption.weight(.medium))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Reviewed")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(checklist.lastReviewedDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption.weight(.medium))
                        }
                    }
                }
            }

            // MARK: Outdated Warning
            if checklist.isOutdated {
                Section {
                    Label {
                        Text("This procedure has not been reviewed in over 12 months. Verify content before use.")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .foregroundStyle(.orange)
                    .font(.subheadline.weight(.medium))
                }
            }

            // MARK: Steps
            Section {
                ForEach(Array(checklist.orderedSteps.enumerated()), id: \.element.id) { index, step in
                    StepRow(step: step, index: index + 1)
                }
            } header: {
                Text("Steps (\(checklist.orderedSteps.count))")
            }
        }
        .navigationTitle(checklist.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if checklist.hasPreparation {
                        showPreparation = true
                    } else {
                        showExecution = true
                    }
                } label: {
                    Label("Execute", systemImage: "play.fill")
                }
                .disabled(checklist.orderedSteps.isEmpty)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button { showEditor = true } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .fullScreenCover(isPresented: $showExecution) {
            ChecklistExecutionView(checklist: checklist)
        }
        .sheet(isPresented: $showPreparation) {
            PreparationView(checklist: checklist) {
                showPreparation = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showExecution = true
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            ChecklistEditorView(checklist: checklist)
                .nightVisionAware()
        }
    }
}

// MARK: - Step Row

struct StepRow: View {
    let step: ChecklistStep
    let index: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number + type icon
            VStack(spacing: 4) {
                Text("\(index)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                stepIcon
            }
            .frame(width: 28, alignment: .center)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                if step.stepType == .decision, let question = step.question {
                    Text(question)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.cyan)

                    ForEach(step.branchOptions) { option in
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.caption2)
                            Text(option.label)
                                .font(.subheadline)
                        }
                        .foregroundStyle(.cyan.opacity(0.8))
                        .padding(.leading, 4)
                    }
                } else {
                    Text(step.text)
                        .font(fontForStepType)
                        .foregroundStyle(colorForStepType)
                }

                if let note = step.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }

                // Media attachments
                if let attachments = step.mediaAttachments, !attachments.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(attachments) { attachment in
                            if attachment.mediaType == .image, let data = attachment.fileData,
                               let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                Label(attachment.mediaType.displayName, systemImage: attachment.mediaType.systemImage)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                }

                // Metadata badges
                HStack(spacing: 12) {
                    if let duration = step.timerDuration, duration > 0 {
                        Label(formatDuration(duration), systemImage: "timer")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.blue)
                    }
                    if step.isCriticalFailure {
                        Label("CRITICAL", systemImage: "bolt.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.red)
                    }
                    if step.requiresAcknowledgment {
                        Label("ACK Required", systemImage: "hand.raised.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    @ViewBuilder
    private var stepIcon: some View {
        switch step.stepType {
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

    private var fontForStepType: Font {
        switch step.stepType {
        case .warning: .body.weight(.bold)
        case .caution: .body.weight(.semibold)
        case .action, .decision: .body
        }
    }

    private var colorForStepType: Color {
        switch step.stepType {
        case .warning: .red
        case .caution: .orange
        case .action: .primary
        case .decision: .cyan
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return secs > 0 ? "\(mins)m \(secs)s" : "\(mins)m"
        }
        return "\(secs)s"
    }
}

#Preview {
    NavigationStack {
        ChecklistDetailView(checklist: {
            let cl = Checklist(title: "Sample Procedure", versionNumber: "v1.0", isEmergency: true)
            return cl
        }())
    }
}
