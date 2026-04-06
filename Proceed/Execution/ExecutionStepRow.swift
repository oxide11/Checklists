import SwiftUI
import AVKit

struct ExecutionStepRow: View {
    let step: ChecklistStep
    let index: Int
    let state: StepState
    let highlightCurrent: Bool
    let progressiveDisclosure: Bool
    let timerRemaining: Double?
    let timerRunning: Bool
    let requiredEquipment: [Equipment]
    let onComplete: () -> Void
    let onSelectBranch: (UUID) -> Void
    let onStartTimer: () -> Void
    let onTapEquipment: ((Equipment) -> Void)?

    enum StepState {
        case completed, current, upcoming
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            completionIndicator
                .frame(width: 44, alignment: .center)

            VStack(alignment: .leading, spacing: 8) {
                stepContent

                if let note = step.note, state == .current {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }

                if state == .current {
                    equipmentDisplay
                    mediaGallery
                    referenceDisplay
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
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(state == .current ? .primary : .secondary)

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
        Image(systemName: step.stepType.systemImage)
            .foregroundStyle(step.stepType == .action ? Color.accentColor : step.stepType.color)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        if progressiveDisclosure && state == .upcoming {
            Text(step.text)
                .font(.body)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        } else if step.stepType == .decision && state == .completed {
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
        step.stepType.color
    }

    // MARK: - Equipment Display

    @ViewBuilder
    private var equipmentDisplay: some View {
        if !requiredEquipment.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Required Equipment")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(requiredEquipment) { item in
                    Button {
                        onTapEquipment?(item)
                    } label: {
                        HStack(spacing: 8) {
                            if let data = item.photoData {
                                CachedImage(data: data)
                                    .scaledToFill()
                                    .frame(width: 28, height: 28)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            } else {
                                Image(systemName: "wrench.and.screwdriver")
                                    .font(.caption)
                                    .frame(width: 28, height: 28)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name)
                                    .font(.subheadline.weight(.medium))
                                if !item.storageLocation.isEmpty {
                                    Text(item.storageLocation)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Reference Display

    @ViewBuilder
    private var referenceDisplay: some View {
        if let fileName = step.referenceFileName, !fileName.isEmpty {
            Button {
                // Reference viewing handled by parent via sheet
            } label: {
                Label("View: \(fileName)", systemImage: "doc.text.magnifyingglass")
            }
            .buttonStyle(.bordered)
            .tint(.indigo)
        }
    }

    // MARK: - Media Gallery

    @ViewBuilder
    private var mediaGallery: some View {
        let attachments = step.safeMediaAttachments
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
                if let data = attachment.fileData {
                    CachedImage(data: data)
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
                    Label(duration.formattedDuration, systemImage: "timer")
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
                    Label("Start Timer (\(duration.formattedDuration))", systemImage: "timer")
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

    private func formatCountdown(_ seconds: Double) -> String {
        let total = max(0, Int(ceil(seconds)))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
