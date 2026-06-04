//
//  VaultBackground.swift
//  Vault
//
//  Ambient base with drifting light orbs and a performance-reactive radial tint
//  that shifts green (gains) / red (losses) based on overall P&L. Adapts to the
//  system appearance: deep navy in dark, soft off-white in light.
//

import SwiftUI

struct VaultBackground: View {
    /// Overall portfolio performance, normalised to roughly -1...1.
    var performance: Double

    @Environment(\.colorScheme) private var scheme

    private var isDark: Bool { scheme == .dark }

    var body: some View {
        ZStack {
            // base gradient (adaptive tones)
            LinearGradient(
                colors: [Theme.bg1, Theme.bg0, Theme.bgDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // upper ambient washes — richer in dark, whisper-soft in light
            RadialGradient(
                colors: [isDark ? Color.oklch(0.30, 0.06, 268, alpha: 0.9)
                                : Color.oklch(0.80, 0.05, 255, alpha: 0.5), .clear],
                center: UnitPoint(x: 0.18, y: 0.08),
                startRadius: 0,
                endRadius: 720
            )
            RadialGradient(
                colors: [isDark ? Color.oklch(0.26, 0.05, 286, alpha: 0.8)
                                : Color.oklch(0.82, 0.04, 300, alpha: 0.45), .clear],
                center: UnitPoint(x: 0.88, y: 0.12),
                startRadius: 0,
                endRadius: 640
            )

            // performance-reactive tint blobs (bottom corners)
            RadialGradient(
                colors: [Theme.gain.opacity(max(0, performance) * (isDark ? 0.32 : 0.18)), .clear],
                center: UnitPoint(x: 0.78, y: 0.92),
                startRadius: 0,
                endRadius: 560
            )
            RadialGradient(
                colors: [Theme.loss.opacity(max(0, -performance) * (isDark ? 0.32 : 0.18)), .clear],
                center: UnitPoint(x: 0.12, y: 0.94),
                startRadius: 0,
                endRadius: 560
            )

            // drifting orbs
            DriftingOrbs(isDark: isDark)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.0), value: performance)
    }
}

/// Two slowly drifting blurred colour orbs for depth.
private struct DriftingOrbs: View {
    let isDark: Bool
    @State private var drift = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [isDark ? Color.oklch(0.55, 0.13, 262, alpha: 0.55)
                                            : Color.oklch(0.80, 0.08, 262, alpha: 0.35), .clear],
                            center: .center, startRadius: 0, endRadius: 260)
                    )
                    .frame(width: 520, height: 520)
                    .blur(radius: 60)
                    .position(x: drift ? 120 : 60, y: drift ? 60 : 0)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [isDark ? Color.oklch(0.50, 0.12, 300, alpha: 0.45)
                                            : Color.oklch(0.82, 0.07, 300, alpha: 0.30), .clear],
                            center: .center, startRadius: 0, endRadius: 230)
                    )
                    .frame(width: 460, height: 460)
                    .blur(radius: 60)
                    .position(x: geo.size.width - (drift ? 80 : 130),
                              y: geo.size.height - (drift ? 90 : 130))
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 28).repeatForever(autoreverses: true)) {
                    drift = true
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview("Gains") {
    VaultBackground(performance: 0.6)
}

#Preview("Losses") {
    VaultBackground(performance: -0.6)
}
