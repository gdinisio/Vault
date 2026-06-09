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
    let container: ModelContainer = Self.makeContainer()

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([Holding.self, PaperPosition.self, PaperTrade.self, WatchItem.self, WatchlistGroup.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        // 1) Normal path: open (and lightweight-migrate) the on-disk store.
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("⚠️ SwiftData: persistent store failed to open — \(error). Attempting recovery…")
        }

        // 2) Recovery: the on-disk store is incompatible (a schema change that
        //    can't be auto-migrated). Remove it and recreate a *persistent*
        //    store so data still survives app restarts going forward.
        let fm = FileManager.default
        if let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                        appropriateFor: nil, create: false) {
            for name in ["default.store", "default.store-wal", "default.store-shm"] {
                try? fm.removeItem(at: appSupport.appendingPathComponent(name))
            }
        }
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("⚠️ SwiftData: recovery failed — \(error). Falling back to in-memory (data will not persist).")
        }

        // 3) Last resort: in-memory, so the app still launches.
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        return try! ModelContainer(for: schema, configurations: [memory])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
        }
        .modelContainer(container)
    }
}
