import SwiftUI
import SwiftData

@main
struct ProceedApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let configuration = ModelConfiguration(
                cloudKitDatabase: .automatic
            )
            modelContainer = try ModelContainer(
                for: Checklist.self, ChecklistStep.self, MediaAttachment.self,
                     ProcedureCategory.self, Folder.self, Equipment.self,
                configurations: configuration
            )
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .nightVisionAware()
        }
        .modelContainer(modelContainer)
    }
}
