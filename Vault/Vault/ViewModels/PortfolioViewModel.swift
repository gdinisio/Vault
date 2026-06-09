//
//  PortfolioViewModel.swift
//  Vault
//
//  Drives the Portfolio tab: cost-basis aggregates, allocation slices, and
//  concurrent live-price refresh via Finnhub.
//

import SwiftUI
import SwiftData

/// Aggregate portfolio metrics for the summary header.
struct PortfolioSummary {
    var totalInvested: Double = 0      // cost basis incl. all charges
    var currentValue: Double = 0
    var profitLoss: Double = 0
    var returnPercent: Double = 0
    var annualisedReturn: Double = 0
    /// Normalised performance (-1...1) for the reactive background.
    var performanceSignal: Double = 0
}

/// One allocation slice for the donut chart. A slice represents a *position*
/// in a ticker — if the same ticker is held across multiple lots (bought at
/// different times) they are aggregated into a single slice and `lotCount`
/// reflects how many lots make up this position.
struct AllocationSlice: Identifiable {
    let id = UUID()
    let ticker: String
    let sector: String
    let value: Double
    let fraction: Double
    let lotCount: Int
}

@MainActor
@Observable
final class PortfolioViewModel {
    var isRefreshing = false
    var toast: Toast?

    private let finnhub: FinnhubService

    init(finnhub: FinnhubService = .shared) {
        self.finnhub = finnhub
    }

    // MARK: Aggregates

    func summary(for holdings: [Holding]) -> PortfolioSummary {
        var s = PortfolioSummary()
        guard !holdings.isEmpty else { return s }

        s.totalInvested = holdings.reduce(0) { $0 + $1.costBasis }
        s.currentValue = holdings.reduce(0) { $0 + $1.currentValue }
        s.profitLoss = s.currentValue - s.totalInvested
        s.returnPercent = s.totalInvested > 0 ? s.profitLoss / s.totalInvested * 100 : 0

        // Cost-weighted average purchase date → portfolio-level CAGR.
        let totalBasis = s.totalInvested
        if totalBasis > 0, s.currentValue > 0 {
            let weightedInterval = holdings.reduce(0.0) { acc, h in
                acc + Date.now.timeIntervalSince(h.purchaseDate) * (h.costBasis / totalBasis)
            }
            let years = max(weightedInterval / (365.25 * 24 * 3600), 1.0 / 365.0)
            let growth = s.currentValue / totalBasis
            s.annualisedReturn = (pow(growth, 1.0 / years) - 1) * 100
        }

        // Map return% onto a gentle -1...1 signal (±25% saturates).
        s.performanceSignal = max(-1, min(1, s.returnPercent / 25))
        return s
    }

    /// Aggregate slices for the donut. Multiple lots of the same ticker are
    /// merged into one slice — allocation is *what you own*, not *how many
    /// times you bought it*. The legend surfaces the lot count when > 1 so the
    /// underlying purchases stay discoverable.
    func allocations(for holdings: [Holding]) -> [AllocationSlice] {
        let total = holdings.reduce(0) { $0 + $1.currentValue }
        guard total > 0 else { return [] }

        // Preserve sector from the first encountered lot (lots of the same
        // ticker share sector in normal use). Group by ticker, sum value.
        let grouped = Dictionary(grouping: holdings, by: \.ticker)
        return grouped.map { ticker, lots -> AllocationSlice in
            let value = lots.reduce(0) { $0 + $1.currentValue }
            let sector = lots.first?.sector ?? "Other"
            return AllocationSlice(
                ticker: ticker,
                sector: sector,
                value: value,
                fraction: value / total,
                lotCount: lots.count
            )
        }
        .sorted { $0.value > $1.value }
    }

    // MARK: Performance history

    /// Build a portfolio value time-series for a range by summing each holding's
    /// (shares × historical price) across aligned dates (forward-filled). Values
    /// are in the USD base; the chart scales/labels handle display currency.
    func performanceSeries(for holdings: [Holding], range: ChartRange) async -> [PricePoint] {
        let lots = holdings.map { (symbol: $0.ticker, shares: $0.shares) }
        guard !lots.isEmpty else { return [] }

        // Fetch every holding's history concurrently (cached by the service).
        let histories = await withTaskGroup(of: (String, [PricePoint]).self) { group in
            for lot in lots {
                group.addTask {
                    let h = (try? await PriceHistoryService.shared.history(for: lot.symbol, range: range)) ?? []
                    return (lot.symbol, h)
                }
            }
            var map: [String: [PricePoint]] = [:]
            for await (symbol, points) in group { map[symbol] = points }
            return map
        }

        let usable = lots.filter { (histories[$0.symbol]?.count ?? 0) > 1 }
        guard !usable.isEmpty else { return [] }

        // Union of all dates, ascending.
        var dateSet = Set<Date>()
        for lot in usable { histories[lot.symbol]?.forEach { dateSet.insert($0.date) } }
        let dates = dateSet.sorted()

        var series: [PricePoint] = []
        for date in dates {
            var total = 0.0
            var complete = true
            for lot in usable {
                guard let arr = histories[lot.symbol],
                      let price = Self.priceAtOrBefore(arr, date) else { complete = false; break }
                total += lot.shares * price
            }
            if complete { series.append(PricePoint(date: date, close: total)) }
        }
        return series
    }

    /// Latest close at or before a date (forward-fill); `arr` is ascending.
    private static func priceAtOrBefore(_ arr: [PricePoint], _ date: Date) -> Double? {
        var result: Double?
        for point in arr {
            if point.date <= date { result = point.close } else { break }
        }
        return result
    }

    // MARK: Live prices

    /// Concurrently refresh every holding's price. Failures fall back to the
    /// last-known value and flag the holding as stale.
    func refreshPrices(for holdings: [Holding]) async {
        guard !holdings.isEmpty else { return }
        guard KeychainService.shared.has(.finnhub) else {
            toast = Toast(message: FinnhubError.missingAPIKey.localizedDescription, kind: .info)
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        let symbols = holdings.map(\.ticker)
        let results = await withTaskGroup(of: (String, Double?).self) { group in
            for symbol in symbols {
                group.addTask { [finnhub] in
                    let price = try? await finnhub.quote(for: symbol).c
                    return (symbol, price)
                }
            }
            var collected: [String: Double] = [:]
            for await (symbol, price) in group {
                if let price { collected[symbol] = price }
            }
            return collected
        }

        var failures = 0
        for holding in holdings {
            if let price = results[holding.ticker] {
                holding.currentPrice = price
                holding.lastUpdated = .now
                holding.isStale = false
            } else {
                holding.isStale = true
                failures += 1
            }
        }

        if failures == holdings.count {
            toast = Toast(message: "Couldn't refresh prices. Showing last-known values.", kind: .error)
        } else if failures > 0 {
            toast = Toast(message: "Updated \(holdings.count - failures) of \(holdings.count) prices.", kind: .info)
        }
    }

    // MARK: Mutations

    func delete(_ holding: Holding, in context: ModelContext) {
        context.delete(holding)
        try? context.save()
    }

    func add(_ holding: Holding, in context: ModelContext) {
        context.insert(holding)
        try? context.save()
    }
}
