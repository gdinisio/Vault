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
    }

    /// Fetch live FX rates so display-currency values are accurate.
    private func refreshFXRates() async {
        if let rates = await FXService.shared.fetchRates() {
            await MainActor.run {
                for (currency, rate) in rates { Money.rates[currency] = rate }
                settings.fxToken &+= 1   // nudge dependent views to recompute
            }
        }
    }

    private var tabView: some View {
        TabView(selection: $selection) {
            Tab("Portfolio", systemImage: "rectangle.split.3x1", value: VaultTab.portfolio) {
                PortfolioView(
                    viewModel: portfolioVM,
                    onOpenAI: { showAI = true },
                    onOpenSettings: { selection = .settings }
                )
            }
            Tab("Paper Trading", systemImage: "doc.text", value: VaultTab.paper) {
                PaperTradingView(
                    viewModel: paperVM,
                    onOpenAI: { showAI = true },
                    onOpenSettings: { selection = .settings }
                )
            }
            Tab("Watchlist", systemImage: "star", value: VaultTab.watchlist) {
                WatchlistView(onOpenSettings: { selection = .settings })
            }
            Tab("Settings", systemImage: "gearshape", value: VaultTab.settings) {
                SettingsView(settings: settings, paperVM: paperVM)
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
