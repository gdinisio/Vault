//
//  AppSettings.swift
//  Vault
//
//  User-configurable, non-secret settings (currency display, starting paper
//  cash). Secrets live in KeychainService, never here.
//

import SwiftUI

@Observable
final class AppSettings {
    var displayCurrency: DisplayCurrency {
        didSet { defaults.set(displayCurrency.rawValue, forKey: Keys.currency) }
    }

    /// Starting virtual cash balance for paper trading.
    var startingPaperCash: Double {
        didSet { defaults.set(startingPaperCash, forKey: Keys.startingCash) }
    }

    /// Bumped when live FX rates change, to nudge money-displaying views to
    /// recompute. Not persisted.
    var fxToken: Int = 0

    private let defaults: UserDefaults

    private enum Keys {
        static let currency = "vault.displayCurrency"
        static let startingCash = "vault.startingPaperCash"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Keys.currency) ?? DisplayCurrency.gbp.rawValue
        self.displayCurrency = DisplayCurrency(rawValue: raw) ?? .gbp
        let cash = defaults.double(forKey: Keys.startingCash)
        self.startingPaperCash = cash > 0 ? cash : 10_000
    }
}
