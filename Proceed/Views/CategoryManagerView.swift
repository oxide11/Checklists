import SwiftUI
import SwiftData

struct CategoryManagerView: View {
    @Query(sort: \ProcedureCategory.sortOrder) private var categories: [ProcedureCategory]
    @Environment(\.modelContext) private var modelContext
    @State private var showNewCategory = false
    @State private var newName = ""
    @State private var newIcon = "folder.fill"
    @State private var newEmoji = ""
    @State private var pendingDelete: [ProcedureCategory] = []

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
                    if let emoji = cat.emoji, !emoji.isEmpty {
                        Text(emoji)
                            .font(.title3)
                            .frame(width: 24)
                    } else {
                        Image(systemName: cat.systemImage)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 24)
                    }
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
                pendingDelete = offsets
                    .compactMap { categories.indices.contains($0) ? categories[$0] : nil }
                    .filter { !$0.isDefault }
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
            TextField("Emoji (optional)", text: $newEmoji)
            Button("Add") {
                guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                let cat = ProcedureCategory(
                    name: newName.trimmingCharacters(in: .whitespaces),
                    systemImage: newIcon,
                    sortOrder: categories.count,
                    isDefault: false,
                    emoji: newEmoji.isEmpty ? nil : String(newEmoji.prefix(1))
                )
                modelContext.insert(cat)
                newName = ""
                newIcon = "folder.fill"
                newEmoji = ""
            }
            Button("Cancel", role: .cancel) {
                newName = ""
                newEmoji = ""
            }
        } message: {
            Text("Enter a name and optional emoji for the new category.")
        }
        .confirmationDialog(
            deleteMessage,
            isPresented: Binding(get: { !pendingDelete.isEmpty }, set: { if !$0 { pendingDelete = [] } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                for cat in pendingDelete { modelContext.delete(cat) }
                pendingDelete = []
            }
            Button("Cancel", role: .cancel) { pendingDelete = [] }
        } message: {
            Text("Procedures in this category will become uncategorized. This cannot be undone.")
        }
    }

    private var deleteMessage: String {
        pendingDelete.count == 1
            ? "Delete category \u{201C}\(pendingDelete[0].name)\u{201D}?"
            : "Delete \(pendingDelete.count) categories?"
    }
}
