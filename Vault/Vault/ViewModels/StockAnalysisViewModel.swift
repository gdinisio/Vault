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

        // Pull structured grounding from Finnhub (recent news + analyst
        // consensus) regardless of whether a provider key is set.
        if KeychainService.shared.has(.finnhub) {
            async let news = try? await finnhub.companyNews(for: snapshot.ticker, days: 14)
            async let rec = try? await finnhub.recommendation(for: snapshot.ticker)
            headlines = Array((await news ?? []).prefix(8))
            consensus = await rec
        }

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
        lines.append("You are a sharp equity analyst inside an iPad investing app called Vault. You give decision-support analysis for a single stock. You are NOT a fortune teller: never predict prices or give a guaranteed buy/sell signal. Instead synthesise the provided facts into a balanced view and a reasoned lean.")
        lines.append("Use ONLY the data, analyst consensus and recent headlines provided below — do not invent figures or events.")
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
}
