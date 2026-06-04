//
//  StockAnalysisViewModel.swift
//  Vault
//
//  Per-stock decision-support analysis. Grounds Claude in the user's actual
//  position, live analyst consensus and recent company news (Finnhub), and
//  lets Claude pull the freshest headlines via web search. Frames output as
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

    let suggestions = [
        "What are the biggest near-term risks?",
        "How does this fit my overall portfolio?",
        "What would change the thesis?",
        "Summarise the latest earnings."
    ]

    private let snapshot: StockSnapshot
    private let currency: DisplayCurrency
    private let finnhub: FinnhubService
    private let anthropic: AnthropicService

    init(snapshot: StockSnapshot, currency: DisplayCurrency,
         finnhub: FinnhubService = .shared, anthropic: AnthropicService = .shared) {
        self.snapshot = snapshot
        self.currency = currency
        self.finnhub = finnhub
        self.anthropic = anthropic
    }

    // MARK: Generation

    func generate() async {
        guard messages.isEmpty else { return }
        guard KeychainService.shared.has(.anthropic) else {
            toast = Toast(message: "Add an Anthropic API key in Settings to analyse this stock.", kind: .info)
            messages = [ChatMessage(role: .assistant, text: Self.fallback(snapshot))]
            return
        }

        // Pull structured grounding from Finnhub concurrently (best-effort).
        if KeychainService.shared.has(.finnhub) {
            async let news = try? await finnhub.companyNews(for: snapshot.ticker, days: 14)
            async let rec = try? await finnhub.recommendation(for: snapshot.ticker)
            headlines = Array((await news ?? []).prefix(8))
            consensus = await rec
        }

        await exchange(
            userText: "Give me a decision-support analysis of this position.",
            showUserMessage: false
        )
    }

    func ask(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await exchange(userText: trimmed, showUserMessage: true)
    }

    // MARK: Networking

    private func exchange(userText: String, showUserMessage: Bool) async {
        if showUserMessage { messages.append(ChatMessage(role: .user, text: userText)) }
        isLoading = true
        defer { isLoading = false }

        var apiMessages = messages.filter { !($0.role == .assistant && $0.text.isEmpty) }
        if !showUserMessage { apiMessages.append(ChatMessage(role: .user, text: userText)) }

        do {
            let reply = try await anthropic.send(messages: apiMessages,
                                                 systemPrompt: systemPrompt,
                                                 enableWebSearch: true)
            messages.append(ChatMessage(role: .assistant, text: reply))
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            toast = Toast(message: message, kind: .error)
            if messages.isEmpty { messages = [ChatMessage(role: .assistant, text: Self.fallback(snapshot))] }
        }
    }

    // MARK: Prompt

    private var systemPrompt: String {
        var lines: [String] = []
        lines.append("You are a sharp equity analyst inside an iPad investing app called Vault. You give decision-support analysis for a single stock the user already owns. You are NOT a fortune teller: never predict prices or give a guaranteed buy/sell signal. Instead synthesise recent facts into a balanced view and a reasoned lean.")
        lines.append("Use the web_search tool to find the most recent news, earnings and analyst commentary before answering. Prefer information from the last few weeks.")
        lines.append("")
        lines.append("Respond in GitHub-flavoured markdown using EXACTLY these sections, each as a `## ` heading, in this order:")
        lines.append("## What's happening — 2-3 sentences on the latest material news/catalysts.")
        lines.append("## Bull case — 1-2 sentences.")
        lines.append("## Bear case — 1-2 sentences.")
        lines.append("## What to watch — 1-2 concrete upcoming items (earnings dates, product launches, macro).")
        lines.append("## Lean — one of Hold / Trim / Add / Sell as **bold**, then 1-2 sentences of reasoning that references the user's cost basis and position size. This is a consideration, not advice.")
        lines.append("End with a single italic line: *Not financial advice — your research and risk tolerance decide.*")
        lines.append("")
        lines.append("THE USER'S POSITION:")
        lines.append("- \(snapshot.ticker) (\(snapshot.companyName), \(snapshot.sector))")
        lines.append("- \(Int(snapshot.shares)) shares at average cost \(Money.currency(snapshot.averageCost, currency: currency))")
        lines.append("- Current price \(Money.currency(snapshot.currentPrice, currency: currency)), unrealised return \(Money.percent(snapshot.returnPercent))")

        if let consensus {
            lines.append("")
            lines.append("ANALYST CONSENSUS (Finnhub, period \(consensus.period)): \(consensus.consensus) — \(consensus.totalBuy) buy, \(consensus.hold) hold, \(consensus.totalSell) sell.")
        }
        if !headlines.isEmpty {
            lines.append("")
            lines.append("RECENT HEADLINES (Finnhub):")
            for item in headlines.prefix(8) {
                lines.append("- \(item.headline) (\(item.source), \(item.date.formatted(date: .abbreviated, time: .omitted)))")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: Fallback

    private static func fallback(_ s: StockSnapshot) -> String {
        """
        ## What's happening
        Live analysis needs an Anthropic API key (and a Finnhub key for fresh news). Add them in Settings to get a news-driven read on \(s.ticker).

        ## Bull case
        Add your keys and Claude will search recent news and earnings to build this.

        ## Bear case
        Same — grounded in the latest headlines once keys are set.

        ## What to watch
        Upcoming earnings and sector catalysts.

        ## Lean
        **Hold** — no live data yet. You're \(Money.percent(s.returnPercent)) on this position at \(Int(s.shares)) shares.

        *Not financial advice — your research and risk tolerance decide.*
        """
    }
}
