//
//  MockData.swift
//  Vault
//
//  Sample data for SwiftUI previews and first-run seeding. Mirrors the
//  realistic GBP portfolio from the design mock.
//

import Foundation
import SwiftData

enum MockData {

    static let holdings: [Holding] = [
        Holding(ticker: "VOO", companyName: "Vanguard S&P 500 ETF", sector: "Index Fund",
                shares: 30, purchasePricePerShare: 452.10,
                purchaseDate: date("2023-04-18"), fxCharge: 64.20, brokerFee: 3.00,
                currentPrice: 498.75),
        Holding(ticker: "AAPL", companyName: "Apple Inc.", sector: "Technology",
                shares: 40, purchasePricePerShare: 172.30,
                purchaseDate: date("2022-11-02"), fxCharge: 41.30, brokerFee: 2.50,
                currentPrice: 214.20),
        Holding(ticker: "MSFT", companyName: "Microsoft Corp.", sector: "Technology",
                shares: 18, purchasePricePerShare: 388.00,
                purchaseDate: date("2024-01-15"), fxCharge: 38.80, brokerFee: 2.50,
                currentPrice: 441.20),
        Holding(ticker: "AMZN", companyName: "Amazon.com Inc.", sector: "Consumer",
                shares: 22, purchasePricePerShare: 168.20,
                purchaseDate: date("2023-09-07"), fxCharge: 27.10, brokerFee: 2.50,
                currentPrice: 201.40),
        Holding(ticker: "NVDA", companyName: "NVIDIA Corp.", sector: "Technology",
                shares: 25, purchasePricePerShare: 98.40,
                purchaseDate: date("2024-03-22"), fxCharge: 18.40, brokerFee: 2.50,
                currentPrice: 131.60),
        Holding(ticker: "TSLA", companyName: "Tesla Inc.", sector: "Consumer",
                shares: 15, purchasePricePerShare: 242.50,
                purchaseDate: date("2024-06-11"), fxCharge: 27.20, brokerFee: 2.50,
                currentPrice: 214.80)
    ]

    static let positions: [PaperPosition] = [
        PaperPosition(ticker: "PLTR", companyName: "Palantir Technologies", sector: "Technology",
                      shares: 120, averageCost: 24.10, currentPrice: 31.85),
        PaperPosition(ticker: "AMD", companyName: "Advanced Micro Devices", sector: "Technology",
                      shares: 40, averageCost: 158.20, currentPrice: 149.70),
        PaperPosition(ticker: "COST", companyName: "Costco Wholesale", sector: "Consumer",
                      shares: 8, averageCost: 712.40, currentPrice: 794.10)
    ]

    static let trades: [PaperTrade] = [
        PaperTrade(ticker: "PLTR", shares: 120, price: 24.10, type: .buy, timestamp: dateTime("2026-05-29 14:22")),
        PaperTrade(ticker: "NVDA", shares: 20, price: 128.40, type: .sell, timestamp: dateTime("2026-05-27 10:08")),
        PaperTrade(ticker: "COST", shares: 8, price: 712.40, type: .buy, timestamp: dateTime("2026-05-21 15:47")),
        PaperTrade(ticker: "AMD", shares: 40, price: 158.20, type: .buy, timestamp: dateTime("2026-05-18 09:31")),
        PaperTrade(ticker: "SOFI", shares: 200, price: 9.85, type: .sell, timestamp: dateTime("2026-05-12 13:55"))
    ]

    static let watchlist: [WatchItem] = [
        WatchItem(ticker: "GOOGL", companyName: "Alphabet Inc.", sector: "Technology"),
        WatchItem(ticker: "LLY", companyName: "Eli Lilly & Co.", sector: "Healthcare"),
        WatchItem(ticker: "JPM", companyName: "JPMorgan Chase", sector: "Financials")
    ]

    /// An in-memory SwiftData container seeded with mock data, for previews.
    @MainActor
    static func previewContainer() -> ModelContainer {
        let schema = Schema([Holding.self, PaperPosition.self, PaperTrade.self, WatchItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        holdings.forEach { context.insert($0) }
        positions.forEach { context.insert($0) }
        trades.forEach { context.insert($0) }
        watchlist.forEach { context.insert($0) }
        return container
    }

    // MARK: Date helpers

    private static func date(_ string: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: string) ?? .now
    }

    private static func dateTime(_ string: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: string) ?? .now
    }
}
