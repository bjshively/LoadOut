//
//  LoadOutApp.swift
//  LoadOut
//
//  Created by Brad Shively on 1/13/26.
//

import SwiftUI
import CoreData

@main
struct LoadOutApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
