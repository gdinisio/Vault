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
