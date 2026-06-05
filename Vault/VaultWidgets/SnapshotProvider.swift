//
//  SnapshotProvider.swift
//  VaultWidgets
//
//  Shared TimelineProvider for all Vault widgets. Reads the snapshot written
//  by the app; falls back to WidgetSnapshot.placeholder when nothing has been
//  persisted yet (first launch / App Group not configured).
//
//  Refresh policy: the app triggers `WidgetCenter.reloadAllTimelines()` on
//  every data/FX change. The `.after(15min)` policy is just a safety net in
//  case the app hasn't run recently.
//

import WidgetKit
import SwiftUI

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let isPlaceholder: Bool
}

struct SnapshotProvider: TimelineProvider {

    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let snap = SnapshotStore.read() ?? .placeholder
        completion(SnapshotEntry(date: .now, snapshot: snap, isPlaceholder: false))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let snap = SnapshotStore.read() ?? .placeholder
        let entry = SnapshotEntry(date: .now, snapshot: snap, isPlaceholder: false)
        // Refresh at most every 15 min as a fallback; app reloads are the primary trigger.
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}
