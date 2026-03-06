//
//  PunchCounterApp.swift
//  PunchCounter
//
//  Created by Tuomas Tolvanen on 6.3.2026.
//

import SwiftUI
import CoreData

@main
struct PunchCounterApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
