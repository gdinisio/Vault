//
//  GlassStyle.swift
//  Vault
//
//  Reusable surface treatments built on system materials and semantic
//  colours — no painted gradients, sheens or shadows. Glass (material) is
//  reserved for chrome; content sits on flat system surfaces.
//

import SwiftUI

// MARK: - Glass card surface (chrome)

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = Theme.cardRadius
    var strokeOpacity: Double = 0.15

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Content container (flat, chrome-less)

/// Logical grouping for content (charts, allocation, grouped detail rows).
/// No fill and no outline — the Stocks-style flat aesthetic relies on section
/// titles, spacing, and internal hairline separators for structure, never a
/// container border (which would double-up with those separators). Fills are
/// reserved for selection/press. Kept as a modifier so chrome can be tuned in
/// one place; the rounded clip keeps any inner backgrounds tidy.
struct ContentCard: ViewModifier {
    var cornerRadius: CGFloat = Theme.contentRadius

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    /// Glass (material) card surface — for chrome.
    func glassCard(cornerRadius: CGFloat = Theme.cardRadius, strokeOpacity: Double = 0.15) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity))
    }

    /// Flat system content surface (inset-grouped cell colour).
    func contentCard(cornerRadius: CGFloat = Theme.contentRadius) -> some View {
        modifier(ContentCard(cornerRadius: cornerRadius))
    }

    /// Consistent page padding shared by every tab's content so horizontal and
    /// vertical insets line up exactly across the app.
    func vaultPagePadding() -> some View {
        modifier(VaultPagePadding())
    }
}

// MARK: - Consistent page padding

struct VaultPagePadding: ViewModifier {
    @Environment(\.horizontalSizeClass) private var hSize

    /// Horizontal page inset — wider on iPad (regular), tighter on iPhone.
    static func horizontal(_ size: UserInterfaceSizeClass?) -> CGFloat {
        size == .compact ? 20 : 40
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Self.horizontal(hSize))
            .padding(.top, 12)
            .padding(.bottom, 24)
    }
}

// MARK: - Uppercase label style

extension View {
    /// The small uppercase label used above values — system grouped-header style.
    func vaultLabel() -> some View {
        self
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }
}
