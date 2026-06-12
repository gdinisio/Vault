//
//  WatchDetailView.swift
//  Vault
//
//  Detail for a watched ticker: real price chart, AI decision-support, and a
//  shortcut to try the idea in paper trading. Actions live in the toolbar.
//

import SwiftUI
import SwiftData

struct WatchDetailView: View {
    let item: WatchItem
    var currency: DisplayCurrency = .gbp
    @Bindable var viewModel: PaperTradingViewModel

    @Query private var positions: [PaperPosition]

    @State private var latestClose: Double = 0
    @State private var showAnalysis = false
    @State private var showBuy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PriceChartView(symbol: item.ticker, sector: item.sector, currency: currency)
                NewsSection(symbol: item.ticker)
            }
            .padding(20)
        }
        .background(Theme.bgDeep.opacity(0.001))
        .navigationTitle(item.ticker)
        .navigationSubtitle(item.companyName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Haptics.impact(.light); showAnalysis = true } label: {
                    Label("Analyse with AI", systemImage: "sparkles")
                }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Button { Haptics.impact(.light); showBuy = true } label: {
                    Label("Buy in Paper Trading", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAnalysis) {
            StockAnalysisView(
                snapshot: StockSnapshot(ticker: item.ticker, companyName: item.companyName, sector: item.sector,
                                        shares: 0, averageCost: 0, currentPrice: latestClose, returnPercent: 0),
                currency: currency
            )
        }
        .sheet(isPresented: $showBuy) {
            BuyView(viewModel: viewModel, positions: positions, currency: currency,
                    preselect: AddHoldingView.SymbolResult(
                        symbol: item.ticker, name: item.companyName,
                        sector: item.sector, price: latestClose > 0 ? latestClose : nil))
        }
        .task {
            if let history = try? await PriceHistoryService.shared.history(for: item.ticker, range: .month),
               let last = history.last?.close {
                latestClose = last
            }
        }
    }
}

#Preview {
    NavigationStack {
        WatchDetailView(item: MockData.watchlist[0], viewModel: PaperTradingViewModel())
    }
    .modelContainer(MockData.previewContainer())
}
