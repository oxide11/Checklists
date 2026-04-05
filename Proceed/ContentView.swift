import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Checklist.title) private var checklists: [Checklist]
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var showSettings = false
    @State private var showNewChecklist = false

    private var filteredChecklists: [Checklist] {
        guard !searchText.isEmpty else { return checklists }
        return checklists.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var emergencyChecklists: [Checklist] {
        filteredChecklists.filter(\.isEmergency)
    }

    private var categorizedChecklists: [(ChecklistCategory, [Checklist])] {
        let nonEmergency = filteredChecklists.filter { !$0.isEmergency }
        return Dictionary(grouping: nonEmergency, by: \.category)
            .sorted { $0.key.displayName < $1.key.displayName }
            .map { ($0.key, $0.value) }
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
                        }
                    } header: {
                        Label("Emergency", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline.weight(.bold))
                    }
                }

                ForEach(categorizedChecklists, id: \.0) { category, lists in
                    Section {
                        ForEach(lists) { checklist in
                            NavigationLink {
                                ChecklistDetailView(checklist: checklist)
                            } label: {
                                ChecklistRow(checklist: checklist)
                            }
                        }
                    } header: {
                        Label(category.displayName, systemImage: category.systemImage)
                    }
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
            .sheet(isPresented: $showNewChecklist) {
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
            .task {
                SampleDataGenerator.populateIfNeeded(context: modelContext)
            }
        } detail: {
            ContentUnavailableView(
                "Select a Procedure",
                systemImage: "checklist",
                description: Text("Choose a procedure from the sidebar to begin.")
            )
        }
    }
}

// MARK: - Checklist Row

struct ChecklistRow: View {
    let checklist: Checklist

    private var stepCount: Int {
        checklist.orderedSteps.count
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: checklist.isEmergency
                  ? "exclamationmark.triangle.fill"
                  : checklist.category.systemImage)
                .font(.title3)
                .foregroundStyle(checklist.isEmergency ? .red : .accentColor)
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Checklist.self, inMemory: true)
}
