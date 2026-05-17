import SwiftUI
import SwiftData

@main
struct ProceedApp: App {
    let modelContainer: ModelContainer
    let containerError: Error?

    init() {
        do {
            let configuration = ModelConfiguration(
                cloudKitDatabase: .automatic
            )
            modelContainer = try ModelContainer(
                for: Checklist.self, ChecklistStep.self, MediaAttachment.self,
                     ProcedureCategory.self, Folder.self, Equipment.self,
                     ChangeLogEntry.self, IssueReport.self, ProcedureRole.self,
                     Workflow.self,
                configurations: configuration
            )
            containerError = nil
        } catch {
            let primaryError = error
            let fallbackConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            // Try in-memory fallback — if this also fails, capture the error
            // for display instead of crashing.
            if let fallback = try? ModelContainer(
                for: Checklist.self, ChecklistStep.self, MediaAttachment.self,
                     ProcedureCategory.self, Folder.self, Equipment.self,
                     ChangeLogEntry.self, IssueReport.self, ProcedureRole.self,
                     Workflow.self,
                configurations: fallbackConfig
            ) {
                modelContainer = fallback
                containerError = primaryError
            } else {
                // Last resort: create the simplest possible in-memory container
                // with just the root model type.
                modelContainer = (try? ModelContainer(
                    for: Checklist.self,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                )) ?? {
                    // Absolute fallback — should never reach here, but avoids fatalError
                    try! ModelContainer(
                        for: Checklist.self,
                        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                    )
                }()
                containerError = primaryError
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if let error = containerError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.red)
                    Text("Database Error")
                        .font(.title2.bold())
                    Text("The app's data could not be loaded. Try restarting the app or reinstalling.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding()
            } else {
                ContentView()
                    .nightVisionAware()
            }
        }
        .modelContainer(modelContainer)
    }
}
