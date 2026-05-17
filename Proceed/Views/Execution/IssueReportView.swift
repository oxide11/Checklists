import SwiftUI
import SwiftData
import PhotosUI

struct IssueReportView: View {
    let checklist: Checklist
    let currentStep: ChecklistStep?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var issueDescription = ""
    @State private var reason = ""
    @State private var severity: IssueSeverity = .medium
    @State private var photoData: Data? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showFileSizeAlert = false
    @State private var submitError: String? = nil

    private static let maxPhotoSize = 25_000_000 // 25 MB

    var body: some View {
        NavigationStack {
            Form {
                // Current step context
                if let step = currentStep {
                    Section("Step Context") {
                        HStack(spacing: 8) {
                            Image(systemName: step.stepType.systemImage)
                                .foregroundStyle(step.stepType.color)
                            Text(step.stepType == .decision ? (step.question ?? step.text) : step.text)
                                .font(.subheadline)
                        }
                    }
                }

                Section("What's Not Working?") {
                    TextField("Describe the issue...", text: $issueDescription, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Why Can't You Proceed?") {
                    TextField("Reason...", text: $reason, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Severity") {
                    Picker("Severity", selection: $severity) {
                        ForEach(IssueSeverity.allCases) { level in
                            Label {
                                Text(level.displayName)
                            } icon: {
                                Image(systemName: level.systemImage)
                            }
                            .tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Photo Evidence") {
                    if let data = photoData {
                        CachedImage(data: data)
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button("Remove Photo", role: .destructive) {
                            photoData = nil
                            selectedPhotoItem = nil
                        }
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(photoData == nil ? "Attach Photo" : "Change Photo", systemImage: "camera.fill")
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                guard data.count <= Self.maxPhotoSize else {
                                    showFileSizeAlert = true
                                    selectedPhotoItem = nil
                                    return
                                }
                                photoData = data
                            }
                        }
                    }
                }
            }
            .navigationTitle("Report Issue")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        do {
                            try submitIssue()
                            dismiss()
                        } catch {
                            submitError = error.localizedDescription
                        }
                    }
                    .disabled(issueDescription.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Photo Too Large", isPresented: $showFileSizeAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The selected photo exceeds the 25 MB size limit. Please choose a smaller image.")
            }
            .alert(
                "Couldn\u{2019}t Submit Report",
                isPresented: Binding(get: { submitError != nil }, set: { if !$0 { submitError = nil } })
            ) {
                Button("OK", role: .cancel) { submitError = nil }
            } message: {
                Text(submitError ?? "")
            }
        }
    }

    private func submitIssue() throws {
        let report = IssueReport(
            issueDescription: issueDescription.trimmingCharacters(in: .whitespaces),
            reason: reason.trimmingCharacters(in: .whitespaces),
            severity: severity,
            stepID: currentStep?.id,
            stepText: currentStep?.text
        )
        report.photoData = photoData
        report.checklist = checklist
        modelContext.insert(report)
        try modelContext.save()
    }
}
