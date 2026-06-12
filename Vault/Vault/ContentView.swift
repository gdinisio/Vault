//
//  ContentView.swift
//  Vault
//
//  App shell: a sidebar-adaptable TabView. On iPad it shows a native sidebar
//  the user can collapse into a floating top tab bar (like Files / Photos);
//  on iPhone it's a tab bar. Each section is its own NavigationStack, and
//  item details (holding / position / ticker) push as destinations.
//

import SwiftUI
import SwiftData

enum VaultTab: String, CaseIterable, Hashable {
    case portfolio, paper, watchlist, search, settings

    var title: String {
        switch self {
        case .portfolio: "Portfolio"
        case .paper:     "Paper Trading"
        case .watchlist: "Watchlists"
        case .search:    "Search"
        case .settings:  "Settings"
        }
    }

    var icon: String {
        switch self {
        case .portfolio: "chart.pie"
        case .paper:     "chart.line.text.clipboard"
        case .watchlist: "star"
        case .search:    "magnifyingglass"
        case .settings:  "gearshape"
        }
    }
}

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @Query private var holdings: [Holding]
    @Query private var positions: [PaperPosition]
    @Query private var watch: [WatchItem]

    @State private var portfolioVM = PortfolioViewModel()
    @State private var paperVM = PaperTradingViewModel()
    @State private var selection: VaultTab = .portfolio
    @State private var showAI = false

    /// Persisted tab/sidebar reorder state. Versioned key — bump to reset
    /// stored order when the tab structure changes.
    @AppStorage("vault.tabCustomization.v5") private var tabCustomization = TabViewCustomization()

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

    var body: some View {
        // Single sidebar-adaptable TabView: native sidebar on iPad (collapsible
        // to a floating tab bar) and a tab bar on iPhone. No manual background —
        // the system provides the standard sidebar material + content surface.
        tabView
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

    // MARK: - Section content (shared by tab bar and split view)

    @ViewBuilder
    private func tabContent(_ tab: VaultTab) -> some View {
        switch tab {
        case .portfolio:
            NavigationStack {
                PortfolioView(viewModel: portfolioVM, onOpenAI: { showAI = true })
            }
        case .paper:
            NavigationStack {
                PaperTradingView(viewModel: paperVM, onOpenAI: { showAI = true })
                    .navigationDestination(for: PaperPosition.self) { position in
                        PaperPositionDetailView(position: position, currency: currency,
                                                viewModel: paperVM, positions: positions)
                    }
            }
        case .watchlist:
            NavigationStack {
                WatchlistsView(viewModel: paperVM)
                    .navigationDestination(for: WatchItem.self) { item in
                        WatchDetailView(item: item, currency: currency, viewModel: paperVM)
                    }
            }
        case .search:
            SearchView()
        case .settings:
            NavigationStack {
                SettingsView(settings: settings, paperVM: paperVM)
            }
        }
    }

    // MARK: - Sidebar-adaptable TabView (tab-bar reorder)

    // Flat root tabs (no TabSection) with `.tabViewCustomization` — reorderable
    // in the TAB BAR. Sidebar rows stay fixed: only TabSection members get the
    // sidebar's drag-to-reorder affordance, and there's no section here.
    // String-based `Tab` inits — the label-closure form crashes the Xcode 27
    // beta preview JIT. Search keeps its `.search` system slot.
    private var tabView: some View {
        TabView(selection: $selection) {
            Tab(VaultTab.search.title, systemImage: VaultTab.search.icon,
                value: .search, role: .search) {
                tabContent(.search)
            }
            .customizationID("vault.tab.search")

            Tab(VaultTab.portfolio.title, systemImage: VaultTab.portfolio.icon,
                value: .portfolio) {
                tabContent(.portfolio)
            }
            .customizationID("vault.tab.portfolio")
            .customizationBehavior(.reorderable, for: .tabBar)

            Tab(VaultTab.paper.title, systemImage: VaultTab.paper.icon,
                value: .paper) {
                tabContent(.paper)
            }
            .customizationID("vault.tab.paper")
            .customizationBehavior(.reorderable, for: .tabBar)

            Tab(VaultTab.watchlist.title, systemImage: VaultTab.watchlist.icon,
                value: .watchlist) {
                tabContent(.watchlist)
            }
            .customizationID("vault.tab.watchlist")
            .customizationBehavior(.reorderable, for: .tabBar)

            Tab(VaultTab.settings.title, systemImage: VaultTab.settings.icon,
                value: .settings) {
                tabContent(.settings)
            }
            .customizationID("vault.tab.settings")
            .customizationBehavior(.reorderable, for: .tabBar)
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

