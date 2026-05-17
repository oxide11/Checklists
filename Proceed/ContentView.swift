import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Checklist.title) private var checklists: [Checklist]
    @Query(sort: \ProcedureCategory.sortOrder) private var categories: [ProcedureCategory]
    @Query(sort: \Folder.sortOrder) private var folders: [Folder]
    @Query(sort: \Workflow.name) private var allWorkflows: [Workflow]
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var showSettings = false
    @State private var showNewChecklist = false
    @State private var showWorkflowEditor = false

    private var filteredChecklists: [Checklist] {
        guard !searchText.isEmpty else { return checklists }
        return checklists.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var emergencyChecklists: [Checklist] {
        filteredChecklists.filter(\.isEmergency)
    }

    /// Checklists that are not in any folder (shown in category sections)
    private var unfolderedChecklists: [Checklist] {
        filteredChecklists.filter { !$0.isEmergency && $0.folder == nil }
    }

    private var categorizedChecklists: [(ProcedureCategory, [Checklist])] {
        let nonEmergency = unfolderedChecklists
        let grouped = Dictionary(grouping: nonEmergency) { $0.category?.id }

        var result: [(ProcedureCategory, [Checklist])] = []
        for cat in categories {
            if let lists = grouped[cat.id], !lists.isEmpty {
                result.append((cat, lists.sorted { $0.title < $1.title }))
            }
        }
        // Uncategorized checklists
        if let uncategorized = grouped[nil], !uncategorized.isEmpty {
            let fallback = ProcedureCategory(name: "Uncategorized", systemImage: "questionmark.folder", sortOrder: 999)
            result.append((fallback, uncategorized.sorted { $0.title < $1.title }))
        }
        return result
    }

    /// Workflows that contain at least one procedure matching the current search.
    private var workflows: [(workflow: Workflow, procedures: [Checklist])] {
        let filteredIDs = Set(filteredChecklists.map(\.id))
        return allWorkflows.compactMap { wf in
            let procedures = wf.orderedProcedures.filter { filteredIDs.contains($0.id) }
            guard !procedures.isEmpty else { return nil }
            return (workflow: wf, procedures: procedures)
        }
    }

    /// Checklists within a specific folder, filtered by search
    private func checklistsInFolder(_ folder: Folder) -> [Checklist] {
        let items = folder.safeChecklists.filter { !$0.isEmergency }
        let filtered: [Checklist]
        if searchText.isEmpty {
            filtered = items
        } else {
            filtered = items.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        return filtered.sorted { $0.title < $1.title }
    }

    private func moveChecklist(id: String, toFolder folder: Folder?) {
        guard let uuid = UUID(uuidString: id),
              let checklist = checklists.first(where: { $0.id == uuid }) else { return }
        checklist.folder = folder
    }

    var body: some View {
        NavigationSplitView {
            List {
                if !emergencyChecklists.isEmpty {
                    Section {
                        ForEach(emergencyChecklists) { checklist in
                            NavigationLink {
                                ChecklistDetailView(checklist: checklist)
                            } label: {
                                ChecklistRow(checklist: checklist)
                            }
                            .draggable(checklist.id.uuidString)
                        }
                    } header: {
                        Label("Emergency", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline.weight(.bold))
                    }
                }

                // Folders section
                if !folders.isEmpty {
                    Section {
                        ForEach(folders) { folder in
                            let folderItems = checklistsInFolder(folder)
                            DisclosureGroup {
                                if folderItems.isEmpty {
                                    Text("No procedures")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                } else {
                                    ForEach(folderItems) { checklist in
                                        NavigationLink {
                                            ChecklistDetailView(checklist: checklist)
                                        } label: {
                                            ChecklistRow(checklist: checklist)
                                        }
                                        .draggable(checklist.id.uuidString)
                                    }
                                }
                            } label: {
                                Label {
                                    HStack {
                                        Text(folder.name)
                                        Spacer()
                                        Text("\(folderItems.count)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: folder.systemImage)
                                }
                            }
                            .dropDestination(for: String.self) { items, _ in
                                for id in items {
                                    moveChecklist(id: id, toFolder: folder)
                                }
                                return !items.isEmpty
                            }
                        }
                    } header: {
                        Label("Folders", systemImage: "folder.fill")
                    }
                }

                // Workflows section
                if !workflows.isEmpty {
                    Section {
                        ForEach(workflows, id: \.workflow.id) { entry in
                            NavigationLink {
                                WorkflowDetailView(workflow: entry.workflow)
                            } label: {
                                Label {
                                    HStack {
                                        Text(entry.workflow.name)
                                        Spacer()
                                        Text("\(entry.procedures.count)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: "arrow.triangle.branch")
                                }
                            }
                        }
                    } header: {
                        Label("Workflows", systemImage: "arrow.triangle.branch")
                    }
                }

                ForEach(categorizedChecklists, id: \.0.id) { category, lists in
                    Section {
                        ForEach(lists) { checklist in
                            NavigationLink {
                                ChecklistDetailView(checklist: checklist)
                            } label: {
                                ChecklistRow(checklist: checklist)
                            }
                            .draggable(checklist.id.uuidString)
                        }
                    } header: {
                        if let emoji = category.emoji, !emoji.isEmpty {
                            Label {
                                Text(category.name)
                            } icon: {
                                Text(emoji)
                            }
                        } else {
                            Label(category.name, systemImage: category.systemImage)
                        }
                    }
                    .dropDestination(for: String.self) { items, _ in
                        for id in items {
                            moveChecklist(id: id, toFolder: nil)
                        }
                        return !items.isEmpty
                    }
                }

                // Management links
                Section {
                    NavigationLink {
                        EquipmentInventoryView()
                    } label: {
                        Label("Equipment Inventory", systemImage: "wrench.and.screwdriver")
                    }

                    NavigationLink {
                        PendingApprovalsView()
                    } label: {
                        Label("Pending Approvals", systemImage: "checkmark.seal")
                    }
                } header: {
                    Text("Management")
                }
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, prompt: "Search procedures")
            .navigationTitle("Proceed")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showNewChecklist = true } label: {
                        Label("New Procedure", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button { showWorkflowEditor = true } label: {
                        Label("Create Workflow", systemImage: "arrow.triangle.branch")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button { showSettings = true } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
            .overlay {
                if filteredChecklists.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else if checklists.isEmpty {
                    ContentUnavailableView(
                        "No Procedures",
                        systemImage: "checklist",
                        description: Text("Import a manual or create a procedure to get started.")
                    )
                }
            }
            .fullScreenCover(isPresented: $showNewChecklist) {
                ChecklistEditorView()
                    .nightVisionAware()
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showSettings = false }
                            }
                        }
                }
                .nightVisionAware()
            }
            .sheet(isPresented: $showWorkflowEditor) {
                NavigationStack {
                    WorkflowEditorView()
                }
            }
            .task {
                SampleDataGenerator.populateIfNeeded(context: modelContext)
            }
        } detail: {
            ContentUnavailableView {
                Label("Select a Procedure", systemImage: "checklist")
            } description: {
                Text("Choose a procedure from the sidebar to begin, or create a new one.")
            } actions: {
                Button {
                    showNewChecklist = true
                } label: {
                    Label("New Procedure", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Checklist Row

struct ChecklistRow: View {
    let checklist: Checklist

    private var stepCount: Int {
        checklist.orderedSteps.count
    }

    @ViewBuilder
    private var categoryIcon: some View {
        if checklist.isEmergency {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.red)
        } else if let emoji = checklist.category?.emoji, !emoji.isEmpty {
            Text(emoji)
                .font(.title3)
        } else {
            Image(systemName: checklist.category?.systemImage ?? "folder.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            categoryIcon
                .frame(width: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(checklist.title)
                    .font(.body.weight(.semibold))

                HStack(spacing: 6) {
                    Text(checklist.versionNumber)
                    Text("\u{00B7}")
                    Text("\(stepCount) steps")

                    if checklist.isOutdated {
                        Text("REVIEW DUE")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange, in: Capsule())
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityRowLabel)
    }

    private var accessibilityRowLabel: String {
        var parts: [String] = []
        if checklist.isEmergency { parts.append("Emergency") }
        parts.append(checklist.title)
        parts.append(checklist.versionNumber)
        parts.append("\(stepCount) steps")
        if checklist.isOutdated { parts.append("review due") }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Checklist.self, inMemory: true)
}
