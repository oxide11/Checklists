import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

struct StepEditorView: View {
    @Binding var step: EditableStep
    let allSteps: [EditableStep]

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showVideoPicker = false
    @State private var showAudioPicker = false

    /// Steps available as branch targets (excludes current step).
    private var targetableSteps: [(index: Int, step: EditableStep)] {
        allSteps.enumerated()
            .filter { $0.element.id != step.id }
            .map { (index: $0.offset, step: $0.element) }
    }

    var body: some View {
        Form {
            typeSection
            contentSection

            if step.stepType == .decision {
                decisionLogicSection
            }

            mediaSection
            metadataSection
        }
        .navigationTitle("Edit Step")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onChange(of: step.stepType) { _, newType in
            // Auto-configure sensible defaults on type change
            if newType == .warning || newType == .caution {
                step.requiresAcknowledgment = true
            }
            if newType == .decision && step.branchOptions.isEmpty {
                step.branchOptions = [
                    EditableBranchOption(label: "Yes"),
                    EditableBranchOption(label: "No")
                ]
            }
        }
    }

    // MARK: - Type Section

    private var typeSection: some View {
        Section {
            Picker("Step Type", selection: $step.stepType) {
                Text("Action").tag(StepType.action)
                Text("Decision").tag(StepType.decision)
                Text("Warning").tag(StepType.warning)
                Text("Caution").tag(StepType.caution)
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Type")
        } footer: {
            Text(stepTypeDescription)
        }
    }

    private var stepTypeDescription: String {
        switch step.stepType {
        case .action: "A linear procedural step the operator performs."
        case .decision: "A branching point with multiple outcome paths."
        case .warning: "A critical safety alert requiring acknowledgment."
        case .caution: "An important notice requiring acknowledgment."
        }
    }

    // MARK: - Content Section

    private var contentSection: some View {
        Section("Content") {
            TextField(
                step.stepType == .decision ? "Step description" : "Step instruction",
                text: $step.text,
                axis: .vertical
            )
            .lineLimit(2...6)

            TextField("Note (optional)", text: $step.note, axis: .vertical)
                .lineLimit(1...3)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Decision Logic Section

    private var decisionLogicSection: some View {
        Section {
            TextField("Decision question", text: $step.question, axis: .vertical)
                .lineLimit(1...4)
                .font(.body.weight(.medium))

            ForEach($step.branchOptions) { $option in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "arrow.turn.down.right")
                            .foregroundStyle(.cyan)
                            .font(.caption)
                        TextField("Option label", text: $option.label)
                    }

                    Picker("Goes to", selection: $option.targetStepID) {
                        Text("None (not linked)")
                            .tag(UUID?.none)

                        ForEach(targetableSteps, id: \.step.id) { index, targetStep in
                            Text(stepPickerLabel(index: index, step: targetStep))
                                .tag(Optional(targetStep.id))
                        }
                    }
                    .font(.subheadline)
                }
                .padding(.vertical, 4)
            }
            .onDelete { offsets in
                step.branchOptions.remove(atOffsets: offsets)
            }

            Button {
                withAnimation {
                    step.branchOptions.append(EditableBranchOption())
                }
            } label: {
                Label("Add Branch", systemImage: "plus.circle")
            }
        } header: {
            Text("Decision Logic")
        } footer: {
            Text("Each branch can target another step in the procedure. Unlinked branches will follow the default linear order.")
        }
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        Section("Options") {
            Toggle(isOn: $step.requiresAcknowledgment) {
                Label("Requires Acknowledgment", systemImage: "hand.raised.fill")
            }

            Toggle(isOn: $step.isCriticalFailure) {
                Label("Critical Failure", systemImage: "bolt.fill")
            }

            // Timer
            Toggle(isOn: Binding(
                get: { step.timerDuration != nil },
                set: { step.timerDuration = $0 ? 60 : nil }
            )) {
                Label("Timer", systemImage: "timer")
            }

            if step.timerDuration != nil {
                HStack {
                    Text("Duration")
                    Spacer()
                    TextField("sec", value: Binding(
                        get: { step.timerDuration ?? 60 },
                        set: { step.timerDuration = max(1, $0) }
                    ), format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    Text("seconds")
                        .foregroundStyle(.secondary)
                }
            }

            TextField("Hardware Part Link (optional)", text: $step.hardwarePartLink)
        }
    }

    // MARK: - Media Section

    private var mediaSection: some View {
        Section {
            // Existing attachments
            ForEach(step.mediaAttachments) { attachment in
                HStack(spacing: 12) {
                    Image(systemName: attachment.mediaType.systemImage)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(attachment.fileName.isEmpty ? attachment.mediaType.displayName : attachment.fileName)
                            .font(.subheadline)
                        if !attachment.caption.isEmpty {
                            Text(attachment.caption)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let data = attachment.fileData {
                            Text(formatBytes(data.count))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    // Thumbnail for images
                    if attachment.mediaType == .image, let data = attachment.fileData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .onDelete { offsets in
                step.mediaAttachments.remove(atOffsets: offsets)
            }

            // Add media buttons
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("Add Photo", systemImage: "photo.badge.plus")
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        let attachment = EditableMediaAttachment(
                            mediaType: .image,
                            fileName: "Photo \(step.mediaAttachments.count + 1).jpg",
                            fileData: data
                        )
                        step.mediaAttachments.append(attachment)
                    }
                    selectedPhotoItem = nil
                }
            }

            Button {
                showVideoPicker = true
            } label: {
                Label("Add Video", systemImage: "video.badge.plus")
            }

            Button {
                showAudioPicker = true
            } label: {
                Label("Add Audio", systemImage: "waveform.badge.plus")
            }
        } header: {
            Text("Media")
        } footer: {
            Text("Attach photos, videos, or audio recordings to provide visual or auditory reference for this step.")
        }
        .fileImporter(isPresented: $showVideoPicker, allowedContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie]) { result in
            handleFileImport(result: result, mediaType: .video)
        }
        .fileImporter(isPresented: $showAudioPicker, allowedContentTypes: [.audio, .mp3, .mpeg4Audio]) { result in
            handleFileImport(result: result, mediaType: .audio)
        }
    }

    // MARK: - Helpers

    private func stepPickerLabel(index: Int, step: EditableStep) -> String {
        let preview = step.text.isEmpty ? "Untitled" : String(step.text.prefix(35))
        return "Step \(index + 1): \(preview)"
    }

    private func handleFileImport(result: Result<URL, Error>, mediaType: MediaType) {
        guard case .success(let url) = result else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        if let data = try? Data(contentsOf: url) {
            let attachment = EditableMediaAttachment(
                mediaType: mediaType,
                fileName: url.lastPathComponent,
                fileData: data
            )
            step.mediaAttachments.append(attachment)
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
