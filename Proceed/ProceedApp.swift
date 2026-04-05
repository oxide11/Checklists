//
//  ProceedApp.swift
//  Proceed
//
//  Created by Moussa Noun on 2026-04-05.
//

import SwiftUI
import CoreData

@main
struct ProceedApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
