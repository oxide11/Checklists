import SwiftUI
import SwiftData

struct ChecklistExecutionView: View {
    let checklist: Checklist
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Equipment.name) private var allEquipment: [Equipment]
    @AppStorage("highlightCurrentStep") private var highlightCurrentStep = true
    @AppStorage("autoStartTimers") private var autoStartTimers = true
    @AppStorage("autoAdvanceOnTimerEnd") private var autoAdvanceOnTimerEnd = false
    @AppStorage("progressiveDisclosure") private var progressiveDisclosure = true
    @State private var engine: ExecutionEngine
    @State private var showResetConfirmation = false
    @State private var showIssueReport = false

    // Timer state
    @State private var activeTimerStepID: UUID? = nil
    @State private var timerRemaining: Double = 0
    @State private var timerTask: Task<Void, Never>? = nil
    @State private var showAutoAdvanceBanner = false

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
                            let stepEquipment = allEquipment.filter { step.requiredEquipmentIDs.contains($0.id) }
                            ExecutionStepRow(
                                step: step,
                                index: index + 1,
                                state: stepState(for: step),
                                highlightCurrent: highlightCurrentStep,
                                progressiveDisclosure: progressiveDisclosure,
                                timerRemaining: activeTimerStepID == step.id ? timerRemaining : nil,
                                timerRunning: activeTimerStepID == step.id,
                                requiredEquipment: stepEquipment,
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
                                },
                                onTapEquipment: nil
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
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemBackground))
                    .onChange(of: engine.currentStepID) { _, newID in
                        if let newID {
                            withAnimation {
                                proxy.scrollTo(newID, anchor: .center)
                            }

                            // Auto-start timer for newly current step
                            if autoStartTimers,
                               let step = engine.visibleSteps.first(where: { $0.id == newID }),
                               let duration = step.timerDuration, duration > 0 {
                                startTimer(for: step)
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if showAutoAdvanceBanner {
                    Text("Advancing...")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 20)
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
                        Button {
                            showIssueReport = true
                        } label: {
                            Label("Report Issue", systemImage: "exclamationmark.bubble")
                        }

                        Divider()

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
            .background(Color(.systemBackground).ignoresSafeArea())
            .sheet(isPresented: $showIssueReport) {
                IssueReportView(
                    checklist: checklist,
                    currentStep: engine.visibleSteps.first { $0.id == engine.currentStepID }
                )
                .nightVisionAware()
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
        .onDisappear {
            stopTimer()
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
                .accessibilityHidden(true)
            Text("Procedure Complete")
                .font(.title2.weight(.bold))
            Text("All \(engine.visibleSteps.count) steps executed successfully.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Workflow context
            if let workflow = checklist.workflow {
                let siblings = workflow.orderedProcedures
                let position = (siblings.firstIndex(where: { $0.id == checklist.id }) ?? 0) + 1

                Text("Procedure \(position) of \(siblings.count) in \(workflow.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

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

            // Timer completed naturally (not cancelled)
            guard !Task.isCancelled else { return }

            if autoAdvanceOnTimerEnd && step.stepType != .decision {
                await MainActor.run {
                    withAnimation { showAutoAdvanceBanner = true }
                }
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    // Only advance if the user is still on this step — they may have
                    // already completed it manually or navigated away during the
                    // banner delay.
                    guard engine.currentStepID == step.id else {
                        showAutoAdvanceBanner = false
                        return
                    }
                    withAnimation {
                        showAutoAdvanceBanner = false
                        stopTimer()
                        engine.completeStep(step.id)
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
        showAutoAdvanceBanner = false
    }
}
