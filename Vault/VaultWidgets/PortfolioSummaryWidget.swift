//
//  PortfolioSummaryWidget.swift
//  VaultWidgets
//
//  Displays total portfolio value, P&L and a sparkline in Small / Medium /
//  Large sizes. Tapping opens the Portfolio tab via deep link.
//

import WidgetKit
import SwiftUI

struct PortfolioSummaryWidget: Widget {
    let kind = "PortfolioSummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            PortfolioSummaryView(entry: entry)
                .widgetURL(URL(string: "vault://portfolio"))
                .containerBackground(for: .widget) {
                    Theme.bgDeep
                }
        }
        .configurationDisplayName("Portfolio")
        .description("Your live portfolio value and overall return.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Views

private struct PortfolioSummaryView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    private var card: WidgetSnapshot.PortfolioCard { entry.snapshot.portfolio }

    var body: some View {
        switch family {
        case .systemSmall:  smallBody
        case .systemMedium: mediumBody
        default:            largeBody
        }
    }

    // Small: icon + value + change
    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                WidgetHeaderMark(systemImage: "rectangle.split.3x1")
                Spacer()
                Text("\(card.holdingCount) stocks")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.inkDim)
            }
            Spacer()
            ValueChangeRow(
                valueText: card.valueText,
                plText: card.plText,
                returnPctText: card.returnPctText,
                signal: card.signal,
                valueFontSize: 22
            )
        }
        .padding(14)
    }

    // Medium: value + change left, sparkline right
    private var mediumBody: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    WidgetHeaderMark(systemImage: "rectangle.split.3x1")
                    Text("Portfolio").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
                    Spacer()
                }
                ValueChangeRow(
                    valueText: card.valueText,
                    plText: card.plText,
                    returnPctText: card.returnPctText,
                    signal: card.signal,
                    valueFontSize: 26
                )
                Text("\(card.holdingCount) positions · 1M")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.inkDim)
            }
            WidgetSparkline(spark: card.spark, signal: card.signal)
                .frame(width: 110, height: 56)
        }
        .padding(16)
    }

    // Large: header + large value + sparkline strip
    private var largeBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                WidgetHeaderMark(systemImage: "rectangle.split.3x1")
                Text("Portfolio").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
                Spacer()
                Text("\(card.holdingCount) positions")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.inkDim)
            }
            .padding(.bottom, 16)

            ValueChangeRow(
                valueText: card.valueText,
                plText: card.plText,
                returnPctText: card.returnPctText,
                signal: card.signal,
                valueFontSize: 38
            )

            Spacer()

            WidgetSparkline(spark: card.spark, signal: card.signal)
                .frame(maxWidth: .infinity)
                .frame(height: 100)

            Text("1-month performance")
                .font(.system(size: 10)).foregroundStyle(Theme.inkDim)
                .padding(.top, 6)
        }
        .padding(18)
    }
}
