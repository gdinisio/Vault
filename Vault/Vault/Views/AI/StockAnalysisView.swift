//
//  StockAnalysisView.swift
//  Vault
//
//  Per-stock decision-support sheet: position + analyst consensus header,
//  the AI's news-grounded sections (What's happening / Bull / Bear / Watch /
//  Lean), recent headlines, and a follow-up "Ask AI" field.
//

import SwiftUI

struct StockAnalysisView: View {
    let snapshot: StockSnapshot
    var currency: DisplayCurrency = .gbp

    @State private var viewModel: StockAnalysisViewModel
    @State private var draft = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool

    init(snapshot: StockSnapshot, currency: DisplayCurrency = .gbp, initialMessages: [ChatMessage] = []) {
        self.snapshot = snapshot
        self.currency = currency
        let vm = StockAnalysisViewModel(snapshot: snapshot, currency: currency)
        vm.messages = initialMessages   // seed a conversation (used by previews)
        _viewModel = State(initialValue: vm)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                positionStrip
                content
            }
            .frame(maxWidth: 920)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Ask bar floats as Liquid Glass chrome — content scrolls under it
            // (matches AIAnalysisView).
            .safeAreaInset(edge: .bottom) {
                askBar
                    .frame(maxWidth: 920)
                    .frame(maxWidth: .infinity)
            }
            .navigationTitle(snapshot.ticker)
            .navigationSubtitle("Decision support · \(snapshot.companyName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .toast($viewModel.toast)
        }
        .presentationBackground(.ultraThickMaterial)
        .presentationCornerRadius(Theme.sheetRadius)
        .presentationDetents([.large])
        .task { await viewModel.generate() }
    }

    // MARK: Position + consensus strip

    private var positionStrip: some View {
        HStack(spacing: 12) {
            infoChip(label: "Your position",
                     value: "\(Int(snapshot.shares)) sh",
                     note: "@ \(Money.currency(snapshot.averageCost, currency: currency))")
            infoChip(label: "Return",
                     value: Money.percent(snapshot.returnPercent),
                     note: Money.currency(snapshot.currentPrice, currency: currency),
                     tint: Theme.tone(snapshot.returnPercent))
            if let c = viewModel.consensus {
                infoChip(label: "Analyst consensus",
                         value: c.consensus,
                         note: "\(c.totalBuy) buy · \(c.hold) hold · \(c.totalSell) sell",
                         tint: consensusTint(c))
            } else {
                infoChip(label: "Live news", value: "On", note: "from recent headlines", tint: Theme.aiPurple)
            }
        }
        .padding(.horizontal, 30).padding(.top, 8).padding(.bottom, 6)
    }

    private func infoChip(label: String, value: String, note: String, tint: Color = Theme.ink) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11, weight: .semibold)).tracking(0.6).textCase(.uppercase).foregroundStyle(Theme.inkDim)
            Text(value).font(.system(size: 20, weight: .semibold, design: .monospaced)).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.6)
            Text(note).font(.system(size: 11.5)).foregroundStyle(Theme.inkDim).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 14)
        .contentCard(cornerRadius: 18)
    }

    private func consensusTint(_ c: RecommendationTrend) -> Color {
        switch c.consensus {
        case "Strong Buy", "Buy", "Add": return Theme.gain
        case "Sell": return Theme.loss
        default: return Theme.ink
        }
    }

    // MARK: Content

    private var content: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        Text("Add a **Gemini** or **Groq** API key in Settings to get a news-driven read on \(snapshot.ticker). Recent headlines are listed below.")
                            .font(.subheadline).foregroundStyle(Theme.ink).lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(18)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.line.opacity(0.05)))
                    }
                    ForEach(viewModel.messages) { message in
                        if message.role == .user {
                            userBubble(message.text)
                        } else {
                            AnalysisSections(text: message.text)
                        }
                    }
                    if viewModel.isLoading {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small).tint(Theme.aiPurple)
                            Text("Reading the latest news…").font(.subheadline).foregroundStyle(Theme.inkDim)
                        }.id("loading")
                    }
                    if !viewModel.headlines.isEmpty {
                        sourcesView
                    }
                }
                .padding(.horizontal, 30).padding(.vertical, 18)
            }
            .scrollIndicators(.hidden)
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func userBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 60)
            Text(text).font(.system(size: 16)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.accent.opacity(0.25)))
        }
    }

    private var sourcesView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent headlines").vaultLabel()
            ForEach(viewModel.headlines.prefix(5)) { item in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(Theme.inkFaint).frame(width: 5, height: 5).padding(.top, 7)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.headline).font(.system(size: 13.5)).foregroundStyle(Theme.ink).lineLimit(2)
                        Text("\(item.source) · \(item.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 11.5)).foregroundStyle(Theme.inkDim)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.line.opacity(0.05)))
    }

    // MARK: Ask bar

    private var askBar: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(viewModel.suggestions, id: \.self) { s in
                        Button { send(s) } label: {
                            Text(s).font(.system(size: 13.5)).foregroundStyle(Theme.ink)
                                .padding(.horizontal, 15).padding(.vertical, 9)
                                .glassEffect(.regular, in: .capsule)
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 30)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 10) {
                TextField("Ask AI about \(snapshot.ticker)…", text: $draft)
                    .textFieldStyle(.plain).font(.system(size: 16.5)).foregroundStyle(Theme.ink)
                    .focused($inputFocused).onSubmit { send(draft) }.padding(.leading, 22)
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
            .padding(.horizontal, 30)
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

// MARK: - Markdown section renderer

/// Renders the AI's `## Heading` + body markdown into styled sections. Falls
/// back to plain paragraphs when there are no headings (e.g. follow-up replies).
private struct AnalysisSections: View {
    let text: String

    private struct Section: Identifiable { let id = UUID(); let title: String?; let body: String }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(parse()) { section in
                VStack(alignment: .leading, spacing: 6) {
                    if let title = section.title {
                        HStack(spacing: 8) {
                            Image(systemName: icon(for: title))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(tint(for: title))
                            Text(title)
                                .font(.system(size: 13, weight: .semibold)).tracking(0.4).textCase(.uppercase)
                                .foregroundStyle(tint(for: title))
                        }
                    }
                    Text(attributed(section.body))
                        .font(.system(size: section.title == nil ? 16 : 16.5))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func parse() -> [Section] {
        let lines = text.components(separatedBy: "\n")
        var sections: [Section] = []
        var currentTitle: String?
        var buffer: [String] = []

        func flush() {
            let body = buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if currentTitle != nil || !body.isEmpty {
                sections.append(Section(title: currentTitle, body: body))
            }
            buffer = []
        }

        for line in lines {
            if line.hasPrefix("## ") {
                flush()
                currentTitle = line.replacingOccurrences(of: "## ", with: "").trimmingCharacters(in: .whitespaces)
            } else {
                buffer.append(line)
            }
        }
        flush()
        return sections.filter { $0.title != nil || !$0.body.isEmpty }
    }

    private func attributed(_ body: String) -> AttributedString {
        (try? AttributedString(markdown: body, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(body)
    }

    private func icon(for title: String) -> String {
        switch title {
        case "What's happening": return "newspaper"
        case "Bull case": return "arrow.up.right"
        case "Bear case": return "arrow.down.right"
        case "What to watch": return "eye"
        case "Lean": return "scalemass"
        default: return "circle.fill"
        }
    }

    private func tint(for title: String) -> Color {
        switch title {
        case "Bull case": return Theme.gain
        case "Bear case": return Theme.loss
        case "Lean": return Theme.aiPurple
        default: return Theme.accent
        }
    }
}

#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        StockAnalysisView(
            snapshot: StockSnapshot(holding: MockData.holdings[4]),
            initialMessages: [
                ChatMessage(role: .assistant, text: "The recent move is **earnings-driven** — last week's print beat on both revenue and margins, and the stock has held the gains since. Sentiment in the headlines below is broadly positive, with the main debate being **valuation** after the run rather than the fundamentals.\n\nFor your position specifically: you're sitting on a solid unrealised gain, so the decision is about **risk**, not conviction. If this name has grown into an oversized share of your portfolio, scaling back into strength is defensible.\n\nWhat to watch: guidance at the next quarter and any shift in the demand commentary that's been driving the multiple."),
                ChatMessage(role: .user, text: "Is now a good entry point to add more?"),
                ChatMessage(role: .assistant, text: "Adding *after* a sharp run means you're paying up, so size any add modestly and consider **averaging in** rather than a single lump. The headlines don't show a fresh catalyst — the move is the previous beat working through — so there's no urgency. I'm not able to give personalised investment advice, but the balanced read is: the thesis is intact, the price is fuller, and patience costs little here.")
            ]
        )
    }
}
