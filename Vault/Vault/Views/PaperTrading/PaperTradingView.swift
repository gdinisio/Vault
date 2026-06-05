//
//  PaperTradingView.swift
//  Vault
//
//  The Paper Trading tab: virtual cash, equity, open positions, equity curve
//  and trade history. Orientation-adaptive (matches PortfolioView) and fully
//  scrollable so nothing is clipped on shorter screens.
//

import SwiftUI
import SwiftData

struct PaperTradingView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: \PaperPosition.ticker) private var positions: [PaperPosition]
    @Query(sort: \PaperTrade.timestamp, order: .reverse) private var trades: [PaperTrade]

    @Bindable var viewModel: PaperTradingViewModel
    var onOpenAI: () -> Void

    @State private var showBuy = false
    @State private var showSell = false
    @State private var selectedPosition: PaperPosition?

    private var currency: DisplayCurrency {
        _ = settings.fxToken   // re-render when live FX rates update
        return settings.displayCurrency
    }
    private var summary: PaperSummary { viewModel.summary(positions: positions) }
    private var sortedPositions: [PaperPosition] {
        positions.sorted { $0.currentValue > $1.currentValue }
    }

    var body: some View {
        GeometryReader { geo in
            let portrait = geo.size.height > geo.size.width
            VStack(alignment: .leading, spacing: 0) {
                equityBand(portrait: portrait)
                    .padding(.top, portrait ? 6 : 10)
                    .padding(.bottom, portrait ? 16 : 22)
                content(portrait: portrait)
            }
            .padding(.horizontal, portrait ? 28 : 52)
            .padding(.top, portrait ? 12 : 16)
            .padding(.bottom, 24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .id(settings.fxToken)   // rebuild when live FX rate lands
        .toast($viewModel.toast)
        .sheet(isPresented: $showBuy) {
            BuyView(viewModel: viewModel, positions: positions, currency: currency)
        }
        .sheet(isPresented: $showSell) {
            SellView(viewModel: viewModel, positions: positions, currency: currency)
        }
        .sheet(item: $selectedPosition) { position in
            PaperPositionDetailView(position: position, currency: currency) {
                // Dismiss the detail first so we never touch a position that
                // selling may delete, then open the Sell sheet.
                selectedPosition = nil
                showSell = true
            }
        }
        .task { await viewModel.refreshPrices(for: positions) }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Leading: utility (refresh) — plain glass.
        ToolbarItem(placement: .topBarLeading) {
            Button {
                Task { await viewModel.refreshPrices(for: positions) }
            } label: {
                if viewModel.isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .disabled(viewModel.isRefreshing)
        }
        // Trailing: primary tools (AI + Buy) — prominent, each its own capsule.
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onOpenAI) {
                Image(systemName: "sparkles")
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.aiPurpleButton)
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            Button { showBuy = true } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.gainButton)
        }
    }

    // MARK: Equity band

    @ViewBuilder
    private func equityBand(portrait: Bool) -> some View {
        let equity = VStack(alignment: .leading, spacing: 8) {
            Text("Account equity").vaultLabel()
            Text(Money.currency(summary.equity, currency: currency))
                .font(.system(size: portrait ? 48 : 64, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.5).lineLimit(1)
        }
        let pl = VStack(alignment: .leading, spacing: 4) {
            Text("Open P&L").vaultLabel()
            Text(Money.signed(summary.openProfitLoss, currency: currency))
                .font(.system(size: 30, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.tone(summary.openProfitLoss))
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(Money.percent(summary.openReturnPercent))
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.tone(summary.openProfitLoss))
        }
        let cash = VStack(alignment: .leading, spacing: 4) {
            Text("Virtual cash").vaultLabel()
            Text(Money.currency0(viewModel.cash, currency: currency))
                .font(.system(size: 30, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
        }

        if portrait {
            VStack(alignment: .leading, spacing: 18) {
                equity
                HStack(alignment: .bottom, spacing: 44) {
                    pl
                    cash
                    Spacer()
                }
            }
        } else {
            HStack(alignment: .bottom, spacing: 44) {
                equity
                pl.padding(.bottom, 8)
                cash.padding(.bottom, 8)
                Spacer()
            }
        }
    }

    // MARK: Content (orientation-adaptive, scrollable)

    @ViewBuilder
    private func content(portrait: Bool) -> some View {
        if portrait {
            // Single column: everything scrolls together.
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    positionsSection
                    equityCurve.frame(height: 200)
                    TradeHistoryView(trades: trades, currency: currency, scrolls: false)
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .refreshable { await viewModel.refreshPrices(for: positions) }
        } else {
            // Two columns: left scrolls (positions + equity curve), right is the
            // self-scrolling trade history.
            HStack(alignment: .top, spacing: 22) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        positionsSection
                        equityCurve.frame(height: 210)
                    }
                    .padding(.bottom, 4)
                }
                .scrollIndicators(.hidden)
                .refreshable { await viewModel.refreshPrices(for: positions) }
                .frame(maxWidth: .infinity)

                TradeHistoryView(trades: trades, currency: currency)
                    .frame(width: 396)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var positionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Open positions").font(.system(size: 21, weight: .semibold)).foregroundStyle(Theme.ink)
                Spacer()
                HStack(spacing: 14) {
                    Text("\(positions.count) open").font(.system(size: 14, design: .monospaced)).foregroundStyle(Theme.inkDim)
                    if !positions.isEmpty {
                        Button { showSell = true } label: {
                            Text("Sell").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.loss)
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                .background(Capsule().fill(Theme.loss.opacity(0.15)))
                        }.buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 4)

            if positions.isEmpty {
                emptyPositions
            } else {
                VStack(spacing: 12) {
                    ForEach(sortedPositions) { position in
                        PaperPositionRowView(position: position, currency: currency)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Haptics.impact(.light)
                                selectedPosition = position
                            }
                    }
                }
            }
        }
    }

    private var equityCurve: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Equity curve").font(.system(size: 21, weight: .semibold)).foregroundStyle(Theme.ink)
                Spacer()
                Text("session").font(.system(size: 13, design: .monospaced)).foregroundStyle(Theme.inkDim)
            }
            SparklineView(
                points: Spark.series(seed: 3.1, count: 70, trendingUp: summary.openProfitLoss >= 0),
                color: Theme.tone(summary.openProfitLoss)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 26).padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentCard()
    }

    private var emptyPositions: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray").font(.system(size: 40)).foregroundStyle(Theme.inkFaint)
            Text("No open positions").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.ink)
            Text("Tap Buy to place your first paper order.").font(.system(size: 14)).foregroundStyle(Theme.inkDim)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .contentCard(cornerRadius: 22)
    }
}

#Preview(traits: .landscapeLeft) {
    ZStack {
        VaultBackground(performance: 0.4)
        PaperTradingView(viewModel: PaperTradingViewModel(), onOpenAI: {})
            .environment(AppSettings())
    }
    .modelContainer(MockData.previewContainer())
}
