import SwiftUI
import SwiftData
import PhotosUI

struct EquipmentEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let existingEquipment: Equipment?
    @State private var name: String
    @State private var storageLocation: String
    @State private var equipmentCategory: String
    @State private var notes: String
    @State private var photoData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showFileSizeAlert = false

    private static let maxPhotoSize = 25_000_000 // 25 MB

    init(equipment: Equipment? = nil) {
        self.existingEquipment = equipment
        self._name = State(initialValue: equipment?.name ?? "")
        self._storageLocation = State(initialValue: equipment?.storageLocation ?? "")
        self._equipmentCategory = State(initialValue: equipment?.equipmentCategory ?? "")
        self._notes = State(initialValue: equipment?.notes ?? "")
        self._photoData = State(initialValue: equipment?.photoData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    if let photoData {
                        CachedImage(data: photoData)
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button("Remove Photo", role: .destructive) {
                            self.photoData = nil
                        }
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Select Photo", systemImage: "photo.badge.plus")
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        guard let newItem else { return }
                        Task {
                            if let data = try? await newItem.loadTransferable(type: Data.self) {
                                guard data.count <= Self.maxPhotoSize else {
                                    showFileSizeAlert = true
                                    selectedPhotoItem = nil
                                    return
                                }
                                photoData = data
                            }
                            selectedPhotoItem = nil
                        }
                    }
                }

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
            .alert("Photo Too Large", isPresented: $showFileSizeAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The selected photo exceeds the 25 MB size limit. Please choose a smaller image.")
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
        eq.photoData = photoData
    }
}
