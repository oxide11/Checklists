import SwiftUI
import SwiftData

struct CategoryManagerView: View {
    @Query(sort: \ProcedureCategory.sortOrder) private var categories: [ProcedureCategory]
    @Environment(\.modelContext) private var modelContext
    @State private var showNewCategory = false
    @State private var newName = ""
    @State private var newIcon = "folder.fill"

    private let iconOptions = [
        "folder.fill", "airplane", "leaf.fill", "car.fill", "hammer.fill",
        "cross.case.fill", "book.fill", "wrench.fill", "gearshape.fill",
        "flame.fill", "bolt.fill", "heart.fill", "star.fill", "flag.fill",
        "building.2.fill", "stethoscope", "desktopcomputer", "train.side.front.car",
        "shield.fill", "bicycle", "drop.fill", "sun.max.fill"
    ]

    var body: some View {
        List {
            ForEach(categories) { cat in
                HStack(spacing: 12) {
                    Image(systemName: cat.systemImage)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 24)
                    Text(cat.name)
                    Spacer()
                    if cat.isDefault {
                        Text("Built-in")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                for i in offsets {
                    let cat = categories[i]
                    guard !cat.isDefault else { continue }
                    modelContext.delete(cat)
                }
            }

            Button { showNewCategory = true } label: {
                Label("New Category", systemImage: "plus.circle.fill")
            }
        }
        .navigationTitle("Categories")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("New Category", isPresented: $showNewCategory) {
            TextField("Name", text: $newName)
            Button("Add") {
                guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                let cat = ProcedureCategory(
                    name: newName.trimmingCharacters(in: .whitespaces),
                    systemImage: newIcon,
                    sortOrder: categories.count,
                    isDefault: false
                )
                modelContext.insert(cat)
                newName = ""
                newIcon = "folder.fill"
            }
            Button("Cancel", role: .cancel) { newName = "" }
        } message: {
            Text("Enter a name for the new category.")
        }
    }
}
