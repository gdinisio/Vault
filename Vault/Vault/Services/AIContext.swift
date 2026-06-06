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

enum AIContext {

    /// Fetch a few recent headlines per ticker (best-effort; needs a Finnhub key).
    static func fetchNews(for tickers: [String], perTicker: Int = 3) async -> [String: [CompanyNews]] {
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

    // MARK: Portfolio prompts

    /// System prompt: analysis instructions + the compiled portfolio data & news.
    static func portfolioSystemPrompt(digests: [HoldingDigest], summary: PortfolioSummary,
                                      currency: DisplayCurrency, news: [String: [CompanyNews]]) -> String {
        var s = instructionBlock()
        s += "\n\n" + portfolioData(digests: digests, summary: summary, currency: currency, news: news)
        return s
    }

    private static func instructionBlock() -> String {
        """
        You are a sharp, concise portfolio analyst inside an iPad investing app called Vault. The user's full PORTFOLIO DATA and recent NEWS are provided below — treat them as the complete, authoritative context for the whole conversation. Ground EVERY answer strictly in those figures and headlines: quote the actual numbers (values, prices, P&L, sector weights) and cite specific headlines by name. Never invent figures or events, and if the data doesn't cover something, say so rather than guessing. You are not a fortune teller: don't predict prices or give guaranteed buy/sell signals — give balanced, reasoned considerations.

        Answer the user's actual question directly and specifically using this data. If they ask for a general review or "what do you think about my portfolio", cover, in order: overall health and recent performance (referencing the news); concentration / diversification risk (cite the sector weights); the single biggest risk right now (cite a specific recent headline if available); and one concrete, actionable suggestion.

        Reply in clear plain prose (no markdown headers). Keep it tight and specific. End every reply with one line exactly: "Not financial advice."
        """
    }

    private static func portfolioData(digests: [HoldingDigest], summary: PortfolioSummary,
                                      currency: DisplayCurrency, news: [String: [CompanyNews]]) -> String {
        var lines: [String] = []
        lines.append("CURRENCY: \(currency.rawValue)")
        lines.append("PORTFOLIO: value \(Money.currency(summary.currentValue, currency: currency)), invested \(Money.currency(summary.totalInvested, currency: currency)), P&L \(Money.signed(summary.profitLoss, currency: currency)) (\(Money.percent(summary.returnPercent))), annualised \(Money.percent(summary.annualisedReturn)).")

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
        lines.append("HOLDINGS:")
        let df = DateFormatter(); df.dateFormat = "d MMM yyyy"
        for d in digests {
            lines.append("- \(d.ticker) (\(d.name), \(d.sector)): \(Int(d.shares)) shares bought \(df.string(from: d.purchaseDate)) @ \(Money.currency(d.purchasePrice, currency: currency)); cost basis \(Money.currency(d.costBasis, currency: currency)) (incl. FX \(Money.currency(d.fxCharge, currency: currency)) + fee \(Money.currency(d.brokerFee, currency: currency))); current price \(Money.currency(d.currentPrice, currency: currency)), position value \(Money.currency(d.currentValue, currency: currency)); return \(Money.percent(d.returnPercent)), annualised \(Money.percent(d.annualisedReturn)).")
            if let items = news[d.ticker], !items.isEmpty {
                for n in items {
                    lines.append("    • news: \(n.headline) (\(n.source), \(n.date.formatted(date: .abbreviated, time: .omitted)))")
                }
            }
        }
        return lines.joined(separator: "\n")
    }
}
