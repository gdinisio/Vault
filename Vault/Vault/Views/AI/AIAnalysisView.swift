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

    init(digests: [HoldingDigest], summary: PortfolioSummary, currency: DisplayCurrency = .gbp, title: String = "Portfolio analysis") {
        self.digests = digests
        self.summary = summary
        self.currency = currency
        self.title = title
        _viewModel = State(initialValue: AIAnalysisViewModel(currency: currency))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            metrics
            conversation
            askBar
        }
        .frame(maxWidth: 1040)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toast($viewModel.toast)
        .presentationBackground(.ultraThinMaterial)
        .presentationCornerRadius(Theme.sheetRadius)
        .task {
            viewModel.prepare(digests: digests, summary: summary)
            await viewModel.generateInitialAnalysis()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 22))
                .foregroundStyle(Theme.aiPurple)
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.aiPurple.opacity(0.18))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.aiPurple.opacity(0.35), lineWidth: 1))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 21, weight: .semibold)).foregroundStyle(Theme.ink)
                Text("\(viewModel.lastProvider.map { "via \($0.rawValue)" } ?? "AI analysis") · \(viewModel.generatedAt.formatted(.dateTime.day().month(.abbreviated).year().hour().minute()))")
                    .font(.system(size: 13)).foregroundStyle(Theme.inkDim)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                    .frame(width: 38, height: 38).background(Circle().fill(Theme.line.opacity(0.08)))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 34).padding(.top, 26).padding(.bottom, 18)
    }

    // MARK: Metrics

    private var metrics: some View {
        HStack(spacing: 12) {
            ForEach(viewModel.metrics) { metric in
                VStack(alignment: .leading, spacing: 8) {
                    Text(metric.label)
                        .font(.system(size: 11, weight: .semibold)).tracking(0.8).textCase(.uppercase)
                        .foregroundStyle(Theme.inkDim)
                    Text(metric.value)
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .foregroundStyle(tone(metric.tone))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(metric.note).font(.system(size: 12)).foregroundStyle(Theme.inkDim).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18).padding(.vertical, 16)
                .glassPillCard()
            }
        }
        .padding(.horizontal, 34).padding(.bottom, 8)
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
                            Text("Analysing your portfolio…").font(.system(size: 14)).foregroundStyle(Theme.inkDim)
                        }
                        .id("loading")
                    }
                }
                .padding(.horizontal, 34).padding(.vertical, 20)
                .frame(maxWidth: 920, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
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
                .font(.system(size: 15)).foregroundStyle(Theme.inkSoft).lineSpacing(4)
            Text("The metric cards above are computed live on-device.")
                .font(.system(size: 13)).foregroundStyle(Theme.inkDim)
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
                            Image(systemName: "newspaper.fill").font(.system(size: 12))
                            Text("Today's brief").font(.system(size: 13.5, weight: .semibold))
                        }
                        .foregroundStyle(Theme.aiPurple)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(
                            Capsule().fill(Theme.aiPurple.opacity(0.16))
                                .overlay(Capsule().strokeBorder(Theme.aiPurple.opacity(0.35), lineWidth: 0.5))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isLoading)

                    ForEach(viewModel.suggestions, id: \.self) { suggestion in
                        Button { send(suggestion) } label: {
                            Text(suggestion).font(.system(size: 13.5)).foregroundStyle(Theme.inkSoft)
                                .padding(.horizontal, 15).padding(.vertical, 9)
                                .glassPill()
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 34)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 12) {
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
                        .foregroundStyle(Theme.onButton)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(LinearGradient(colors: [Theme.aiPurpleButton, Theme.aiPurpleButton.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading)
                .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                .padding(4)
            }
            .padding(4)
            .glassPill()
            .padding(.horizontal, 34)
        }
        .padding(.bottom, 28)
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
                        .foregroundStyle(Theme.inkSoft)
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

// MARK: - Glass helpers

private extension View {
    func glassPillCard() -> some View {
        background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.line.opacity(0.12), lineWidth: 0.5))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        AIAnalysisView(
            digests: MockData.holdings.map { HoldingDigest($0) },
            summary: PortfolioViewModel().summary(for: MockData.holdings)
        )
    }
}
