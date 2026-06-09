//
//  PaperSummaryWidget.swift
//  VaultWidgets
//
//  Displays paper trading account equity, open P&L and an equity-curve
//  sparkline in Small / Medium / Large sizes. Tapping opens the Paper Trading tab.
//

import WidgetKit
import SwiftUI

struct PaperSummaryWidget: Widget {
    let kind = "PaperSummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            PaperSummaryView(entry: entry)
                .widgetURL(URL(string: "vault://paper"))
                .containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName("Paper Trading")
        .description("Your virtual paper trading account equity and P&L.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Views

private struct PaperSummaryView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    private var card: WidgetSnapshot.PaperCard { entry.snapshot.paper }

    // Equity curve uses a deterministic cosmetic sparkline (no real time-series).
    private var spark: [Double] {
        Spark.series(seed: 3.1, count: 30, trendingUp: card.signal >= 0)
    }

    var body: some View {
        switch family {
        case .systemSmall:  smallBody
        case .systemMedium: mediumBody
        default:            largeBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                WidgetHeaderMark(systemImage: "doc.text", tint: Theme.accent)
                Spacer()
                Text("Paper").font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.inkDim)
            }
            Spacer()
            ValueChangeRow(
                valueText: card.equityText,
                plText: card.plText,
                returnPctText: card.returnPctText,
                signal: card.signal,
                valueFontSize: 22
            )
        }
        .padding(14)
    }

    private var mediumBody: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    WidgetHeaderMark(systemImage: "doc.text", tint: Theme.accent)
                    Text("Paper Trading").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
                    Spacer()
                }
                ValueChangeRow(
                    valueText: card.equityText,
                    plText: card.plText,
                    returnPctText: card.returnPctText,
                    signal: card.signal,
                    valueFontSize: 26
                )
                Text("\(card.positionCount) open positions")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.inkDim)
            }
            WidgetSparkline(spark: spark, signal: card.signal)
                .frame(width: 110, height: 56)
        }
        .padding(16)
    }

    private var largeBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                WidgetHeaderMark(systemImage: "doc.text", tint: Theme.accent)
                Text("Paper Trading").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
                Spacer()
                Text("\(card.positionCount) positions")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.inkDim)
            }
            .padding(.bottom, 16)

            ValueChangeRow(
                valueText: card.equityText,
                plText: card.plText,
                returnPctText: card.returnPctText,
                signal: card.signal,
                valueFontSize: 38
            )

            Spacer()

            WidgetSparkline(spark: spark, signal: card.signal)
                .frame(maxWidth: .infinity)
                .frame(height: 100)

            Text("Equity curve · cosmetic")
                .font(.system(size: 10)).foregroundStyle(Theme.inkDim)
                .padding(.top, 6)
        }
        .padding(18)
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    PaperSummaryWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .placeholder, isPlaceholder: false)
}

#Preview("Medium", as: .systemMedium) {
    PaperSummaryWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .placeholder, isPlaceholder: false)
}

#Preview("Large", as: .systemLarge) {
    PaperSummaryWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .placeholder, isPlaceholder: false)
}
