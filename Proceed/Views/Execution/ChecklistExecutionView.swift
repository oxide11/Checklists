import SwiftUI

struct ChecklistExecutionView: View {
    let checklist: Checklist
    @Environment(\.dismiss) private var dismiss
    @AppStorage("highlightCurrentStep") private var highlightCurrentStep = true
    @State private var engine: ExecutionEngine
    @State private var showResetConfirmation = false

    // Timer state
    @State private var activeTimerStepID: UUID? = nil
    @State private var timerRemaining: Double = 0
    @State private var timerTask: Task<Void, Never>? = nil

    init(checklist: Checklist) {
        self.checklist = checklist
        self._engine = State(initialValue: ExecutionEngine(checklist: checklist))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar

                ScrollViewReader { proxy in
                    List {
                        ForEach(Array(engine.visibleSteps.enumerated()), id: \.element.id) { index, step in
                            ExecutionStepRow(
                                step: step,
                                index: index + 1,
                                state: stepState(for: step),
                                highlightCurrent: highlightCurrentStep,
                                timerRemaining: activeTimerStepID == step.id ? timerRemaining : nil,
                                timerRunning: activeTimerStepID == step.id,
                                onComplete: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        stopTimer()
                                        engine.completeStep(step.id)
                                    }
                                },
                                onSelectBranch: { targetID in
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        stopTimer()
                                        engine.selectBranch(on: step.id, targetStepID: targetID)
                                    }
                                },
                                onStartTimer: {
                                    startTimer(for: step)
                                }
                            )
                            .id(step.id)
                            .listRowSeparator(.hidden)
                        }

                        if engine.isComplete {
                            completionBanner
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: engine.currentStepID) { _, newID in
                        if let newID {
                            withAnimation {
                                proxy.scrollTo(newID, anchor: .center)
                            }
                        }
                    }
                }
            }
            .navigationTitle(checklist.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(role: .destructive) {
                            showResetConfirmation = true
                        } label: {
                            Label("Reset Procedure", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog("Reset Procedure?", isPresented: $showResetConfirmation) {
                Button("Reset to Beginning", role: .destructive) {
                    stopTimer()
                    withAnimation { engine.reset() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear all progress and start from the first step.")
            }
        }
        .nightVisionAware()
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 4) {
            ProgressView(value: engine.progress)
                .tint(checklist.isEmergency ? .red : .accentColor)

            HStack {
                Text(engine.progressLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                if engine.isComplete {
                    Label("Complete", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                } else {
                    Text(checklist.isEmergency ? "EMERGENCY" : "In Progress")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(checklist.isEmergency ? .red : .secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Completion Banner

    private var completionBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Procedure Complete")
                .font(.title2.weight(.bold))
            Text("All \(engine.visibleSteps.count) steps executed successfully.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Helpers

    private func stepState(for step: ChecklistStep) -> ExecutionStepRow.StepState {
        if engine.completedStepIDs.contains(step.id) {
            return .completed
        } else if step.id == engine.currentStepID {
            return .current
        } else {
            return .upcoming
        }
    }

    // MARK: - Timer

    private func startTimer(for step: ChecklistStep) {
        guard let duration = step.timerDuration, duration > 0 else { return }
        stopTimer()

        activeTimerStepID = step.id
        timerRemaining = duration

        timerTask = Task {
            let start = Date()
            while !Task.isCancelled && timerRemaining > 0 {
                try? await Task.sleep(for: .milliseconds(100))
                let elapsed = Date().timeIntervalSince(start)
                await MainActor.run {
                    withAnimation(.linear(duration: 0.1)) {
                        timerRemaining = max(0, duration - elapsed)
                    }
                }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
        activeTimerStepID = nil
        timerRemaining = 0
    }
}
