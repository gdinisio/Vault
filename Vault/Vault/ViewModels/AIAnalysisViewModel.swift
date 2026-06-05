//
//  AIAnalysisViewModel.swift
//  Vault
//
//  Compiles portfolio data + per-holding news, runs it through the AI provider
//  chain (Gemini → Groq), and maintains the follow-up conversation. Also builds
//  the self-contained prompt for the copy-paste flow.
//

import SwiftUI

struct AIMetric: Identifiable {
    enum Tone { case good, warn, neutral }
    let id = UUID()
    let label: String
    let value: String
    let note: String
    let tone: Tone
}

@MainActor
@Observable
final class AIAnalysisViewModel {
    var messages: [ChatMessage] = []
    var metrics: [AIMetric] = []
    var isLoading = false
    var toast: Toast?
    var generatedAt = Date()
    /// Which provider produced the latest reply (for the header label).
    var lastProvider: AIProvider?
    private(set) var didPrepare = false

    let suggestions = [
        "How concentrated is my tech exposure really?",
        "Should I trim my biggest winner after this run?",
        "What would a healthcare position do to my risk?",
        "Is my portfolio beating the index after fees?"
    ]

    private let ai: AIService
    private let currency: DisplayCurrency
    private var digests: [HoldingDigest] = []
    private var summaryData = PortfolioSummary()
    private var systemPrompt = ""
    private var contextLoaded = false

    init(ai: AIService = .shared, currency: DisplayCurrency = .gbp) {
        self.ai = ai
        self.currency = currency
    }

    var hasProvider: Bool {
        KeychainService.shared.has(.gemini) || KeychainService.shared.has(.groq)
    }

    // MARK: Setup

    /// Compute factual metric cards from pre-built digests (sync, on main).
    func prepare(digests: [HoldingDigest], summary: PortfolioSummary) {
        self.digests = digests
        summaryData = summary
        metrics = Self.computeMetrics(digests: digests, summary: summary, currency: currency)
        didPrepare = true
    }

    /// Fetch per-holding news and build the rich system prompt (once).
    func loadContext() async {
        guard !contextLoaded, !digests.isEmpty else { return }
        let news = await AIContext.fetchNews(for: digests.map(\.ticker))
        systemPrompt = AIContext.portfolioSystemPrompt(digests: digests, summary: summaryData, currency: currency, news: news)
        contextLoaded = true
    }

    /// Kick off the initial analysis when the sheet appears. With a provider key
    /// it runs automatically; otherwise the user uses the copy-paste bar.
    func generateInitialAnalysis() async {
        guard messages.isEmpty else { return }
        generatedAt = .now
        await loadContext()
        guard hasProvider else { return }
        await exchange(userText: "Analyse my portfolio using the data and news provided.", showUserMessage: false)
    }

    func ask(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await exchange(userText: trimmed, showUserMessage: true)
    }

    /// A news-driven "what moved" brief (only when the user taps it).
    func generateBrief() async {
        guard !isLoading else { return }
        await loadContext()
        guard hasProvider else {
            toast = Toast(message: "Add a Gemini or Groq API key in Settings to enable AI analysis.", kind: .info)
            return
        }
        await exchange(
            userText: "Give me a brief: using the news provided, summarise what moved recently and why, the single most important development for this portfolio, and one thing to watch. Be concise.",
            showUserMessage: true
        )
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

    // MARK: Metric computation (factual, on-device)

    private static func computeMetrics(digests: [HoldingDigest], summary: PortfolioSummary,
                                       currency: DisplayCurrency) -> [AIMetric] {
        guard !digests.isEmpty, summary.currentValue > 0 else { return [] }

        var sectorTotals: [String: Double] = [:]
        for d in digests { sectorTotals[d.sector, default: 0] += d.currentValue }
        let topSector = sectorTotals.max { $0.value < $1.value }
        let concentration = (topSector?.value ?? 0) / summary.currentValue * 100

        let largest = digests.max { $0.currentValue < $1.currentValue }
        let largestPct = (largest?.currentValue ?? 0) / summary.currentValue * 100
        let sectorCount = Set(digests.map(\.sector)).count

        return [
            AIMetric(label: "Concentration",
                     value: String(format: "%.0f%%", concentration),
                     note: "\(topSector?.key ?? "—") weight",
                     tone: concentration >= 45 ? .warn : .neutral),
            AIMetric(label: "Annualised return",
                     value: Money.percent(summary.annualisedReturn),
                     note: "trailing, cost-weighted",
                     tone: summary.annualisedReturn >= 0 ? .good : .warn),
            AIMetric(label: "Largest position",
                     value: largest?.ticker ?? "—",
                     note: String(format: "%.0f%% of book", largestPct),
                     tone: .neutral),
            AIMetric(label: "Holdings",
                     value: "\(digests.count)",
                     note: "across \(sectorCount) sector\(sectorCount == 1 ? "" : "s")",
                     tone: .neutral)
        ]
    }
}
