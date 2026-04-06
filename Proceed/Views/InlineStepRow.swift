import SwiftUI

struct InlineStepRow: View {
    let step: ChecklistStep
    let index: Int
    let isCompleted: Bool
    let isCurrent: Bool
    let requiredEquipment: [Equipment]
    let timerRemaining: Double?
    let timerRunning: Bool
    let onComplete: () -> Void
    let onSelectBranch: (UUID) -> Void
    let onStartTimer: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left column: step number + completion indicator
            VStack(spacing: 4) {
                Text("\(index)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(isCurrent ? .primary : .secondary)

                completionIndicator
            }
            .frame(width: 36)

            // Right column: content
            VStack(alignment: .leading, spacing: 6) {
                // Step text
                Text(step.text)
                    .font(isCurrent ? step.stepType.font : .body)
                    .strikethrough(isCompleted)
                    .foregroundStyle(isCompleted ? .secondary : step.stepType.color)

                // Note (current step only)
                if let note = step.note, isCurrent {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }

                // Just-in-time features for current step
                if isCurrent && !isCompleted {
                    equipmentDisplay
                    mediaGallery
                    referenceDisplay
                }

                // Metadata badges (shown for ALL steps)
                metadataBadges

                // Timer display (current step only)
                if isCurrent && !isCompleted {
                    timerDisplay
                }

                // Interaction controls (current step only)
                if isCurrent && !isCompleted {
                    interactionControls
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, isCurrent ? 4 : 0)
        .background {
            if isCurrent {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.08))
            }
        }
        .opacity(isCompleted ? 0.6 : 1.0)
    }

    // MARK: - Completion Indicator

    @ViewBuilder
    private var completionIndicator: some View {
        if isCompleted {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
        } else if isCurrent {
            Image(systemName: step.stepType.systemImage)
                .font(.title2)
                .foregroundStyle(step.stepType == .action ? Color.accentColor : step.stepType.color)
        } else {
            Image(systemName: "circle")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
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
            }
            .padding(8)
            .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Media Gallery

    @ViewBuilder
    private var mediaGallery: some View {
        let attachments = step.safeMediaAttachments
        if !attachments.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(attachments) { attachment in
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
            }
        }
    }

    // MARK: - Reference Display

    @ViewBuilder
    private var referenceDisplay: some View {
        if let fileName = step.referenceFileName, !fileName.isEmpty {
            Label("View: \(fileName)", systemImage: "doc.text.magnifyingglass")
                .font(.caption)
                .foregroundStyle(.indigo)
        }
    }

    // MARK: - Metadata Badges

    @ViewBuilder
    private var metadataBadges: some View {
        let hasTimer = (step.timerDuration ?? 0) > 0
        let hasCritical = step.isCriticalFailure
        let hasEquipmentBadge = !isCurrent && !step.requiredEquipmentIDs.isEmpty

        if hasTimer || hasCritical || hasEquipmentBadge {
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
                if !isCurrent && !step.requiredEquipmentIDs.isEmpty {
                    Label("\(step.requiredEquipmentIDs.count) tools", systemImage: "wrench.and.screwdriver")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Timer Display

    @ViewBuilder
    private var timerDisplay: some View {
        if let duration = step.timerDuration, duration > 0 {
            if let remaining = timerRemaining {
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
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.cyan)
        }
        ForEach(step.branchOptions) { option in
            Button {
                if let targetID = option.targetStepID {
                    withAnimation { onSelectBranch(targetID) }
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
