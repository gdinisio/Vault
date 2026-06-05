//
//  AppGroup.swift
//  Vault / VaultWidgets (shared — add to both target memberships)
//
//  Defines the App Group identifier and resolves the shared container URL
//  used by both the app and the widget extension to exchange snapshot data.
//

import Foundation

enum AppGroup {
    static let id = "group.com.gdinisio.Vault"

    /// The shared App Group container URL.
    /// Returns nil if the entitlement is missing — e.g. free developer account on
    /// device; everything works in the Simulator without a paid account.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }

    /// URL of the widget snapshot JSON file inside the shared container.
    static var snapshotURL: URL? {
        containerURL?.appendingPathComponent("vault_widget_snapshot.json")
    }
}
