import SwiftUI
import SwiftData

struct EquipmentInventoryView: View {
    @Query(sort: \Equipment.name) private var equipment: [Equipment]
    @Environment(\.modelContext) private var modelContext
    @State private var showEditor = false
    @State private var selectedEquipment: Equipment? = nil
    @State private var searchText = ""

    private var filteredEquipment: [Equipment] {
        guard !searchText.isEmpty else { return equipment }
        return equipment.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.storageLocation.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedEquipment: [(String, [Equipment])] {
        Dictionary(grouping: filteredEquipment) {
            $0.equipmentCategory.isEmpty ? "Uncategorized" : $0.equipmentCategory
        }
        .sorted { $0.key < $1.key }
        .map { ($0.key, $0.value) }
    }

    var body: some View {
        List {
            if equipment.isEmpty {
                ContentUnavailableView(
                    "No Equipment",
                    systemImage: "wrench.and.screwdriver",
                    description: Text("Add tools and equipment to track storage locations and link to procedures.")
                )
            } else {
                ForEach(groupedEquipment, id: \.0) { category, items in
                    Section(category) {
                        ForEach(items) { item in
                            Button {
                                selectedEquipment = item
                            } label: {
                                EquipmentRow(equipment: item)
                            }
                        }
                        .onDelete { offsets in
                            for i in offsets { modelContext.delete(items[i]) }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search equipment")
        .navigationTitle("Equipment")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showEditor = true } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            EquipmentEditorView()
                .nightVisionAware()
        }
        .sheet(item: $selectedEquipment) { item in
            EquipmentEditorView(equipment: item)
                .nightVisionAware()
        }
    }
}

struct EquipmentRow: View {
    let equipment: Equipment

    var body: some View {
        HStack(spacing: 12) {
            if let data = equipment.photoData {
                CachedImage(data: data)
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 40, height: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(equipment.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                if !equipment.storageLocation.isEmpty {
                    Label(equipment.storageLocation, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
