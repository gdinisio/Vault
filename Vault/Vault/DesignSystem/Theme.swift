//
//  Theme.swift
//  Vault
//
//  Central design tokens for the Liquid Glass visual language. Colours are
//  defined as adaptive light/dark pairs and resolve automatically to the
//  system appearance (the iPad's Light/Dark setting). Derived from the
//  original OKLCH design system.
//

import SwiftUI
import UIKit

enum Theme {

    // MARK: Semantic colours (adaptive)

    /// Soft emerald for gains — slightly deeper in light mode for contrast.
    static let gain = dyn(dark: Color(red: 0.2, green: 0.8, blue: 0.5),
                          light: .oklch(0.56, 0.15, 158))
    /// Soft coral for losses.
    static let loss = dyn(dark: Color(red: 0.9, green: 0.35, blue: 0.3),
                          light: .oklch(0.54, 0.20, 25))
    /// Periwinkle accent.
    static let accent = dyn(dark: .oklch(0.74, 0.11, 255), light: .oklch(0.52, 0.16, 255))
    /// Claude / AI lavender.
    static let aiPurple = dyn(dark: .oklch(0.84, 0.10, 285), light: .oklch(0.52, 0.17, 285))
    /// Amber used for "warn" tone.
    static let warn = dyn(dark: .oklch(0.82, 0.13, 75), light: .oklch(0.52, 0.13, 75))

    // MARK: Solid button fills (stay vivid in light AND dark; text on them is dark)

    static let gainButton = Color(red: 0.2, green: 0.8, blue: 0.5)
    static let lossButton = Color(red: 0.9, green: 0.35, blue: 0.3)
    static let accentButton = Color.oklch(0.74, 0.12, 255)
    static let aiPurpleButton = Color.oklch(0.78, 0.13, 285)
    /// Near-black ink that sits on a vivid button fill.
    static let onButton = Color(red: 0.04, green: 0.06, blue: 0.05)

    // MARK: Ink (text)

    static let ink = dyn(dark: .oklch(0.97, 0.005, 264), light: .oklch(0.22, 0.02, 264))
    static let inkSoft = dyn(dark: .oklch(0.80, 0.012, 264), light: .oklch(0.38, 0.02, 264))
    static let inkDim = dyn(dark: .oklch(0.66, 0.014, 264), light: .oklch(0.50, 0.02, 264))
    static let inkFaint = dyn(dark: .oklch(0.52, 0.016, 264), light: .oklch(0.64, 0.015, 264))

    // MARK: Base background tones

    static let bg0 = dyn(dark: .oklch(0.16, 0.028, 264), light: .oklch(0.95, 0.012, 264))
    static let bg1 = dyn(dark: .oklch(0.20, 0.030, 264), light: .oklch(0.985, 0.006, 264))
    static let bgDeep = dyn(dark: Color(red: 0.027, green: 0.031, blue: 0.047),
                            light: .oklch(0.93, 0.012, 264))

    /// Adaptive "hairline" base used for glass borders and subtle fills:
    /// white in dark mode, dark navy in light mode. Always used with opacity.
    static let line = dyn(dark: .white, light: .oklch(0.28, 0.03, 264))

    /// Soft drop shadow under glass cards — deep in dark, gentle in light.
    static let cardShadow = dyn(dark: Color.black.opacity(0.45), light: Color.black.opacity(0.10))

    // MARK: Sector accent hues (OKLCH hue angle → Color)

    static func sectorColor(_ sector: String) -> Color {
        dyn(dark: .oklch(0.72, 0.13, sectorHue(sector)),
            light: .oklch(0.60, 0.15, sectorHue(sector)))
    }

    static func sectorHue(_ sector: String) -> Double {
        switch sector {
        case "Technology": return 255
        case "Index Fund": return 200
        case "Consumer":   return 312
        case "Healthcare": return 158
        case "Energy":     return 60
        case "Financials": return 255
        default:           return 255
        }
    }

    // MARK: Corner radii

    static let cardRadius: CGFloat = 20
    static let sheetRadius: CGFloat = 28

    // MARK: Helpers

    /// Returns gain/loss colour for a signed value.
    static func tone(_ value: Double) -> Color {
        value >= 0 ? gain : loss
    }

    /// Build an adaptive colour that resolves to `dark` or `light` based on the
    /// current user interface style (system Light/Dark setting).
    static func dyn(dark: Color, light: Color) -> Color {
        Color(UIColor { trait in
            UIColor(trait.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

// MARK: - OKLCH → sRGB conversion

extension Color {
    /// Build a SwiftUI Color from OKLCH components.
    static func oklch(_ l: Double, _ c: Double, _ h: Double, alpha: Double = 1) -> Color {
        let hr = h * .pi / 180
        let a = c * cos(hr)
        let b = c * sin(hr)

        // OKLab → LMS (cone responses)
        let l_ = l + 0.3963377774 * a + 0.2158037573 * b
        let m_ = l - 0.1055613458 * a - 0.0638541728 * b
        let s_ = l - 0.0894841775 * a - 1.2914855480 * b

        let lCubed = l_ * l_ * l_
        let mCubed = m_ * m_ * m_
        let sCubed = s_ * s_ * s_

        // LMS → linear sRGB
        let rLin =  4.0767416621 * lCubed - 3.3077115913 * mCubed + 0.2309699292 * sCubed
        let gLin = -1.2684380046 * lCubed + 2.6097574011 * mCubed - 0.3413193965 * sCubed
        let bLin = -0.0041960863 * lCubed - 0.7034186147 * mCubed + 1.7076147010 * sCubed

        func gamma(_ x: Double) -> Double {
            let clamped = max(0, x)
            let v = clamped <= 0.0031308
                ? 12.92 * clamped
                : 1.055 * pow(clamped, 1 / 2.4) - 0.055
            return min(1, max(0, v))
        }

        return Color(.sRGB,
                     red: gamma(rLin),
                     green: gamma(gLin),
                     blue: gamma(bLin),
                     opacity: alpha)
    }
}
