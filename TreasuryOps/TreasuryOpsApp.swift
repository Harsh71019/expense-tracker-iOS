//
//  TreasuryOpsApp.swift
//  TreasuryOps
//
//  Created by Harsh on 20/08/26.
//

import SwiftUI
import CoreData

@main
struct TreasuryOpsApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
