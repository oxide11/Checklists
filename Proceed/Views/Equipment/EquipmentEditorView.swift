import SwiftUI
import SwiftData

struct EquipmentEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let existingEquipment: Equipment?
    @State private var name: String
    @State private var storageLocation: String
    @State private var equipmentCategory: String
    @State private var notes: String

    init(equipment: Equipment? = nil) {
        self.existingEquipment = equipment
        self._name = State(initialValue: equipment?.name ?? "")
        self._storageLocation = State(initialValue: equipment?.storageLocation ?? "")
        self._equipmentCategory = State(initialValue: equipment?.equipmentCategory ?? "")
        self._notes = State(initialValue: equipment?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Storage Location", text: $storageLocation)
                    TextField("Category (e.g., Tools, Safety, Fluids)", text: $equipmentCategory)
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle(existingEquipment == nil ? "New Equipment" : "Edit Equipment")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let eq = existingEquipment ?? Equipment()
        if existingEquipment == nil { modelContext.insert(eq) }
        eq.name = name.trimmingCharacters(in: .whitespaces)
        eq.storageLocation = storageLocation.trimmingCharacters(in: .whitespaces)
        eq.equipmentCategory = equipmentCategory.trimmingCharacters(in: .whitespaces)
        eq.notes = notes.isEmpty ? nil : notes
    }
}
