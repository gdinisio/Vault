//
//  SnapshotStore.swift
//  Vault / VaultWidgets (shared — add to both target memberships)
//
//  Atomic read/write of the WidgetSnapshot JSON in the App Group container.
//  Thread-safe: JSONDecoder/Encoder are created once; file I/O is synchronous
//  (tiny payload, only called on background task or main actor).
//

import Foundation

enum SnapshotStore {
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()

    /// Read the last snapshot written by the app. Returns nil if no snapshot
    /// exists yet (e.g. first launch, or App Group not configured).
    static func read() -> WidgetSnapshot? {
        guard let url = AppGroup.snapshotURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    /// Persist a snapshot to the App Group container.
    static func write(_ snapshot: WidgetSnapshot) {
        guard let url = AppGroup.snapshotURL,
              let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
