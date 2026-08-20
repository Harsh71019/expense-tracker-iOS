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
    @State private var authModel = AuthModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(authModel)
        }
    }
}
