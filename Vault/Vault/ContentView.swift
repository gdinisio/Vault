//
//  ContentView.swift
//  Vault
//
//  App shell: two-tab TabView over a performance-reactive Liquid Glass
//  background, with the AI Analysis and Settings sheets hosted at the top
//  level so they're reachable from both tabs.
//

import SwiftUI
import SwiftData

enum VaultTab: Hashable { case portfolio, paper, watchlist, settings }

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @Query private var holdings: [Holding]
    @Query private var positions: [PaperPosition]
    @Query private var watch: [WatchItem]

    @State private var portfolioVM = PortfolioViewModel()
    @State private var paperVM = PaperTradingViewModel()
    @State private var selection: VaultTab = .portfolio
    @State private var showAI = false

    /// AI analysis subject depends on the active tab: real holdings on the
    /// Portfolio side, paper positions on the Paper Trading side.
    private var aiInput: (digests: [HoldingDigest], summary: PortfolioSummary, title: String) {
        if selection == .paper {
            let s = paperVM.summary(positions: positions)
            let invested = positions.reduce(0) { $0 + $1.costBasis }
            let summary = PortfolioSummary(
                totalInvested: invested,
                currentValue: s.positionsValue,
                profitLoss: s.openProfitLoss,
                returnPercent: s.openReturnPercent,
                annualisedReturn: 0,
                performanceSignal: s.performanceSignal
            )
            return (positions.map { HoldingDigest($0) }, summary, "Paper account analysis")
        }
        return (holdings.map { HoldingDigest($0) }, portfolioVM.summary(for: holdings), "Portfolio analysis")
    }

    private var performance: Double {
        switch selection {
        case .portfolio, .settings, .watchlist: return portfolioVM.summary(for: holdings).performanceSignal
        case .paper: return paperVM.summary(positions: positions).performanceSignal
        }
    }

    var body: some View {
        ZStack {
            VaultBackground(performance: performance)

            tabView
        }
        .sensoryFeedback(.selection, trigger: selection)
        .fullScreenCover(isPresented: $showAI) {
            let input = aiInput
            AIAnalysisView(
                digests: input.digests,
                summary: input.summary,
                currency: settings.displayCurrency,
                title: input.title
            )
        }
        .task { await refreshFXRates() }
        // Rebuild widget snapshot on launch and whenever data/FX changes.
        .onChange(of: holdings.count) { _, _ in rebuildWidgetSnapshot() }
        .onChange(of: positions.count) { _, _ in rebuildWidgetSnapshot() }
        .onChange(of: watch.count) { _, _ in rebuildWidgetSnapshot() }
        .onChange(of: settings.fxToken) { _, _ in rebuildWidgetSnapshot() }
        // Deep-link routing: widgets open vault://portfolio|paper|watchlist|ticker/SYM
        .onOpenURL { url in handleDeepLink(url) }
    }

    /// Fetch live FX rates so display-currency values are accurate.
    private func refreshFXRates() async {
        if let rates = await FXService.shared.fetchRates() {
            await MainActor.run {
                for (currency, rate) in rates { Money.rates[currency] = rate }
                settings.fxToken &+= 1   // nudge dependent views to recompute
            }
        }
        // Rebuild snapshot after FX lands (fxToken change also triggers onChange,
        // but we do it here too so the very first launch gets a snapshot).
        rebuildWidgetSnapshot()
    }

    private func rebuildWidgetSnapshot() {
        Task {
            await WidgetSnapshotWriter.shared.rebuild(
                holdings: holdings,
                positions: positions,
                watch: watch,
                currency: settings.displayCurrency
            )
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "vault" else { return }
        switch url.host {
        case "portfolio":  selection = .portfolio
        case "paper":      selection = .paper
        case "watchlist":  selection = .watchlist
        case "settings":   selection = .settings
        case "ticker":     selection = .portfolio   // opens portfolio; detail tap is future work
        default:           break
        }
    }

    private var tabView: some View {
        TabView(selection: $selection) {
            Tab(value: VaultTab.portfolio) {
                NavigationStack {
                    PortfolioView(
                        viewModel: portfolioVM,
                        onOpenAI: { showAI = true }
                    )
                }
            } label: {
                Label("Portfolio", systemImage: "chart.pie.fill")
            }
            Tab(value: VaultTab.paper) {
                NavigationStack {
                    PaperTradingView(
                        viewModel: paperVM,
                        onOpenAI: { showAI = true }
                    )
                }
            } label: {
                Label("Paper Trading", systemImage: "chart.line.text.clipboard")
            }
            Tab(value: VaultTab.watchlist) {
                NavigationStack {
                    WatchlistView()
                }
            } label: {
                Label("Watchlist", systemImage: "star")
            }
            Tab(value: VaultTab.settings) {
                NavigationStack {
                    SettingsView(settings: settings, paperVM: paperVM)
                }
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .modify {
            if #available(iOS 26.0, *) {
                $0.tabBarMinimizeBehavior(.onScrollDown)
            } else {
                $0
            }
        }
    }
}

// MARK: - Conditional modifier helper

extension View {
    /// Apply a transform that may use availability-gated modifiers.
    @ViewBuilder
    func modify(@ViewBuilder _ transform: (Self) -> some View) -> some View {
        transform(self)
    }
}

#Preview(traits: .landscapeLeft) {
    ContentView()
        .environment(AppSettings())
        .modelContainer(MockData.previewContainer())
}
