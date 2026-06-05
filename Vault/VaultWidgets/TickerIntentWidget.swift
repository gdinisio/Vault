//
//  TickerIntentWidget.swift
//  VaultWidgets
//
//  Single configurable ticker widget — user picks a symbol from their holdings
//  or watchlist via an AppIntent. Shows price + sparkline + % change.
//  Tapping opens the Portfolio tab.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - AppEntity

struct TickerEntity: AppEntity {
    let id: String       // ticker symbol
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Ticker"
    static var defaultQuery = TickerEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id) · \(name)")
    }
}

// MARK: - EntityQuery

struct TickerEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TickerEntity] {
        let snap = SnapshotStore.read() ?? .placeholder
        return snap.tickers
            .filter { identifiers.contains($0.symbol) }
            .map { TickerEntity(id: $0.symbol, name: $0.name) }
    }

    func suggestedEntities() async throws -> [TickerEntity] {
        let snap = SnapshotStore.read() ?? .placeholder
        return snap.tickers.map { TickerEntity(id: $0.symbol, name: $0.name) }
    }

    func defaultResult() async -> TickerEntity? {
        try? await suggestedEntities().first
    }
}

// MARK: - Intent

struct TickerSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Ticker"
    static var description = IntentDescription("Choose a holding or watchlist stock to display.")

    @Parameter(title: "Ticker")
    var ticker: TickerEntity?
}

// MARK: - Provider

struct TickerIntentProvider: AppIntentTimelineProvider {
    typealias Entry = TickerEntry
    typealias Intent = TickerSelectionIntent

    func placeholder(in context: Context) -> TickerEntry {
        TickerEntry(date: .now, card: .placeholder)
    }

    func snapshot(for intent: TickerSelectionIntent, in context: Context) async -> TickerEntry {
        TickerEntry(date: .now, card: resolveCard(intent: intent))
    }

    func timeline(for intent: TickerSelectionIntent, in context: Context) async -> Timeline<TickerEntry> {
        let entry = TickerEntry(date: .now, card: resolveCard(intent: intent))
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func resolveCard(intent: TickerSelectionIntent) -> WidgetSnapshot.TickerCard {
        let snap = SnapshotStore.read() ?? .placeholder
        if let symbol = intent.ticker?.id,
           let card = snap.tickers.first(where: { $0.symbol == symbol }) {
            return card
        }
        return snap.tickers.first ?? .placeholder
    }
}

// MARK: - Entry

struct TickerEntry: TimelineEntry {
    let date: Date
    let card: WidgetSnapshot.TickerCard
}

extension WidgetSnapshot.TickerCard {
    static let placeholder = WidgetSnapshot.TickerCard(
        symbol: "AAPL", name: "Apple Inc.",
        priceText: "£172.40", changeText: "+8.2% (1M)", up: true,
        spark: Spark.series(seed: 1.2, count: 22, trendingUp: true),
        kind: .holding
    )
}

// MARK: - Widget

struct SingleTickerWidget: Widget {
    let kind = "SingleTickerWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TickerSelectionIntent.self, provider: TickerIntentProvider()) { entry in
            TickerWidgetView(entry: entry)
                .widgetURL(URL(string: "vault://portfolio"))
                .containerBackground(for: .widget) { Theme.bgDeep }
        }
        .configurationDisplayName("Single Ticker")
        .description("Track a holding or watchlist stock at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - View

private struct TickerWidgetView: View {
    let entry: TickerEntry
    @Environment(\.widgetFamily) private var family

    private var card: WidgetSnapshot.TickerCard { entry.card }
    private var tint: Color { card.up ? Theme.gain : Theme.loss }
    private var spark: [Double] {
        card.spark.isEmpty
            ? Spark.series(seed: Double(abs(card.symbol.hashValue % 997)), count: 22, trendingUp: card.up)
            : card.spark
    }

    var body: some View {
        switch family {
        case .systemSmall:  smallBody
        default:            mediumBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(card.symbol)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: card.up ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
            }
            Text(card.name)
                .font(.system(size: 10)).foregroundStyle(Theme.inkDim).lineLimit(1)

            Spacer()

            SparklineView(points: spark, color: tint)
                .frame(maxWidth: .infinity, maxHeight: 36)

            Spacer(minLength: 6)

            Text(card.priceText)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(card.changeText)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint)
        }
        .padding(14)
    }

    private var mediumBody: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(card.symbol)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                Text(card.name)
                    .font(.system(size: 12)).foregroundStyle(Theme.inkDim).lineLimit(1)
                Spacer()
                Text(card.priceText)
                    .font(.system(size: 26, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(card.changeText)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(tint)
            }
            SparklineView(points: spark, color: tint)
                .frame(width: 120, height: 60)
        }
        .padding(16)
    }
}
