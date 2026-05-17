import SwiftUI
import SwiftData

struct FolderManagerView: View {
    @Query(sort: \Folder.sortOrder) private var folders: [Folder]
    @Environment(\.modelContext) private var modelContext
    @State private var showNewFolder = false
    @State private var newName = ""
    @State private var pendingDelete: [Folder] = []

    var body: some View {
        List {
            if folders.isEmpty {
                Text("No folders yet. Create folders to organize procedures by area of interest.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            ForEach(folders) { folder in
                HStack(spacing: 12) {
                    Image(systemName: folder.systemImage)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(folder.name)
                        let count = folder.safeChecklists.count
                        Text("\(count) procedure\(count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                pendingDelete = offsets.map { folders[$0] }
            }

            Button { showNewFolder = true } label: {
                Label("New Folder", systemImage: "plus.circle.fill")
            }
        }
        .navigationTitle("Folders")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("New Folder", isPresented: $showNewFolder) {
            TextField("Name", text: $newName)
            Button("Add") {
                guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                let folder = Folder(
                    name: newName.trimmingCharacters(in: .whitespaces),
                    sortOrder: folders.count
                )
                modelContext.insert(folder)
                newName = ""
            }
            Button("Cancel", role: .cancel) { newName = "" }
        } message: {
            Text("Enter a name for the new folder.")
        }
        .confirmationDialog(
            deleteMessage,
            isPresented: Binding(get: { !pendingDelete.isEmpty }, set: { if !$0 { pendingDelete = [] } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                for folder in pendingDelete { modelContext.delete(folder) }
                pendingDelete = []
            }
            Button("Cancel", role: .cancel) { pendingDelete = [] }
        } message: {
            Text("Procedures inside will become uncategorized. This cannot be undone.")
        }
    }

    private var deleteMessage: String {
        pendingDelete.count == 1
            ? "Delete folder \u{201C}\(pendingDelete[0].name)\u{201D}?"
            : "Delete \(pendingDelete.count) folders?"
    }
}
