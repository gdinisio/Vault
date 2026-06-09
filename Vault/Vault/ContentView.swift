//
//  ContentView.swift
//  Vault
//
//  App shell: a sidebar-adaptable TabView. On iPad it shows a Liquid Glass
//  sidebar that the user can collapse into a floating top tab bar (like Files /
//  Photos); on iPhone it's a tab bar. Each section is its own NavigationStack,
//  and item details (holding / position / ticker) push as destinations.
//

import SwiftUI
import SwiftData

enum VaultTab: Hashable { case portfolio, paper, watchlist, search, settings }

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @Query private var holdings: [Holding]
    @Query private var positions: [PaperPosition]
    @Query private var watch: [WatchItem]

    @State private var portfolioVM = PortfolioViewModel()
    @State private var paperVM = PaperTradingViewModel()
    @State private var selection: VaultTab = .portfolio
    @State private var showAI = false

    /// User-customisable sidebar/tab-bar order. Bound to the native iOS 26
    /// customisation experience — tapping Edit in the sidebar header lets the
    /// user reorder and hide tabs; the choices persist across launches.
    @AppStorage("vault.tabCustomization") private var tabCustomization = TabViewCustomization()

    private var currency: DisplayCurrency {
        _ = settings.fxToken
        return settings.displayCurrency
    }

    /// AI analysis subject depends on the active section.
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
        case .paper: return paperVM.summary(positions: positions).performanceSignal
        default:     return portfolioVM.summary(for: holdings).performanceSignal
        }
    }

    var body: some View {
        ZStack {
            VaultBackground(performance: performance)
                .ignoresSafeArea()

            tabView
        }
        .sensoryFeedback(.selection, trigger: selection)
        .fullScreenCover(isPresented: $showAI) {
            let input = aiInput
            AIAnalysisView(
                digests: input.digests,
                summary: input.summary,
                currency: currency,
                title: input.title
            )
        }
        .task { await refreshFXRates() }
        .onChange(of: holdings.count) { _, _ in rebuildWidgetSnapshot() }
        .onChange(of: positions.count) { _, _ in rebuildWidgetSnapshot() }
        .onChange(of: watch.count)    { _, _ in rebuildWidgetSnapshot() }
        .onChange(of: settings.fxToken) { _, _ in rebuildWidgetSnapshot() }
        .onOpenURL { url in handleDeepLink(url) }
    }

    // MARK: - Tab view (sidebar-adaptable)

    private var tabView: some View {
        TabView(selection: $selection) {
            Tab(value: VaultTab.portfolio) {
                NavigationStack {
                    PortfolioView(viewModel: portfolioVM, onOpenAI: { showAI = true })
                        .navigationDestination(for: Holding.self) { holding in
                            HoldingDetailView(holding: holding, currency: currency)
                        }
                }
            } label: {
                Label("Portfolio", systemImage: "chart.pie")
            }
            .customizationID("vault.tab.portfolio")
            .customizationBehavior(.reorderable, for: .sidebar, .tabBar)

            Tab(value: VaultTab.paper) {
                NavigationStack {
                    PaperTradingView(viewModel: paperVM, onOpenAI: { showAI = true })
                        .navigationDestination(for: PaperPosition.self) { position in
                            PaperPositionDetailView(position: position, currency: currency,
                                                    viewModel: paperVM, positions: positions)
                        }
                }
            } label: {
                Label("Paper Trading", systemImage: "chart.line.text.clipboard")
            }
            .customizationID("vault.tab.paper")
            .customizationBehavior(.reorderable, for: .sidebar, .tabBar)

            Tab(value: VaultTab.watchlist) {
                NavigationStack {
                    WatchlistsView()
                        .navigationDestination(for: WatchlistGroup.self) { group in
                            WatchlistGroupDetailView(group: group, viewModel: paperVM)
                        }
                        .navigationDestination(for: WatchItem.self) { item in
                            WatchDetailView(item: item, currency: currency, viewModel: paperVM)
                        }
                }
            } label: {
                Label("Watchlists", systemImage: "star")
            }
            .customizationID("vault.tab.watchlist")
            .customizationBehavior(.reorderable, for: .sidebar, .tabBar)

            // Search keeps its fixed conventional position — it stays put
            // while the other tabs are reorderable (never hideable).
            Tab(value: VaultTab.search, role: .search) {
                SearchView()
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .customizationID("vault.tab.search")
            .customizationBehavior(.disabled, for: .sidebar, .tabBar)

            Tab(value: VaultTab.settings) {
                NavigationStack {
                    SettingsView(settings: settings, paperVM: paperVM)
                }
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .customizationID("vault.tab.settings")
            .customizationBehavior(.reorderable, for: .sidebar, .tabBar)
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewCustomization($tabCustomization)
    }

    // MARK: - Helpers

    private func refreshFXRates() async {
        if let rates = await FXService.shared.fetchRates() {
            await MainActor.run {
                for (currency, rate) in rates { Money.rates[currency] = rate }
                settings.fxToken &+= 1
            }
        }
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
        case "ticker":     selection = .watchlist
        default:           break
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
