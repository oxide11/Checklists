import SwiftUI
import SwiftData

struct ChecklistDetailView: View {
    let checklist: Checklist
    @Query(sort: \Equipment.name) private var allEquipment: [Equipment]
    @Environment(\.modelContext) private var modelContext
    @State private var showEditor = false
    @State private var showExecution = false
    @State private var showPreparation = false
    @State private var inlineMode = true
    @State private var inlineEngine: ExecutionEngine?
    @State private var exportFormat: ExportFormat = .markdown
    @State private var showExportShare = false
    @State private var exportFileURL: URL? = nil
    @State private var showExportError = false
    @State private var exportErrorMessage: String? = nil
    @State private var showApproval = false
    @State private var showShareSheet = false
    @State private var showShareError = false
    @State private var statusSaveError: String? = nil
    @State private var preparationCompleted = false
    @State private var showChangeLog = false
    @State private var showIssues = false
    @State private var showTeam = false
    @Environment(\.openURL) private var openURL

    // Timer state for inline check-off mode
    @State private var activeTimerStepID: UUID? = nil
    @State private var timerRemaining: Double = 0
    @State private var timerTask: Task<Void, Never>? = nil

    enum ExportFormat { case markdown, html, pdf }

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

            // MARK: Approval Actions (shown only when relevant)
            if checklist.safeRoles.contains(where: { $0.userRole == .approver }) {
                if checklist.status == .draft || checklist.status == .rejected {
                    Section {
                        Button {
                            submitForReview()
                        } label: {
                            Label("Submit for Review", systemImage: "arrow.up.circle.fill")
                        }
                        .tint(.orange)
                    }
                }

                if checklist.status == .pendingReview {
                    Section {
                        Button {
                            showApproval = true
                        } label: {
                            Label("Review Procedure", systemImage: "checkmark.seal")
                        }
                        .tint(.green)
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

            // MARK: Required Equipment (shown in inline mode or always if present)
            if inlineMode {
                equipmentSection
            }

            // MARK: Steps
            Section {
                ForEach(Array(checklist.orderedSteps.enumerated()), id: \.element.id) { index, step in
                    if inlineMode, let engine = inlineEngine {
                        let stepEquipment = allEquipment.filter { step.requiredEquipmentIDs.contains($0.id) }
                        InlineStepRow(
                            step: step,
                            index: index + 1,
                            isCompleted: engine.completedStepIDs.contains(step.id),
                            isCurrent: step.id == engine.currentStepID,
                            requiredEquipment: stepEquipment,
                            timerRemaining: activeTimerStepID == step.id ? timerRemaining : nil,
                            timerRunning: activeTimerStepID == step.id,
                            onComplete: {
                                stopTimer()
                                engine.completeStep(step.id)
                            },
                            onSelectBranch: { targetID in
                                stopTimer()
                                engine.selectBranch(on: step.id, targetStepID: targetID)
                            },
                            onStartTimer: {
                                startTimer(for: step)
                            }
                        )
                    } else {
                        StepRow(step: step, index: index + 1)
                    }
                }
            } header: {
                HStack {
                    Text("Steps (\(checklist.orderedSteps.count))")
                    Spacer()
                    if inlineMode, let engine = inlineEngine {
                        Text(engine.progressLabel)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: Completion Banner
            if inlineMode, let engine = inlineEngine, engine.isComplete {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                            .symbolEffect(.bounce, value: engine.isComplete)

                        Text("Procedure Complete")
                            .font(.title2.weight(.bold))

                        Text("All \(engine.visibleSteps.count) steps completed successfully.")
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

                            if let nextIndex = siblings.firstIndex(where: { $0.id == checklist.id }),
                               nextIndex + 1 < siblings.count {
                                let nextProcedure = siblings[nextIndex + 1]
                                NavigationLink {
                                    ChecklistDetailView(checklist: nextProcedure)
                                } label: {
                                    Label("Next: \(nextProcedure.title)", systemImage: "arrow.right.circle.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .tint(.green)
                                .padding(.top, 4)
                            }
                        }

                        Button {
                            withAnimation {
                                stopTimer()
                                engine.reset()
                            }
                        } label: {
                            Label("Reset Procedure", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.blue)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle(checklist.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task {
            if inlineMode && inlineEngine == nil && !checklist.orderedSteps.isEmpty {
                inlineEngine = ExecutionEngine(checklist: checklist)
            }
        }
        .onDisappear {
            stopTimer()
        }
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
                Button {
                    if inlineMode {
                        inlineMode = false
                        inlineEngine = nil
                    } else {
                        inlineEngine = ExecutionEngine(checklist: checklist)
                        inlineMode = true
                    }
                } label: {
                    Label(
                        inlineMode ? "View Mode" : "Check-off Mode",
                        systemImage: inlineMode ? "eye" : "checklist.checked"
                    )
                }
                .disabled(checklist.orderedSteps.isEmpty)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button { showEditor = true } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button { showChangeLog = true } label: {
                    let count = checklist.safeChangeLog.count
                    Label("Change History (\(count))", systemImage: "clock.arrow.circlepath")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button { showIssues = true } label: {
                    let openCount = checklist.safeIssueReports.filter { $0.issueStatus == .open }.count
                    if openCount > 0 {
                        Label("Reported Issues (\(openCount) open)", systemImage: "exclamationmark.bubble")
                    } else {
                        Label("Reported Issues", systemImage: "exclamationmark.bubble")
                    }
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button { showTeam = true } label: {
                    let count = checklist.safeRoles.count
                    Label("Team (\(count))", systemImage: "person.2")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Label(
                    "Status: \(checklist.status.displayName)",
                    systemImage: checklist.status.systemImage
                )
                .foregroundStyle(checklist.status.color)
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Button {
                        exportFormat = .markdown
                        exportAndShare()
                    } label: {
                        Label("Markdown", systemImage: "doc.plaintext")
                    }
                    Button {
                        exportFormat = .html
                        exportAndShare()
                    } label: {
                        Label("HTML", systemImage: "globe")
                    }
                    #if canImport(UIKit)
                    Button {
                        exportFormat = .pdf
                        exportAndShare()
                    } label: {
                        Label("PDF", systemImage: "doc.richtext")
                    }
                    #endif
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    Task { @MainActor in
                        let available = await CloudKitSharingService.shared.checkAccountStatus()
                        if available {
                            showShareSheet = true
                        } else {
                            showShareError = true
                        }
                    }
                } label: {
                    Label("Share with Team", systemImage: "person.crop.circle.badge.plus")
                }
            }
        }
        #if canImport(UIKit)
        .fullScreenCover(isPresented: $showExecution) {
            ChecklistExecutionView(checklist: checklist)
        }
        #else
        .sheet(isPresented: $showExecution) {
            ChecklistExecutionView(checklist: checklist)
        }
        #endif
        .sheet(isPresented: $showPreparation, onDismiss: {
            if preparationCompleted {
                preparationCompleted = false
                showExecution = true
            }
        }) {
            PreparationView(checklist: checklist) {
                preparationCompleted = true
                showPreparation = false
            }
        }
        #if canImport(UIKit)
        .fullScreenCover(isPresented: $showEditor) {
            ChecklistEditorView(checklist: checklist)
                .nightVisionAware()
        }
        #else
        .sheet(isPresented: $showEditor) {
            ChecklistEditorView(checklist: checklist)
                .nightVisionAware()
        }
        #endif
        #if canImport(UIKit)
        .sheet(isPresented: $showExportShare) {
            if let url = exportFileURL {
                ShareSheet(items: [url])
            }
        }
        #else
        .onChange(of: showExportShare) { _, newValue in
            if newValue, let url = exportFileURL {
                openURL(url)
                showExportShare = false
            }
        }
        #endif
        .sheet(isPresented: $showApproval) {
            ApprovalView(checklist: checklist)
        }
        .alert("Share with Team", isPresented: $showShareSheet) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("CloudKit sharing requires additional setup. Procedures sync automatically across your iCloud devices.")
        }
        .alert("iCloud Required", isPresented: $showShareError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Sign in to iCloud in Settings to share procedures with your team.")
        }
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "The procedure could not be exported. Please try again or choose a different format.")
        }
        .alert(
            "Couldn\u{2019}t Save Status Change",
            isPresented: Binding(get: { statusSaveError != nil }, set: { if !$0 { statusSaveError = nil } })
        ) {
            Button("OK", role: .cancel) { statusSaveError = nil }
        } message: {
            Text(statusSaveError ?? "")
        }
        .sheet(isPresented: $showChangeLog) {
            NavigationStack {
                ChangeLogView(checklist: checklist)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showChangeLog = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showIssues) {
            NavigationStack {
                IssueListView(checklist: checklist)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showIssues = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showTeam) {
            NavigationStack {
                TeamManagementView(checklist: checklist)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showTeam = false }
                        }
                    }
            }
        }
    }

    private func exportAndShare() {
        let tempDir = FileManager.default.temporaryDirectory
        let safeName = checklist.title.replacingOccurrences(of: "/", with: "-")

        do {
            switch exportFormat {
            case .markdown:
                let content = ExportService.exportMarkdown(checklist: checklist)
                let url = tempDir.appendingPathComponent("\(safeName).md")
                try content.write(to: url, atomically: true, encoding: .utf8)
                exportFileURL = url
            case .html:
                let content = ExportService.exportHTML(checklist: checklist)
                let url = tempDir.appendingPathComponent("\(safeName).html")
                try content.write(to: url, atomically: true, encoding: .utf8)
                exportFileURL = url
            case .pdf:
                #if canImport(UIKit)
                let data = try ExportService.exportPDF(checklist: checklist)
                let url = tempDir.appendingPathComponent("\(safeName).pdf")
                try data.write(to: url)
                exportFileURL = url
                #else
                throw ExportError.pdfGenerationFailed
                #endif
            }
            showExportShare = true
        } catch {
            exportErrorMessage = error.localizedDescription
            showExportError = true
        }
    }

    private func submitForReview() {
        let previousStatus = checklist.status
        checklist.status = .pendingReview

        let logEntry = ChangeLogEntry(
            changeType: .submitted,
            summary: "Submitted for review",
            previousVersionNumber: checklist.versionNumber,
            newVersionNumber: checklist.versionNumber
        )
        logEntry.checklist = checklist
        modelContext.insert(logEntry)

        do {
            try modelContext.save()
        } catch {
            // Roll back the in-memory mutation so the UI reflects reality.
            checklist.status = previousStatus
            modelContext.delete(logEntry)
            statusSaveError = error.localizedDescription
        }
    }

    // MARK: - Timer (Inline Mode)

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

    // MARK: - Equipment Section

    @ViewBuilder
    private var equipmentSection: some View {
        let inventoryEquipment = checklist.safeEquipmentItems
        let freeTextEquipment = checklist.requiredEquipment

        if !inventoryEquipment.isEmpty || !freeTextEquipment.isEmpty {
            Section("Required Equipment") {
                ForEach(inventoryEquipment) { item in
                    HStack(spacing: 10) {
                        if let data = item.photoData {
                            CachedImage(data: data)
                                .scaledToFill()
                                .frame(width: 32, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 32)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name)
                                .font(.subheadline)
                            if !item.storageLocation.isEmpty {
                                Text(item.storageLocation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                ForEach(freeTextEquipment, id: \.self) { item in
                    Label(item, systemImage: "wrench.and.screwdriver")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
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
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
                stepIcon
            }
            .frame(width: 36, alignment: .center)

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
                        .font(step.stepType.font)
                        .foregroundStyle(step.stepType.color)
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
                            if attachment.mediaType == .image, let data = attachment.fileData {
                                CachedImage(data: data)
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

                // Reference file badge
                if let refName = step.referenceFileName, !refName.isEmpty {
                    Label(refName, systemImage: "doc.fill")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                }

                // Metadata badges
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
                    if step.requiresAcknowledgment {
                        Label("ACK Required", systemImage: "hand.raised.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.orange)
                    }
                    if !step.requiredEquipmentIDs.isEmpty {
                        Label("\(step.requiredEquipmentIDs.count) tools", systemImage: "wrench.and.screwdriver")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    @ViewBuilder
    private var stepIcon: some View {
        Image(systemName: step.stepType.systemImage)
            .foregroundStyle(step.stepType.color)
    }
}

// MARK: - Share Sheet

#if canImport(UIKit)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

#Preview {
    NavigationStack {
        ChecklistDetailView(checklist: {
            let cl = Checklist(title: "Sample Procedure", versionNumber: "v1.0", isEmergency: true)
            return cl
        }())
    }
}
