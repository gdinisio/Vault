//
//  PaperPositionDetailView.swift
//  Vault
//
//  Pushed detail for an open paper position — value, live price chart, AI
//  analysis and a breakdown of cost basis and P&L. Sell is hosted here as a
//  sheet (no longer needs to route through the parent).
//

import SwiftUI
import SwiftData

struct PaperPositionDetailView: View {
    let position: PaperPosition
    var currency: DisplayCurrency = .gbp
    @Bindable var viewModel: PaperTradingViewModel
    let positions: [PaperPosition]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var showAnalysis = false
    @State private var showSell = false
    @State private var showBuy = false

    private var up: Bool { position.profitLoss >= 0 }

    private var snapshot: StockSnapshot {
        StockSnapshot(
            ticker: position.ticker,
            companyName: position.companyName,
            sector: position.sector,
            shares: position.shares,
            averageCost: position.averageCost,
            currentPrice: position.currentPrice,
            returnPercent: position.returnPercent
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                valueBlock
                PriceChartView(symbol: position.ticker, sector: position.sector, currency: currency)

                section("Position") {
                    detailRow("Shares", "\(Int(position.shares))")
                    detailRow("Average cost", Money.currency(position.averageCost, currency: currency))
                    detailRow("Cost basis", Money.currency(position.costBasis, currency: currency))
                    Divider().overlay(Theme.inkFaint.opacity(0.4))
                    detailRow("Current price", Money.currency(position.currentPrice, currency: currency))
                    detailRow("Current value", Money.currency(position.currentValue, currency: currency), emphasised: true)
                }

                section("Performance", footnote: "Last updated \(position.lastUpdated.formatted(date: .abbreviated, time: .shortened)).") {
                    detailRow("Profit / loss", Money.signed(position.profitLoss, currency: currency), tint: up ? Theme.gain : Theme.loss)
                    detailRow("Return", Money.percent(position.returnPercent), tint: up ? Theme.gain : Theme.loss)
                }

                NewsSection(symbol: position.ticker)
            }
            .padding(28)
        }
        .background(Theme.bgDeep.opacity(0.001))
        .navigationTitle(position.ticker)
        .navigationSubtitle(position.companyName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Haptics.impact(.light); showAnalysis = true } label: {
                    Label("Analyse with AI", systemImage: "sparkles")
                }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Button { Haptics.impact(.light); showBuy = true } label: {
                    Label("Buy", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { Haptics.impact(.rigid); showSell = true } label: {
                    Label("Sell", systemImage: "minus")
                }
            }
        }
        .sheet(isPresented: $showAnalysis) {
            StockAnalysisView(snapshot: snapshot, currency: currency)
        }
        .sheet(isPresented: $showSell) {
            SellView(viewModel: viewModel, positions: positions, currency: currency)
        }
        .sheet(isPresented: $showBuy) {
            BuyView(viewModel: viewModel, positions: positions, currency: currency,
                    preselect: AddHoldingView.SymbolResult(
                        symbol: position.ticker, name: position.companyName,
                        sector: position.sector, price: position.currentPrice))
        }
    }

    private var valueBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current value").vaultLabel()
            Text(Money.currency(position.currentValue, currency: currency))
                .font(.system(size: 44, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text("\(Money.signed(position.profitLoss, currency: currency)) · \(Money.percent(position.returnPercent))")
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundStyle(up ? Theme.gain : Theme.loss)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .contentCard()
    }

    // MARK: Building blocks

    private func section(_ title: String, footnote: String? = nil, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).vaultLabel()
            VStack(spacing: 12) { content() }
                .padding(20)
                .contentCard()
            if let footnote {
                Text(footnote)
                    .font(.footnote)
                    .foregroundStyle(Theme.inkDim)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
            }
        }
    }

    private func detailRow(_ label: String, _ value: String, tint: Color = Theme.ink, emphasised: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: emphasised ? .semibold : .regular))
                .foregroundStyle(emphasised ? Theme.ink : Theme.inkDim)
            Spacer()
            Text(value)
                .font(.system(size: emphasised ? 17 : 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint)
        }
    }
}

#Preview {
    NavigationStack {
        PaperPositionDetailView(
            position: MockData.positions[0],
            viewModel: PaperTradingViewModel(),
            positions: MockData.positions
        )
    }
    .modelContainer(MockData.previewContainer())
}
