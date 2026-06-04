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

enum VaultTab: Hashable { case portfolio, paper, settings }

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @Query private var holdings: [Holding]
    @Query private var positions: [PaperPosition]

    @State private var portfolioVM = PortfolioViewModel()
    @State private var paperVM = PaperTradingViewModel()
    @State private var selection: VaultTab = .portfolio
    @State private var showAI = false

    private var performance: Double {
        switch selection {
        case .portfolio: return portfolioVM.summary(for: holdings).performanceSignal
        case .paper: return paperVM.summary(positions: positions).performanceSignal
        case .settings: return portfolioVM.summary(for: holdings).performanceSignal
        }
    }

    var body: some View {
        ZStack {
            VaultBackground(performance: performance)

            tabView
        }
        .sensoryFeedback(.selection, trigger: selection)
        .fullScreenCover(isPresented: $showAI) {
            AIAnalysisView(
                holdings: holdings,
                summary: portfolioVM.summary(for: holdings),
                currency: settings.displayCurrency
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
