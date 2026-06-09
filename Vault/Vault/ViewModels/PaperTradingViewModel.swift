//
//  PaperTradingViewModel.swift
//  Vault
//
//  Drives the Paper Trading tab: virtual cash, buy/sell execution against
//  SwiftData, equity/P&L aggregates, and concurrent price refresh.
//

import SwiftUI
import SwiftData

struct PaperSummary {
    var cash: Double = 0
    var positionsValue: Double = 0
    var equity: Double = 0
    var openProfitLoss: Double = 0
    var openReturnPercent: Double = 0
    var performanceSignal: Double = 0
}

@MainActor
@Observable
final class PaperTradingViewModel {
    /// Flat trading commission as a fraction of the order's gross value (1%).
    static let feeRate = 0.01

    var isRefreshing = false
    var toast: Toast?

    /// Virtual cash balance, persisted across launches.
    var cash: Double {
        didSet { defaults.set(cash, forKey: cashKey) }
    }

    private let finnhub: FinnhubService
    private let defaults: UserDefaults
    private let cashKey = "vault.paperCash"
    private let initialisedKey = "vault.paperCashInitialised"

    init(finnhub: FinnhubService = .shared,
         defaults: UserDefaults = .standard,
         startingCash: Double = 10_000) {
        self.finnhub = finnhub
        self.defaults = defaults
        if defaults.bool(forKey: initialisedKey) {
            self.cash = defaults.double(forKey: cashKey)
        } else {
            self.cash = startingCash
            defaults.set(startingCash, forKey: cashKey)
            defaults.set(true, forKey: initialisedKey)
        }
    }

    /// Reset the balance to a new starting amount (from Settings).
    func resetCash(to amount: Double) {
        cash = amount
    }

    // MARK: Aggregates

    func summary(positions: [PaperPosition]) -> PaperSummary {
        var s = PaperSummary()
        s.cash = cash
        s.positionsValue = positions.reduce(0) { $0 + $1.currentValue }
        s.equity = s.cash + s.positionsValue
        let basis = positions.reduce(0) { $0 + $1.costBasis }
        s.openProfitLoss = positions.reduce(0) { $0 + $1.profitLoss }
        s.openReturnPercent = basis > 0 ? s.openProfitLoss / basis * 100 : 0
        s.performanceSignal = max(-1, min(1, s.openReturnPercent / 25))
        return s
    }

    // MARK: Trading

    enum TradeResult { case ok, insufficientCash, insufficientShares }

    /// Execute a paper buy: deduct cash, open or average up a position, log trade.
    @discardableResult
    func buy(ticker: String, companyName: String, sector: String,
             shares: Double, price: Double,
             existing positions: [PaperPosition], in context: ModelContext) -> TradeResult {
        let cost = shares * price * (1 + Self.feeRate)
        guard cost <= cash else { return .insufficientCash }

        if let position = positions.first(where: { $0.ticker == ticker }) {
            let totalShares = position.shares + shares
            position.averageCost = (position.costBasis + cost) / totalShares
            position.shares = totalShares
            position.currentPrice = price
            position.lastUpdated = .now
        } else {
            let position = PaperPosition(ticker: ticker, companyName: companyName, sector: sector,
                                         shares: shares, averageCost: price, currentPrice: price)
            context.insert(position)
        }

        context.insert(PaperTrade(ticker: ticker, shares: shares, price: price, type: .buy))
        cash -= cost
        try? context.save()
        return .ok
    }

    /// Execute a paper sell: add proceeds, reduce/close position, log trade.
    @discardableResult
    func sell(position: PaperPosition, shares: Double, price: Double, in context: ModelContext) -> TradeResult {
        guard shares <= position.shares else { return .insufficientShares }
        let proceeds = shares * price

        context.insert(PaperTrade(ticker: position.ticker, shares: shares, price: price, type: .sell))
        cash += proceeds

        if shares == position.shares {
            context.delete(position)
        } else {
            position.shares -= shares
            position.currentPrice = price
            position.lastUpdated = .now
        }
        try? context.save()
        return .ok
    }

    // MARK: Live prices

    func refreshPrices(for positions: [PaperPosition]) async {
        guard !positions.isEmpty else { return }
        guard KeychainService.shared.has(.finnhub) else {
            toast = Toast(message: FinnhubError.missingAPIKey.localizedDescription, kind: .info)
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        let symbols = positions.map(\.ticker)
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
        for position in positions {
            if let price = results[position.ticker] {
                position.currentPrice = price
                position.lastUpdated = .now
                position.isStale = false
            } else {
                position.isStale = true
                failures += 1
            }
        }

        if failures == positions.count {
            toast = Toast(message: "Couldn't refresh prices. Showing last-known values.", kind: .error)
        }
    }
}
