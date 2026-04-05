import SwiftUI
import AVKit

struct ExecutionStepRow: View {
    let step: ChecklistStep
    let index: Int
    let state: StepState
    let highlightCurrent: Bool
    let timerRemaining: Double?
    let timerRunning: Bool
    let onComplete: () -> Void
    let onSelectBranch: (UUID) -> Void
    let onStartTimer: () -> Void

    enum StepState {
        case completed, current, upcoming
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            completionIndicator
                .frame(width: 36, alignment: .center)

            VStack(alignment: .leading, spacing: 8) {
                stepContent

                if let note = step.note, state == .current {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }

                if state == .current {
                    mediaGallery
                    metadataBadges
                    timerDisplay
                    interactionControls
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, highlightCurrent && state == .current ? 4 : 0)
        .background {
            if highlightCurrent && state == .current {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
            }
        }
        .opacity(state == .completed ? 0.55 : 1.0)
    }

    // MARK: - Completion Indicator

    @ViewBuilder
    private var completionIndicator: some View {
        VStack(spacing: 4) {
            Text("\(index)")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(.secondary)

            switch state {
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            case .current:
                stepTypeIcon
                    .font(.title2)
            case .upcoming:
                Image(systemName: "circle.dashed")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var stepTypeIcon: some View {
        switch step.stepType {
        case .action:
            Image(systemName: "circle")
                .foregroundStyle(Color.accentColor)
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

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        if step.stepType == .decision && state == .completed {
            // Completed decision — show the text only
            Text(step.question ?? step.text)
                .font(.body)
                .strikethrough()
                .foregroundStyle(.secondary)
        } else {
            Text(step.text)
                .font(state == .current ? .body.weight(.semibold) : .body)
                .strikethrough(state == .completed)
                .foregroundStyle(state == .completed ? .secondary : textColor)
        }
    }

    private var textColor: Color {
        switch step.stepType {
        case .warning: .red
        case .caution: .orange
        case .decision: .primary
        case .action: .primary
        }
    }

    // MARK: - Media Gallery

    @ViewBuilder
    private var mediaGallery: some View {
        let attachments = step.mediaAttachments ?? []
        if !attachments.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(attachments) { attachment in
                    mediaView(for: attachment)
                }
            }
        }
    }

    @ViewBuilder
    private func mediaView(for attachment: MediaAttachment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            switch attachment.mediaType {
            case .image:
                if let data = attachment.fileData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            case .video:
                Label(attachment.fileName, systemImage: "video.fill")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            case .audio:
                Label(attachment.fileName, systemImage: "waveform")
                    .font(.subheadline)
                    .foregroundStyle(.purple)
            case .model3D:
                Label(attachment.fileName, systemImage: "cube")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }

            if let caption = attachment.caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Metadata Badges

    @ViewBuilder
    private var metadataBadges: some View {
        let hasBadges = step.timerDuration != nil || step.isCriticalFailure
        if hasBadges {
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
            }
        }
    }

    // MARK: - Timer Display

    @ViewBuilder
    private var timerDisplay: some View {
        if let duration = step.timerDuration, duration > 0 {
            if let remaining = timerRemaining {
                // Timer is active — show countdown
                VStack(spacing: 4) {
                    Text(formatCountdown(remaining))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(remaining <= 10 ? .red : .blue)
                        .contentTransition(.numericText())

                    if remaining <= 0 {
                        Label("Time's up", systemImage: "bell.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else if !timerRunning {
                // Timer not started
                Button(action: onStartTimer) {
                    Label("Start Timer (\(formatDuration(duration)))", systemImage: "timer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .controlSize(.large)
            }
        }
    }

    // MARK: - Interaction Controls

    @ViewBuilder
    private var interactionControls: some View {
        switch step.stepType {
        case .action:
            Button(action: onComplete) {
                Label("Mark Complete", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .warning:
            Button(action: onComplete) {
                Label("Acknowledge Warning", systemImage: "hand.raised.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)

        case .caution:
            Button(action: onComplete) {
                Label("Acknowledge Caution", systemImage: "hand.raised.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)

        case .decision:
            decisionControls
        }
    }

    @ViewBuilder
    private var decisionControls: some View {
        if let question = step.question {
            Text(question)
                .font(.headline)
                .foregroundStyle(.cyan)
                .padding(.top, 4)
        }

        ForEach(step.branchOptions) { option in
            Button {
                if let targetID = option.targetStepID {
                    onSelectBranch(targetID)
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.turn.down.right")
                    Text(option.label)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .tint(.cyan)
            .controlSize(.large)
            .disabled(option.targetStepID == nil)
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return secs > 0 ? "\(mins)m \(secs)s" : "\(mins)m"
        }
        return "\(secs)s"
    }

    private func formatCountdown(_ seconds: Double) -> String {
        let total = max(0, Int(ceil(seconds)))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
