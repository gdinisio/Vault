//
//  AIAnalysisView.swift
//  Vault
//
//  Full-screen AI Analysis sheet: the AI's portfolio commentary, factual risk
//  metric cards, suggestion chips and an "Ask AI" follow-up field.
//

import SwiftUI

struct AIAnalysisView: View {
    let digests: [HoldingDigest]
    let summary: PortfolioSummary
    var currency: DisplayCurrency = .gbp
    var title: String = "Portfolio analysis"

    @State private var viewModel: AIAnalysisViewModel
    @State private var draft = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool

    init(digests: [HoldingDigest], summary: PortfolioSummary, currency: DisplayCurrency = .gbp, title: String = "Portfolio analysis", initialMessages: [ChatMessage] = []) {
        self.digests = digests
        self.summary = summary
        self.currency = currency
        self.title = title
        let vm = AIAnalysisViewModel(currency: currency)
        vm.messages = initialMessages   // seed a conversation (used by previews)
        _viewModel = State(initialValue: vm)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                metrics
                conversation
            }
            .frame(maxWidth: 1040)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Ask bar floats as Liquid Glass chrome: the conversation scrolls
            // *under* it (no flat bottom block to scroll past), and the
            // suggestion chips hover over the text alongside it.
            .safeAreaInset(edge: .bottom) {
                askBar
                    .frame(maxWidth: 1040)
                    .frame(maxWidth: .infinity)
            }
            .navigationTitle(title)
            .navigationSubtitle(providerLine)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .toast($viewModel.toast)
        }
        .presentationBackground(.ultraThinMaterial)
        .presentationCornerRadius(Theme.sheetRadius)
        .task {
            viewModel.prepare(digests: digests, summary: summary)
            await viewModel.generateInitialAnalysis()
        }
    }

    private var providerLine: String {
        "\(viewModel.lastProvider.map { "via \($0.rawValue)" } ?? "AI analysis") · \(viewModel.generatedAt.formatted(.dateTime.day().month(.abbreviated).year().hour().minute()))"
    }

    // MARK: Metrics

    /// Flat stat row (Stocks "Key Statistics" style) — no card chrome; the three
    /// stats sit on one line at all widths (equal columns), so iPhone never
    /// wraps a metric onto a second row. Labels reserve two lines so the values
    /// stay aligned even when a label ("Largest position") wraps on a narrow
    /// iPhone column; values shrink to fit rather than truncate.
    private var metrics: some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(viewModel.metrics) { metric in
                VStack(alignment: .leading, spacing: 5) {
                    Text(metric.label)
                        .font(.caption2.weight(.semibold)).textCase(.uppercase)
                        .foregroundStyle(Theme.inkDim)
                        .lineLimit(2, reservesSpace: true)
                    Text(metric.value)
                        .font(.system(size: 26, weight: .semibold, design: .monospaced))
                        .foregroundStyle(tone(metric.tone))
                        .lineLimit(1).minimumScaleFactor(0.5)
                    Text(metric.note)
                        .font(.caption2).foregroundStyle(Theme.inkDim)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 34).padding(.top, 8).padding(.bottom, 12)
    }

    private func tone(_ tone: AIMetric.Tone) -> Color {
        switch tone {
        case .good: return Theme.gain
        case .warn: return Theme.warn
        case .neutral: return Theme.ink
        }
    }

    // MARK: Conversation

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        emptyHint
                    }
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    if viewModel.isLoading {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small).tint(Theme.aiPurple)
                            Text("Analysing your portfolio…").font(.subheadline).foregroundStyle(Theme.inkDim)
                        }
                        .id("loading")
                    }
                }
                .padding(.horizontal, 34).padding(.vertical, 20)
                .frame(maxWidth: 920, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            // Soft fade where the conversation meets the metrics (top) and the
            // floating ask bar (bottom) — no hard scroll edges.
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var emptyHint: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Get your portfolio analysed")
                .font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.ink)
            Text("Add a **Gemini** or **Groq** API key in Settings to enable in-app analysis — it compiles your holdings, P&L and the latest news on each position and runs it automatically.")
                .font(.subheadline).foregroundStyle(Theme.ink).lineSpacing(4)
            Text("The metric cards above are computed live on-device.")
                .font(.footnote).foregroundStyle(Theme.inkDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.line.opacity(0.05)))
    }

    // MARK: Ask bar

    private var askBar: some View {
        VStack(spacing: 12) {
            // suggestion chips — "Today's brief" runs a live web-search brief
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Button {
                        Haptics.impact(.light)
                        Task { await viewModel.generateBrief() }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "newspaper.fill").font(.caption)
                            Text("Today's brief").font(.system(size: 13.5, weight: .bold))
                        }
                        .foregroundStyle(Theme.aiPurple)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        // Liquid Glass like the other chips, but a faint tint +
                        // bold text keep it the featured action.
                        .glassEffect(.regular.tint(Theme.aiPurple.opacity(0.22)), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isLoading)

                    ForEach(viewModel.suggestions, id: \.self) { suggestion in
                        Button { send(suggestion) } label: {
                            Text(suggestion).font(.system(size: 13.5)).foregroundStyle(Theme.ink)
                                .padding(.horizontal, 15).padding(.vertical, 9)
                                .glassEffect(.regular, in: .capsule)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 34)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 10) {
                TextField("Ask AI about your portfolio…", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16.5))
                    .foregroundStyle(Theme.ink)
                    .focused($inputFocused)
                    .onSubmit { send(draft) }
                    .padding(.leading, 22)
                Button { send(draft) } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 17))
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.aiPurpleButton)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading)
                .padding(5)
            }
            .glassEffect(.regular, in: .capsule)
            .padding(.horizontal, 34)
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private func send(_ text: String) {
        let toSend = text.trimmingCharacters(in: .whitespaces)
        guard !toSend.isEmpty else { return }
        draft = ""
        inputFocused = false
        Task { await viewModel.ask(toSend) }
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        if message.role == .user {
            HStack {
                Spacer(minLength: 60)
                Text(message.text)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.accent.opacity(0.25)))
            }
        } else {
            // assistant: parse paragraphs with **bold**
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, para in
                    Text(attributed(para))
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var paragraphs: [String] {
        message.text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func attributed(_ text: String) -> AttributedString {
        // Convert markdown **bold** to attributed runs.
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        AIAnalysisView(
            digests: MockData.holdings.map { HoldingDigest($0) },
            summary: PortfolioViewModel().summary(for: MockData.holdings),
            initialMessages: [
                ChatMessage(role: .assistant, text: "Your book is **up 12.4% annualised** and the recent move is led by technology. The standout is **NVDA**, which after its run is now roughly a third of your holdings — that's the single biggest driver of both your gains and your risk.\n\nThe main concern is **concentration**: technology is ~58% of the portfolio, so a sector pullback would hit you harder than the index. Recent headlines remain constructive — **AAPL** on services growth and **MSFT** on cloud margins — but none of that offsets the single-name weight in NVDA.\n\nOne concrete step: trimming a slice of NVDA into a healthcare or broad index position would cut diversification risk meaningfully without giving up much expected return."),
                ChatMessage(role: .user, text: "Should I trim my biggest winner after this run?"),
                ChatMessage(role: .assistant, text: "Trimming **NVDA** is risk management, not a bet against the company. At ~33% of your book, a **10–15% trim** brings it back toward a 25% weight while leaving plenty of upside exposure.\n\nTwo things to weigh: the **tax impact** of realising gains in a taxable account, and where you redeploy — an under-weighted sector improves your diversification more than adding to another tech name.")
            ]
        )
    }
}
