//
//  WidgetSnapshotWriter.swift
//  Vault
//
//  Builds a WidgetSnapshot from the current app state and writes it to the
//  shared App Group container, then tells WidgetKit to reload all timelines.
//
//  Called from ContentView whenever holdings, positions, watch items or FX
//  rates change — so widgets always reflect fresh data.
//

import SwiftUI
import WidgetKit

@MainActor
final class WidgetSnapshotWriter {
    static let shared = WidgetSnapshotWriter()
    private init() {}

    /// Rebuild and persist the snapshot, then reload all widget timelines.
    /// Fetches 1-month sparklines for every symbol concurrently; non-blocking
    /// from the caller's perspective (called inside a Task in ContentView).
    func rebuild(
        holdings: [Holding],
        positions: [PaperPosition],
        watch: [WatchItem],
        currency: DisplayCurrency
    ) async {
        // ── 1. Portfolio card ──────────────────────────────────────────────
        let portfolioVM = PortfolioViewModel()
        let ps = portfolioVM.summary(for: holdings)

        let portfolioSpark: [Double]
        if holdings.isEmpty {
            portfolioSpark = []
        } else {
            let series = await portfolioVM.performanceSeries(for: holdings, range: .month)
            portfolioSpark = series.map(\.close)
        }

        let portfolioCard = WidgetSnapshot.PortfolioCard(
            valueText:     Money.currency(ps.currentValue, currency: currency),
            plText:        Money.signed(ps.profitLoss, currency: currency),
            returnPctText: Money.percent(ps.returnPercent),
            signal:        ps.performanceSignal,
            spark:         portfolioSpark,
            holdingCount:  holdings.count
        )

        // ── 2. Paper trading card ──────────────────────────────────────────
        // PaperTradingViewModel reads cash from UserDefaults (saved on every change).
        let paperVM = PaperTradingViewModel()
        let pps = paperVM.summary(positions: positions)

        let paperCard = WidgetSnapshot.PaperCard(
            equityText:    Money.currency(pps.equity, currency: currency),
            plText:        Money.signed(pps.openProfitLoss, currency: currency),
            returnPctText: Money.percent(pps.openReturnPercent),
            signal:        pps.performanceSignal,
            // Equity curve: no real time-series stored for paper trading,
            // so the widget renders a deterministic cosmetic sparkline.
            spark:         [],
            positionCount: positions.count
        )

        // ── 3. Ticker cards (holdings + watch) ────────────────────────────
        // Fetch 1M history for all symbols concurrently (cached by the service).
        let allSymbols = holdings.map(\.ticker) + watch.map(\.ticker)
        let historySpark: [String: [Double]]
        if allSymbols.isEmpty {
            historySpark = [:]
        } else {
            historySpark = await withTaskGroup(of: (String, [Double]).self) { group in
                for symbol in allSymbols {
                    group.addTask {
                        let pts = (try? await PriceHistoryService.shared.history(for: symbol, range: .month)) ?? []
                        return (symbol, pts.map(\.close))
                    }
                }
                var map: [String: [Double]] = [:]
                for await (sym, pts) in group { map[sym] = pts }
                return map
            }
        }

        var tickerCards: [WidgetSnapshot.TickerCard] = []

        // Holdings — use stored currentPrice as the price; sparkline % for change.
        for h in holdings {
            let sp = historySpark[h.ticker] ?? []
            let pct = rangePercent(spark: sp) ?? h.returnPercent
            tickerCards.append(WidgetSnapshot.TickerCard(
                symbol:     h.ticker,
                name:       h.companyName,
                priceText:  Money.currency(h.currentPrice, currency: currency),
                changeText: "\(Money.percent(pct)) (1M)",
                up:         pct >= 0,
                spark:      sp,
                kind:       .holding
            ))
        }

        // Watch items — last close from history as the price (no stored price).
        for w in watch {
            let sp = historySpark[w.ticker] ?? []
            let lastPrice = sp.last ?? 0
            let pct = rangePercent(spark: sp) ?? 0
            tickerCards.append(WidgetSnapshot.TickerCard(
                symbol:     w.ticker,
                name:       w.companyName,
                priceText:  lastPrice > 0 ? Money.currency(lastPrice, currency: currency) : "—",
                changeText: lastPrice > 0 ? "\(Money.percent(pct)) (1M)" : "—",
                up:         pct >= 0,
                spark:      sp,
                kind:       .watch
            ))
        }

        // ── 4. Write + reload ──────────────────────────────────────────────
        let snapshot = WidgetSnapshot(
            generatedAt:  .now,
            currencyCode: currency.rawValue,
            portfolio:    portfolioCard,
            paper:        paperCard,
            tickers:      tickerCards
        )
        SnapshotStore.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Helpers

    /// Percentage change first→last in a price series.
    private func rangePercent(spark: [Double]) -> Double? {
        guard let first = spark.first, let last = spark.last, first > 0 else { return nil }
        return (last - first) / first * 100
    }
}
