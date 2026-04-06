import SwiftUI

struct PreparationView: View {
    let checklist: Checklist
    let onBegin: () -> Void

    @State private var acknowledgedItems: Set<Int> = []
    @State private var acknowledgedEquipment: Set<UUID> = []

    private var allAcknowledged: Bool {
        let freeTextDone = checklist.requiredEquipment.isEmpty ||
            acknowledgedItems.count >= checklist.requiredEquipment.count
        let inventoryItems = checklist.safeEquipmentItems
        let inventoryDone = inventoryItems.isEmpty ||
            acknowledgedEquipment.count >= inventoryItems.count
        return freeTextDone && inventoryDone
    }

    var body: some View {
        NavigationStack {
            List {
                if let notes = checklist.preparationNotes, !notes.isEmpty {
                    Section("Notes") {
                        Text(notes)
                            .font(.body)
                    }
                }

                if !checklist.requiredEquipment.isEmpty {
                    Section("Required Equipment") {
                        ForEach(Array(checklist.requiredEquipment.enumerated()), id: \.offset) { index, item in
                            Button {
                                if acknowledgedItems.contains(index) {
                                    acknowledgedItems.remove(index)
                                } else {
                                    acknowledgedItems.insert(index)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: acknowledgedItems.contains(index)
                                          ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(acknowledgedItems.contains(index) ? .green : .secondary)
                                        .font(.title3)
                                    Text(item)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }

                if !checklist.safeEquipmentItems.isEmpty {
                    Section("From Inventory") {
                        ForEach(checklist.safeEquipmentItems) { item in
                            Button {
                                if acknowledgedEquipment.contains(item.id) {
                                    acknowledgedEquipment.remove(item.id)
                                } else {
                                    acknowledgedEquipment.insert(item.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: acknowledgedEquipment.contains(item.id)
                                          ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(acknowledgedEquipment.contains(item.id) ? .green : .secondary)
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .foregroundStyle(.primary)
                                        if !item.storageLocation.isEmpty {
                                            Label(item.storageLocation, systemImage: "mappin.and.ellipse")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Section {
                    Button(action: onBegin) {
                        Label("Begin Procedure", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } footer: {
                    if !allAcknowledged {
                        Label(
                            "Some equipment items have not been acknowledged.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Preparation")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .nightVisionAware()
    }
}
