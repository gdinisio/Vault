//
//  StockAnalysisViewModel.swift
//  Vault
//
//  Per-stock decision-support analysis. Grounds the AI in the user's actual
//  position, live analyst consensus and recent company news (Finnhub), then
//  runs it through the provider chain (Gemini → Groq). Frames output as
//  considerations — never a price prediction.
//

import SwiftUI

/// Immutable snapshot of a holding so the VM never touches a SwiftData model
/// off the main actor.
struct StockSnapshot {
    let ticker: String
    let companyName: String
    let sector: String
    let shares: Double
    let averageCost: Double
    let currentPrice: Double
    let returnPercent: Double

    init(holding: Holding) {
        ticker = holding.ticker
        companyName = holding.companyName
        sector = holding.sector
        shares = holding.shares
        averageCost = holding.purchasePricePerShare
        currentPrice = holding.currentPrice
        returnPercent = holding.returnPercent
    }

    init(ticker: String, companyName: String, sector: String, shares: Double,
         averageCost: Double, currentPrice: Double, returnPercent: Double) {
        self.ticker = ticker
        self.companyName = companyName
        self.sector = sector
        self.shares = shares
        self.averageCost = averageCost
        self.currentPrice = currentPrice
        self.returnPercent = returnPercent
    }
}

@MainActor
@Observable
final class StockAnalysisViewModel {
    var messages: [ChatMessage] = []
    var isLoading = false
    var toast: Toast?
    var consensus: RecommendationTrend?
    var headlines: [CompanyNews] = []
    private var perf: PerfSummary?
    private var quote: FinnhubQuote?
    private var groundingLoaded = false

    let suggestions = [
        "What are the biggest near-term risks?",
        "How does this fit my overall portfolio?",
        "What would change the thesis?",
        "Summarise the latest earnings."
    ]

    /// Which provider produced the latest reply.
    var lastProvider: AIProvider?

    private let snapshot: StockSnapshot
    private let currency: DisplayCurrency
    private let finnhub: FinnhubService
    private let ai: AIService

    init(snapshot: StockSnapshot, currency: DisplayCurrency,
         finnhub: FinnhubService = .shared, ai: AIService = .shared) {
        self.snapshot = snapshot
        self.currency = currency
        self.finnhub = finnhub
        self.ai = ai
    }

    var hasProvider: Bool {
        KeychainService.shared.has(.gemini) || KeychainService.shared.has(.groq)
    }

    // MARK: Generation

    func generate() async {
        guard messages.isEmpty else { return }
        await loadGrounding()

        // With a provider key, analyse automatically; otherwise the view shows
        // a hint to add a Gemini/Groq key in Settings.
        guard hasProvider else { return }
        await exchange(
            userText: "Give me a decision-support analysis of this stock using the data and news provided.",
            showUserMessage: false
        )
    }

    func ask(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Make sure the full grounding (performance, news, consensus) is attached
        // even if the question is asked before the auto-analysis finishes.
        await loadGrounding()
        await exchange(userText: trimmed, showUserMessage: true)
    }

    /// Pull structured grounding once: price performance (Yahoo, no key needed)
    /// plus recent news, analyst consensus and a live quote (Finnhub).
    private func loadGrounding() async {
        guard !groundingLoaded else { return }
        groundingLoaded = true
        perf = (await AIContext.performance(for: [snapshot.ticker]))[snapshot.ticker]
        if KeychainService.shared.has(.finnhub) {
            async let news = try? await finnhub.companyNews(for: snapshot.ticker, days: 14)
            async let rec = try? await finnhub.recommendation(for: snapshot.ticker)
            async let q = try? await finnhub.quote(for: snapshot.ticker)
            headlines = Array((await news ?? []).prefix(10))
            consensus = await rec
            quote = await q
        }
    }

    // MARK: Networking

    private func exchange(userText: String, showUserMessage: Bool) async {
        if showUserMessage { messages.append(ChatMessage(role: .user, text: userText)) }
        isLoading = true
        defer { isLoading = false }

        var apiMessages = messages.filter { !($0.role == .assistant && $0.text.isEmpty) }
        if !showUserMessage { apiMessages.append(ChatMessage(role: .user, text: userText)) }

        do {
            let result = try await ai.chat(system: systemPrompt, messages: apiMessages)
            lastProvider = result.provider
            messages.append(ChatMessage(role: .assistant, text: result.text))
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            toast = Toast(message: message, kind: .error)
        }
    }

    // MARK: Prompt

    private var systemPrompt: String {
        var lines: [String] = []
        lines.append("You are a sharp equity analyst inside an iPad investing app called Vault, giving decision-support analysis for a single stock. You are NOT a fortune teller: never predict a price or give a guaranteed buy/sell signal — synthesise the provided facts into a balanced view and a single, reasoned stance.")
        lines.append("Use ONLY the position, price performance, analyst consensus and headlines provided below. Quote the actual numbers and cite headlines by name. Never invent figures or events; if something isn't covered, say so.")
        lines.append("")
        lines.append("Reply in GitHub-flavoured markdown using EXACTLY these `## ` sections, in this order:")
        lines.append("")
        lines.append("## What's happening")
        lines.append("2-3 sentences on the latest material news and catalysts, citing specific headlines.")
        lines.append("")
        lines.append("## Bull case")
        lines.append("1-2 sentences grounded in the data.")
        lines.append("")
        lines.append("## Bear case")
        lines.append("1-2 sentences grounded in the data.")
        lines.append("")
        lines.append("## What to watch")
        lines.append("1-2 concrete upcoming items (earnings dates, product launches, macro).")
        lines.append("")
        lines.append("## Verdict")
        lines.append("Begin this section with your single stance in bold — write exactly ONE of **Hold**, **Trim**, **Add**, or **Sell**. Choose one; do NOT list the options and do NOT write them separated by slashes. Then give 1-2 sentences of reasoning that reference the user's cost basis, position size and return, plus the price performance. Example of the required form: \"**Trim** — you're up 64% and this is now an outsized position, so taking some profit reduces single-stock risk.\"")
        lines.append("")
        lines.append("End with one italic line exactly: *Not financial advice — your research and risk tolerance decide.*")
        lines.append("")
        lines.append("THE USER'S POSITION:")
        lines.append("- \(snapshot.ticker) (\(snapshot.companyName), \(snapshot.sector))")
        if snapshot.shares > 0 {
            lines.append("- \(Int(snapshot.shares)) shares at average cost \(Money.currency(snapshot.averageCost, currency: currency))")
            lines.append("- Current price \(Money.currency(snapshot.currentPrice, currency: currency)), unrealised return \(Money.percent(snapshot.returnPercent))")
        } else {
            lines.append("- The user does NOT currently hold this stock (watchlist / research only). Current price \(Money.currency(snapshot.currentPrice, currency: currency)). Frame the Verdict as whether to open a position (Add) or stay out (Hold).")
        }

        if let perf {
            lines.append("")
            lines.append("PRICE PERFORMANCE: \(AIContext.perfLine(perf))")
        }
        if let quote, let dp = quote.dp {
            lines.append("TODAY: \(Money.percent(dp)) (previous close \(Money.currency(quote.pc, currency: currency)))")
        }

        if let consensus {
            lines.append("")
            lines.append("ANALYST CONSENSUS (Finnhub, period \(consensus.period)): \(consensus.consensus) — \(consensus.totalBuy) buy, \(consensus.hold) hold, \(consensus.totalSell) sell.")
        }
        if !headlines.isEmpty {
            lines.append("")
            lines.append("RECENT HEADLINES (Finnhub, last 14 days):")
            for item in headlines.prefix(10) {
                lines.append("- \(item.headline) (\(item.source), \(item.date.formatted(date: .abbreviated, time: .omitted)))")
            }
        }
        return lines.joined(separator: "\n")
    }
}
