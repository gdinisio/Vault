//
//  WidgetSnapshot.swift
//  Vault / VaultWidgets (shared — add to both target memberships)
//
//  Codable value types that the app serialises into the App Group container
//  and the widget deserialises to render its views. All monetary display strings
//  are pre-formatted by the app so the widget needs no Money/FX logic.
//

import Foundation

struct WidgetSnapshot: Codable {
    var generatedAt: Date
    var currencyCode: String          // e.g. "GBP" or "USD"
    var portfolio: PortfolioCard
    var paper: PaperCard
    var tickers: [TickerCard]         // holdings first, then watch items

    // MARK: - Nested types

    struct PortfolioCard: Codable {
        var valueText: String         // e.g. "£12,480"
        var plText: String            // e.g. "+£1,230"
        var returnPctText: String     // e.g. "+12.4%"
        var signal: Double            // -1...1; positive = green tint
        var spark: [Double]           // raw close prices (widget normalises)
        var holdingCount: Int
    }

    struct PaperCard: Codable {
        var equityText: String
        var plText: String
        var returnPctText: String
        var signal: Double
        var spark: [Double]           // cosmetic — no real equity time series
        var positionCount: Int
    }

    struct TickerCard: Codable {
        enum Kind: String, Codable { case holding, watch }
        var symbol: String
        var name: String
        var priceText: String         // last known price
        var changeText: String        // e.g. "+2.4% (1M)"
        var up: Bool
        var spark: [Double]
        var kind: Kind
    }

    // MARK: - Placeholder (used in widget gallery + before first app launch)

    static let placeholder = WidgetSnapshot(
        generatedAt: .now,
        currencyCode: "GBP",
        portfolio: PortfolioCard(
            valueText: "£12,480", plText: "+£1,230", returnPctText: "+10.9%",
            signal: 0.4,
            spark: Spark.series(seed: 7.3, count: 30, trendingUp: true),
            holdingCount: 5
        ),
        paper: PaperCard(
            equityText: "£10,340", plText: "+£340", returnPctText: "+3.4%",
            signal: 0.2,
            spark: Spark.series(seed: 3.1, count: 30, trendingUp: true),
            positionCount: 3
        ),
        tickers: [
            TickerCard(symbol: "AAPL", name: "Apple Inc.",
                       priceText: "£172.40", changeText: "+8.2% (1M)", up: true,
                       spark: Spark.series(seed: 1.2, count: 22, trendingUp: true),
                       kind: .holding),
            TickerCard(symbol: "MSFT", name: "Microsoft",
                       priceText: "£334.10", changeText: "+4.1% (1M)", up: true,
                       spark: Spark.series(seed: 2.5, count: 22, trendingUp: true),
                       kind: .holding),
            TickerCard(symbol: "TSLA", name: "Tesla",
                       priceText: "£198.60", changeText: "-3.2% (1M)", up: false,
                       spark: Spark.series(seed: 4.7, count: 22, trendingUp: false),
                       kind: .watch),
            TickerCard(symbol: "NVDA", name: "NVIDIA",
                       priceText: "£820.50", changeText: "+15.1% (1M)", up: true,
                       spark: Spark.series(seed: 5.9, count: 22, trendingUp: true),
                       kind: .holding),
            TickerCard(symbol: "GOOGL", name: "Alphabet",
                       priceText: "£154.20", changeText: "+2.8% (1M)", up: true,
                       spark: Spark.series(seed: 3.3, count: 22, trendingUp: true),
                       kind: .watch),
        ]
    )
}
