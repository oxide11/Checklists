import SwiftUI
import SwiftData

struct ChecklistEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ProcedureCategory.sortOrder) private var categories: [ProcedureCategory]
    @Query(sort: \Folder.sortOrder) private var folders: [Folder]

    let existingChecklist: Checklist?
    @State private var editable: EditableChecklist
    @State private var saveError: String? = nil

    init(checklist: Checklist? = nil) {
        self.existingChecklist = checklist
        self._editable = State(
            initialValue: checklist.map { EditableChecklist(from: $0) } ?? EditableChecklist()
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                preparationSection
                stepsSection
            }
            .navigationTitle(existingChecklist == nil ? "New Procedure" : "Edit Procedure")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try editable.save(to: modelContext, updating: existingChecklist)
                            dismiss()
                        } catch {
                            saveError = error.localizedDescription
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!editable.isValid)
                }
            }
            .alert(
                "Couldn\u{2019}t Save Procedure",
                isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
            ) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        Section {
            TextField("Procedure Title", text: $editable.title)

            Picker("Category", selection: $editable.categoryID) {
                Text("None").tag(UUID?.none)
                ForEach(categories) { cat in
                    Label(cat.name, systemImage: cat.systemImage)
                        .tag(Optional(cat.id))
                }
            }

            if !folders.isEmpty {
                Picker("Folder", selection: $editable.folderID) {
                    Text("None").tag(UUID?.none)
                    ForEach(folders) { folder in
                        Label(folder.name, systemImage: folder.systemImage)
                            .tag(Optional(folder.id))
                    }
                }
            }

            HStack {
                Text("Version")
                Spacer()
                Text(editable.versionNumber)
                    .foregroundStyle(.secondary)
                if existingChecklist != nil {
                    Button("Major Bump") {
                        editable.bumpMajorVersion()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Toggle(isOn: $editable.isEmergency) {
                Label("Emergency Procedure", systemImage: "exclamationmark.triangle.fill")
            }
        } header: {
            Text("Details")
        }
    }

    // MARK: - Preparation Section

    private var preparationSection: some View {
        Section {
            TextField("Preparation Notes", text: $editable.preparationNotes, axis: .vertical)
                .lineLimit(2...6)

            ForEach(editable.requiredEquipment.indices, id: \.self) { index in
                HStack {
                    Image(systemName: "wrench.and.screwdriver")
                        .foregroundStyle(.secondary)
                    TextField("Equipment item", text: $editable.requiredEquipment[index])
                }
            }
            .onDelete { offsets in
                editable.requiredEquipment.remove(atOffsets: offsets)
            }

            Button {
                editable.requiredEquipment.append("")
            } label: {
                Label("Add Equipment", systemImage: "plus.circle")
            }
        } header: {
            Text("Preparation")
        } footer: {
            Text("List tools, safety gear, and conditions needed before starting this procedure.")
        }
    }

    // MARK: - Steps Section

    private var stepsSection: some View {
        Section {
            if editable.steps.isEmpty {
                Text("No steps yet. Add your first step below.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach($editable.steps) { $step in
                    NavigationLink {
                        StepEditorView(step: $step, allSteps: editable.steps)
                    } label: {
                        stepSummaryRow(step: step)
                    }
                }
                .onMove { from, to in
                    editable.steps.move(fromOffsets: from, toOffset: to)
                }
                .onDelete { offsets in
                    let deletedIDs = Set(offsets.map { editable.steps[$0].id })
                    editable.steps.remove(atOffsets: offsets)
                    cleanupBranchReferences(deletedIDs: deletedIDs)
                }
            }

            Button {
                withAnimation {
                    editable.steps.append(EditableStep())
                }
            } label: {
                Label("Add Step", systemImage: "plus.circle.fill")
            }
        } header: {
            HStack {
                Text("Steps (\(editable.steps.count))")
                Spacer()
                if !editable.steps.isEmpty {
                    EditButton()
                        .font(.subheadline)
                }
            }
        } footer: {
            if !editable.steps.isEmpty {
                Text("Tap a step to edit. Use Edit to reorder or delete.")
            }
        }
    }

    // MARK: - Step Summary Row

    @ViewBuilder
    private func stepSummaryRow(step: EditableStep) -> some View {
        let index = (editable.steps.firstIndex(where: { $0.id == step.id }) ?? 0) + 1

        HStack(spacing: 10) {
            VStack(spacing: 2) {
                Text("\(index)")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
                stepTypeIcon(step.stepType)
                    .font(.body)
            }
            .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text(step.text.isEmpty ? "Untitled Step" : step.text)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundStyle(step.text.isEmpty ? .secondary : .primary)

                HStack(spacing: 6) {
                    Text(step.stepType.rawValue.capitalized)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(step.stepType.color)

                    if step.stepType == .decision && !step.branchOptions.isEmpty {
                        Text("\u{00B7} \(step.branchOptions.count) branches")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if step.timerDuration != nil {
                        Image(systemName: "timer")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }

                    if step.isCriticalFailure {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func stepTypeIcon(_ type: StepType) -> some View {
        Image(systemName: type.systemImage)
            .foregroundStyle(type.color)
    }

    private func cleanupBranchReferences(deletedIDs: Set<UUID>) {
        for i in editable.steps.indices {
            for j in editable.steps[i].branchOptions.indices {
                if let target = editable.steps[i].branchOptions[j].targetStepID,
                   deletedIDs.contains(target) {
                    editable.steps[i].branchOptions[j].targetStepID = nil
                }
            }
        }
    }
}
