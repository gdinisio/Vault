//
//  GlassStyle.swift
//  Vault
//
//  Reusable Liquid Glass surface treatments: translucent fill, hairline
//  white stroke and a soft specular highlight. Used by every card and pill.
//

import SwiftUI

// MARK: - Glass card surface

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = Theme.cardRadius
    var strokeOpacity: Double = 0.15

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        // top-left specular sheen
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.10), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .center
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Theme.line.opacity(strokeOpacity), lineWidth: 0.5)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Theme.cardShadow, radius: 24, x: 0, y: 18)
    }
}

// MARK: - Matte content card surface (flat — glass is reserved for chrome)

struct ContentCard: ViewModifier {
    var cornerRadius: CGFloat = Theme.contentRadius

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Theme.surfaceStroke, lineWidth: 0.5)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Theme.surfaceShadow, radius: 14, x: 0, y: 8)
    }
}

// MARK: - Thin glass pill (chips, segmented controls)

struct GlassPill: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Theme.line.opacity(0.12), lineWidth: 0.5)
                    }
            }
            .clipShape(Capsule(style: .continuous))
    }
}

extension View {
    /// Liquid Glass card surface with hairline stroke + specular highlight.
    func glassCard(cornerRadius: CGFloat = Theme.cardRadius, strokeOpacity: Double = 0.15) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity))
    }

    /// Thin glass pill surface.
    func glassPill() -> some View {
        modifier(GlassPill())
    }

    /// Flat, opaque content surface. The matte counterpart to `glassCard()` —
    /// use for content (rows, cards, charts) so glass stays on the chrome.
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
    /// The small uppercase tracking label used above values.
    func vaultLabel() -> some View {
        self
            .font(.system(size: 12, weight: .semibold))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Theme.inkDim)
    }
}
