//
//  VaultApp.swift
//  Vault
//
//  Created by Giovanni Di Nisio on 03/06/2026.
//

import SwiftUI
import SwiftData

@main
struct VaultApp: App {
    @State private var settings = AppSettings()

    /// Shared SwiftData container for all models.
    let container: ModelContainer = {
        let schema = Schema([Holding.self, PaperPosition.self, PaperTrade.self, WatchItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Fall back to in-memory so the app still launches if the store is corrupt.
            let fallback = ModelConfiguration(schema: Schema([Holding.self, PaperPosition.self, PaperTrade.self, WatchItem.self]), isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
        }
        .modelContainer(container)
    }
}
