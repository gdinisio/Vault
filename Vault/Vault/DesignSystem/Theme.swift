//
//  Theme.swift
//  Vault
//
//  Central design tokens, mapped 1:1 onto Apple's semantic colours so the app
//  inherits the exact system palette (and its Increased-Contrast / Dark-Mode
//  variants) everywhere. Token names are kept so views read semantically
//  ("ink", "gain") while resolving to UIKit dynamic colours underneath.
//

import SwiftUI
import UIKit

enum Theme {

    // MARK: Semantic colours

    /// Gains — the system green Apple uses in Stocks.
    static let gain = Color(.systemGreen)
    /// Losses — the system red Apple uses in Stocks.
    static let loss = Color(.systemRed)
    /// Accent for interactive highlights.
    static let accent = Color(.systemBlue)
    /// AI features.
    static let aiPurple = Color(.systemPurple)
    /// Warnings / stale data.
    static let warn = Color(.systemOrange)

    // MARK: Solid button fills (text on them is white, like system filled buttons)

    static let gainButton = Color(.systemGreen)
    static let lossButton = Color(.systemRed)
    static let accentButton = Color(.systemBlue)
    static let aiPurpleButton = Color(.systemPurple)
    /// Ink that sits on a vivid button fill.
    static let onButton = Color.white

    // MARK: Ink (text) — the system label hierarchy

    static let ink = Color(.label)
    static let inkSoft = Color(.secondaryLabel)
    static let inkDim = Color(.secondaryLabel)
    static let inkFaint = Color(.tertiaryLabel)

    // MARK: Backgrounds — flat system canvas

    /// Flat page/preview background.
    static let bgDeep = Color(.systemBackground)

    /// Hairline base for borders and subtle fills; always used with opacity.
    static let line = Color(.label)

    // MARK: Content surfaces

    /// Elevated fill for content cards/rows (inset-grouped cell colour).
    static let surface = Color(.secondarySystemBackground)
    /// Selected row fill.
    static let surfaceSelected = Color(.systemFill)
    /// Hairline border for content surfaces.
    static let surfaceStroke = Color(.separator)

    // MARK: Sector accents — the system palette

    static func sectorColor(_ sector: String) -> Color {
        switch sector {
        case "Technology": Color(.systemBlue)
        case "Index Fund": Color(.systemTeal)
        case "Consumer":   Color(.systemPink)
        case "Healthcare": Color(.systemMint)
        case "Energy":     Color(.systemOrange)
        case "Financials": Color(.systemIndigo)
        default:           Color(.systemBlue)
        }
    }

    // MARK: Corner radii

    static let cardRadius: CGFloat = 20
    static let contentRadius: CGFloat = 20
    static let sheetRadius: CGFloat = 28

    // MARK: Helpers

    /// Returns gain/loss colour for a signed value.
    static func tone(_ value: Double) -> Color {
        value >= 0 ? gain : loss
    }
}
