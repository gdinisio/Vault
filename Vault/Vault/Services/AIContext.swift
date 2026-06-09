//
//  AIContext.swift
//  Vault
//
//  Compiles a rich analysis context — portfolio figures + per-holding recent
//  news + analyst data — into the system prompt for the AI providers
//  (Gemini/Groq). The model is fed the data, so it doesn't need its own web
//  access.
//

import Foundation

/// Immutable snapshot of a holding (built on the main actor before async work).
struct HoldingDigest: Sendable {
    let ticker: String
    let name: String
    let sector: String
    let shares: Double
    let purchasePrice: Double
    let currentPrice: Double
    let purchaseDate: Date
    let costBasis: Double
    let currentValue: Double
    let returnPercent: Double
    let annualisedReturn: Double
    let fxCharge: Double
    let brokerFee: Double

    @MainActor
    init(_ h: Holding) {
        ticker = h.ticker
        name = h.companyName
        sector = h.sector
        shares = h.shares
        purchasePrice = h.purchasePricePerShare
        currentPrice = h.currentPrice
        purchaseDate = h.purchaseDate
        costBasis = h.costBasis
        currentValue = h.currentValue
        returnPercent = h.returnPercent
        annualisedReturn = h.annualisedReturn
        fxCharge = h.fxCharge
        brokerFee = h.brokerFee
    }

    @MainActor
    init(_ p: PaperPosition) {
        ticker = p.ticker
        name = p.companyName
        sector = p.sector
        shares = p.shares
        purchasePrice = p.averageCost
        currentPrice = p.currentPrice
        purchaseDate = p.lastUpdated
        costBasis = p.costBasis
        currentValue = p.currentValue
        returnPercent = p.returnPercent
        annualisedReturn = 0
        fxCharge = 0
        brokerFee = 0
    }
}

/// Recent price performance over standard windows (percent changes).
struct PerfSummary: Sendable {
    var day: Double?
    var week: Double?
    var month: Double?
    var quarter: Double?
    var year: Double?
}

enum AIContext {

    /// Fetch recent headlines per ticker (best-effort; needs a Finnhub key).
    static func fetchNews(for tickers: [String], perTicker: Int = 5) async -> [String: [CompanyNews]] {
        guard KeychainService.shared.has(.finnhub), !tickers.isEmpty else { return [:] }
        return await withTaskGroup(of: (String, [CompanyNews]).self) { group in
            for ticker in tickers {
                group.addTask {
                    let news = (try? await FinnhubService.shared.companyNews(for: ticker, days: 14)) ?? []
                    return (ticker, Array(news.prefix(perTicker)))
                }
            }
            var map: [String: [CompanyNews]] = [:]
            for await (ticker, news) in group { map[ticker] = news }
            return map
        }
    }

    /// Fetch 1-year daily history per ticker and derive 1D/1W/1M/3M/1Y moves
    /// (uses Yahoo — no API key required).
    static func performance(for tickers: [String]) async -> [String: PerfSummary] {
        guard !tickers.isEmpty else { return [:] }
        return await withTaskGroup(of: (String, PerfSummary?).self) { group in
            for ticker in tickers {
                group.addTask {
                    guard let history = try? await PriceHistoryService.shared.history(for: ticker, range: .year),
                          history.count > 1 else { return (ticker, nil) }
                    return await (ticker, perfSummary(from: history))
                }
            }
            var map: [String: PerfSummary] = [:]
            for await (ticker, perf) in group { if let perf { map[ticker] = perf } }
            return map
        }
    }

    private static func perfSummary(from history: [PricePoint]) -> PerfSummary {
        let sorted = history.sorted { $0.date < $1.date }
        guard let last = sorted.last else { return PerfSummary() }

        func changeSince(days: Int) -> Double? {
            let target = Calendar.current.date(byAdding: .day, value: -days, to: last.date) ?? last.date
            let prior = sorted.last { $0.date <= target } ?? sorted.first
            guard let prior, prior.close != 0, prior.date < last.date else { return nil }
            return (last.close - prior.close) / prior.close * 100
        }

        var p = PerfSummary()
        if sorted.count >= 2 {
            let prev = sorted[sorted.count - 2]
            if prev.close != 0 { p.day = (last.close - prev.close) / prev.close * 100 }
        }
        p.week = changeSince(days: 7)
        p.month = changeSince(days: 30)
        p.quarter = changeSince(days: 90)
        p.year = changeSince(days: 365)
        return p
    }

    /// "1D +0.4%, 1W -2.1%, 1M +5.0%, 3M +12.3%, 1Y +31.8%"
    static func perfLine(_ p: PerfSummary) -> String {
        let parts: [String?] = [
            p.day.map { "1D \(Money.percent($0))" },
            p.week.map { "1W \(Money.percent($0))" },
            p.month.map { "1M \(Money.percent($0))" },
            p.quarter.map { "3M \(Money.percent($0))" },
            p.year.map { "1Y \(Money.percent($0))" }
        ]
        let joined = parts.compactMap { $0 }.joined(separator: ", ")
        return joined.isEmpty ? "no recent history" : joined
    }

    // MARK: Portfolio prompts

    /// System prompt: analysis instructions + the compiled portfolio data,
    /// price performance & news.
    static func portfolioSystemPrompt(digests: [HoldingDigest], summary: PortfolioSummary,
                                      currency: DisplayCurrency,
                                      news: [String: [CompanyNews]],
                                      perf: [String: PerfSummary]) -> String {
        var s = instructionBlock()
        s += "\n\n" + portfolioData(digests: digests, summary: summary, currency: currency, news: news, perf: perf)
        return s
    }

    private static func instructionBlock() -> String {
        """
        You are a sharp, concise portfolio analyst inside an iPad investing app called Vault. The user's full PORTFOLIO DATA, recent PRICE PERFORMANCE (1D/1W/1M/3M/1Y), and recent NEWS are provided below — treat them as the complete, authoritative context for the whole conversation.

        Ground EVERY answer strictly in this data: quote the actual numbers (position values, P&L, sector weights, the specific 1D/1W/1M/3M/1Y moves) and cite specific headlines by name. Never invent figures or events; if the data doesn't cover something, say so rather than guessing. You are not a fortune teller — don't predict prices or give guaranteed buy/sell signals; give balanced, reasoned considerations.

        Answer the user's actual question directly and specifically. For a general review ("what do you think about my portfolio?"), cover in order: overall health and recent performance (reference the actual moves and headlines); concentration / diversification risk (cite the sector weights and largest position); the single biggest risk right now (cite a specific recent headline if available); and one concrete, actionable suggestion.

        Reply in clear plain prose — no markdown headers, no bulleted dumps. Keep it tight, specific and figure-driven. End every reply with exactly one line: "Not financial advice."
        """
    }

    private static func portfolioData(digests: [HoldingDigest], summary: PortfolioSummary,
                                      currency: DisplayCurrency,
                                      news: [String: [CompanyNews]],
                                      perf: [String: PerfSummary]) -> String {
        var lines: [String] = []
        lines.append("CURRENCY: \(currency.rawValue)")
        lines.append("PORTFOLIO: value \(Money.currency(summary.currentValue, currency: currency)), invested \(Money.currency(summary.totalInvested, currency: currency)), P&L \(Money.signed(summary.profitLoss, currency: currency)) (\(Money.percent(summary.returnPercent))), annualised \(Money.percent(summary.annualisedReturn)). \(digests.count) holding\(digests.count == 1 ? "" : "s").")

        // Sector weights
        let total = digests.reduce(0) { $0 + $1.currentValue }
        if total > 0 {
            var sectors: [String: Double] = [:]
            for d in digests { sectors[d.sector, default: 0] += d.currentValue }
            let weights = sectors.sorted { $0.value > $1.value }
                .map { "\($0.key) \(Int(($0.value / total * 100).rounded()))%" }
                .joined(separator: ", ")
            lines.append("SECTOR WEIGHTS: \(weights)")
        }

        lines.append("")
        lines.append("HOLDINGS (each: position, then price performance, then recent news):")
        let df = DateFormatter(); df.dateFormat = "d MMM yyyy"
        for d in digests {
            let weightPct = total > 0 ? Int((d.currentValue / total * 100).rounded()) : 0
            lines.append("- \(d.ticker) (\(d.name), \(d.sector)): \(Int(d.shares)) shares bought \(df.string(from: d.purchaseDate)) @ \(Money.currency(d.purchasePrice, currency: currency)); cost basis \(Money.currency(d.costBasis, currency: currency)) (incl. FX \(Money.currency(d.fxCharge, currency: currency)) + fee \(Money.currency(d.brokerFee, currency: currency))); current price \(Money.currency(d.currentPrice, currency: currency)), position value \(Money.currency(d.currentValue, currency: currency)) (\(weightPct)% of portfolio); return \(Money.percent(d.returnPercent)), annualised \(Money.percent(d.annualisedReturn)).")
            if let p = perf[d.ticker] {
                lines.append("    • price performance: \(perfLine(p))")
            }
            if let items = news[d.ticker], !items.isEmpty {
                for n in items {
                    lines.append("    • news: \(n.headline) (\(n.source), \(n.date.formatted(date: .abbreviated, time: .omitted)))")
                }
            }
        }
        return lines.joined(separator: "\n")
    }
}
