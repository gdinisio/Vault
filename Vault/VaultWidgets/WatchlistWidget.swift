//
//  WatchlistWidget.swift
//  VaultWidgets
//
//  Shows a compact list of tickers (holdings + watchlist) with price and
//  1-month % change in Medium (3 rows) and Large (6 rows) sizes.
//  Tapping opens the Watchlist tab.
//

import WidgetKit
import SwiftUI

struct WatchlistWidget: Widget {
    let kind = "WatchlistWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            WatchlistWidgetView(entry: entry)
                .widgetURL(URL(string: "vault://watchlist"))
                .containerBackground(for: .widget) { Theme.bgDeep }
        }
        .configurationDisplayName("Watchlist")
        .description("Your holdings and watched tickers at a glance.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - View

private struct WatchlistWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    private var maxRows: Int { family == .systemMedium ? 3 : 6 }
    private var tickers: [WidgetSnapshot.TickerCard] {
        Array(entry.snapshot.tickers.prefix(maxRows))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                WidgetHeaderMark(systemImage: "star.fill", tint: Theme.warn)
                Text("Watchlist").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
                Spacer()
                Text(entry.snapshot.currencyCode)
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.inkDim)
            }
            .padding(.bottom, 8)

            if tickers.isEmpty {
                Spacer()
                Text("Add holdings or watchlist items in Vault")
                    .font(.system(size: 12)).foregroundStyle(Theme.inkDim)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                VStack(spacing: 0) {
                    ForEach(tickers, id: \.symbol) { card in
                        TickerRow(card: card)
                        if card.symbol != tickers.last?.symbol {
                            Divider().overlay(Theme.line.opacity(0.08))
                        }
                    }
                }
            }
        }
        .padding(14)
    }
}

private struct TickerRow: View {
    let card: WidgetSnapshot.TickerCard

    private var tint: Color { card.up ? Theme.gain : Theme.loss }
    private var spark: [Double] {
        card.spark.isEmpty
            ? Spark.series(seed: Double(abs(card.symbol.hashValue % 997)), count: 18, trendingUp: card.up)
            : card.spark
    }

    var body: some View {
        HStack(spacing: 8) {
            // Symbol + kind badge
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(card.symbol)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                    if card.kind == .watch {
                        Image(systemName: "star.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(Theme.warn.opacity(0.8))
                    }
                }
                Text(card.name)
                    .font(.system(size: 9)).foregroundStyle(Theme.inkDim)
                    .lineLimit(1)
            }
            .frame(width: 70, alignment: .leading)

            // Sparkline
            SparklineView(points: spark, color: tint)
                .frame(maxWidth: .infinity, maxHeight: 24)

            // Price + change
            VStack(alignment: .trailing, spacing: 1) {
                Text(card.priceText)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(card.changeText)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(tint)
            }
            .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 6)
    }
}
