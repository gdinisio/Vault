//
//  WidgetStyles.swift
//  VaultWidgets
//
//  Shared layout helpers and colour resolution used across all four widgets.
//  Keeps individual widget files focused on content rather than style.
//

import SwiftUI
import WidgetKit

// MARK: - Adaptive colours
// Widgets support the full SwiftUI colour system including dark/light adaptive
// colours, so we can reference Theme tokens directly.

extension Color {
    static var widgetGain: Color  { Theme.gain }
    static var widgetLoss: Color  { Theme.loss }
    static var widgetInk: Color   { Theme.ink }
    static var widgetDim: Color   { Theme.inkDim }
}

// MARK: - Signal → tint

func signalColor(_ signal: Double) -> Color {
    signal >= 0 ? Theme.gain : Theme.loss
}

// MARK: - Neutral widget background

/// Flat system background matching the app's matte content surfaces
/// (adapts to light/dark).
struct WidgetBackground: View {
    var body: some View {
        Color(.systemBackground)
    }
}

// MARK: - Change pill (mirrors the app's filled ChangePill)

struct WidgetChangePill: View {
    let text: String
    let up: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(Capsule(style: .continuous).fill(up ? Theme.gain : Theme.loss))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

// MARK: - Shared value+change row

struct ValueChangeRow: View {
    let valueText: String
    let plText: String
    let returnPctText: String
    let signal: Double
    var valueFontSize: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(valueText)
                .font(.system(size: valueFontSize, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            HStack(spacing: 7) {
                WidgetChangePill(text: returnPctText, up: signal >= 0)
                Text(plText)
                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(signalColor(signal))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }
}

// MARK: - Vault logo mark for widget headers

struct WidgetHeaderMark: View {
    let systemImage: String
    var tint: Color = Theme.accent

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 26, height: 26)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.18)))
    }
}

// MARK: - Small sparkline strip

struct WidgetSparkline: View {
    let spark: [Double]
    let signal: Double

    var body: some View {
        SparklineView(
            points: spark.isEmpty
                ? Spark.series(seed: 7.3, count: 22, trendingUp: signal >= 0)
                : spark,
            color: signalColor(signal)
        )
    }
}
