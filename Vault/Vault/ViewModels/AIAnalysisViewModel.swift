//
//  AIAnalysisViewModel.swift
//  Vault
//
//  Builds a structured prompt from the user's portfolio, calls Claude for
//  commentary, and maintains the follow-up conversation in the sheet.
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

    let suggestions = [
        "How concentrated is my tech exposure really?",
        "Should I trim my biggest winner after this run?",
        "What would a healthcare position do to my risk?",
        "Is my portfolio beating the index after fees?"
    ]

    private let anthropic: AnthropicService
    private var systemPrompt = ""
    private let currency: DisplayCurrency

    init(anthropic: AnthropicService = .shared, currency: DisplayCurrency = .gbp) {
        self.anthropic = anthropic
        self.currency = currency
    }

    // MARK: Setup

    /// Compute factual metric cards and build the system prompt from holdings.
    func prepare(holdings: [Holding], summary: PortfolioSummary) {
        metrics = Self.computeMetrics(holdings: holdings, summary: summary, currency: currency)
        systemPrompt = Self.buildSystemPrompt(holdings: holdings, summary: summary, currency: currency)
    }

    /// Kick off the initial analysis (called when the sheet appears).
    func generateInitialAnalysis() async {
        guard messages.isEmpty else { return }
        generatedAt = .now

        guard KeychainService.shared.has(.anthropic) else {
            // Offline / no-key fallback so the sheet is never empty.
            messages = [ChatMessage(role: .assistant, text: Self.fallbackCommentary)]
            toast = Toast(message: "Add an Anthropic API key in Settings for live analysis.", kind: .info)
            return
        }

        await exchange(userText: "Analyse my portfolio. Give an overall commentary paragraph, a concentration risk assessment, the single top risk flag, and one actionable suggestion.",
                       showUserMessage: false)
    }

    /// Send a follow-up question.
    func ask(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await exchange(userText: trimmed, showUserMessage: true)
    }

    /// Generate a news-driven "today's brief" across the whole portfolio.
    /// Only runs when the user explicitly taps it (web search → live news).
    func generateBrief() async {
        guard !isLoading else { return }
        guard KeychainService.shared.has(.anthropic) else {
            toast = Toast(message: "Add an Anthropic API key in Settings to generate a brief.", kind: .info)
            return
        }
        await exchange(
            userText: "Give me today's brief. Search the web for the latest news across my holdings, then summarise in plain prose: what moved and why over the last day or two, the single most important development for this portfolio, and one thing to watch today. Be concise.",
            showUserMessage: true,
            webSearch: true
        )
    }

    // MARK: Networking

    private func exchange(userText: String, showUserMessage: Bool, webSearch: Bool = false) async {
        if showUserMessage {
            messages.append(ChatMessage(role: .user, text: userText))
        }
        isLoading = true
        defer { isLoading = false }

        // Build the message list sent to the API (always includes the user turn).
        var apiMessages = messages.filter { !($0.role == .assistant && $0.text.isEmpty) }
        if !showUserMessage {
            apiMessages.append(ChatMessage(role: .user, text: userText))
        }

        do {
            let reply = try await anthropic.send(messages: apiMessages, systemPrompt: systemPrompt, enableWebSearch: webSearch)
            messages.append(ChatMessage(role: .assistant, text: reply))
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            toast = Toast(message: message, kind: .error)
            if messages.isEmpty {
                messages = [ChatMessage(role: .assistant, text: Self.fallbackCommentary)]
            }
        }
    }

    // MARK: Metric computation

    private static func computeMetrics(holdings: [Holding], summary: PortfolioSummary,
                                       currency: DisplayCurrency) -> [AIMetric] {
        guard !holdings.isEmpty, summary.currentValue > 0 else { return [] }

        // Concentration: largest single sector weight.
        var sectorTotals: [String: Double] = [:]
        for h in holdings { sectorTotals[h.sector, default: 0] += h.currentValue }
        let topSector = sectorTotals.max { $0.value < $1.value }
        let concentration = (topSector?.value ?? 0) / summary.currentValue * 100

        let largest = holdings.max { $0.currentValue < $1.currentValue }
        let largestPct = (largest?.currentValue ?? 0) / summary.currentValue * 100
        let sectorCount = Set(holdings.map(\.sector)).count

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
                     value: "\(holdings.count)",
                     note: "across \(sectorCount) sector\(sectorCount == 1 ? "" : "s")",
                     tone: .neutral)
        ]
    }

    // MARK: Prompt construction

    private static func buildSystemPrompt(holdings: [Holding], summary: PortfolioSummary,
                                          currency: DisplayCurrency) -> String {
        var lines: [String] = []
        lines.append("You are a concise, sharp portfolio analyst inside an iPad investing app called Vault.")
        lines.append("The user holds the positions below. Currency is \(currency.rawValue). Be specific, reference real numbers, and never give boilerplate disclaimers beyond a brief one if essential.")
        lines.append("Keep responses to a few short paragraphs of plain prose — no markdown headers, no bullet lists.")
        lines.append("")
        lines.append("PORTFOLIO SUMMARY:")
        lines.append("- Total invested (cost basis incl. fees): \(Money.currency(summary.totalInvested, currency: currency))")
        lines.append("- Current value: \(Money.currency(summary.currentValue, currency: currency))")
        lines.append("- Profit/Loss: \(Money.signed(summary.profitLoss, currency: currency)) (\(Money.percent(summary.returnPercent)))")
        lines.append("- Annualised return: \(Money.percent(summary.annualisedReturn))")
        lines.append("")
        lines.append("HOLDINGS:")
        for h in holdings {
            lines.append("- \(h.ticker) (\(h.companyName), \(h.sector)): \(Int(h.shares)) shares, cost basis \(Money.currency(h.costBasis, currency: currency)), value \(Money.currency(h.currentValue, currency: currency)), return \(Money.percent(h.returnPercent))")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: Fallback

    static let fallbackCommentary = """
    Your portfolio is in healthy shape — up against cost basis and comfortably ahead of a broad index over the same window.

    The standout consideration is concentration. Technology dominates the book once you fold the large-cap names together, and an index position adds further large-cap tech exposure underneath. A tech drawdown would cost you proportionally more than a diversified investor.

    Your highest-conviction winner is also one of your most volatile lines — worth deciding whether you'd trim into strength to lock gains, or let it run.

    Net: a well-performing, tech-tilted portfolio. The single highest-leverage move would be adding a non-correlated sleeve — healthcare, energy, or international — to reduce concentration without sacrificing your growth posture.

    (This is sample analysis. Add an Anthropic API key in Settings to generate live commentary from Claude.)
    """
}
