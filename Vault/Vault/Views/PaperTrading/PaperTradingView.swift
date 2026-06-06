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
            .vaultPagePadding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Paper Trading")
        .toolbar { toolbarContent }
        .id(settings.fxToken)   // rebuild when live FX rate lands
        .toast($viewModel.toast)
        .sheet(isPresented: $showBuy) {
            BuyView(viewModel: viewModel, positions: positions, currency: currency)
        }
        .sheet(isPresented: $showSell) {
            SellView(viewModel: viewModel, positions: positions, currency: currency)
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
        // Hero equity value
        let equityValue = VStack(alignment: .leading, spacing: 6) {
            Text("Account equity").vaultLabel()
            Text(Money.currency(summary.equity, currency: currency))
                .font(.system(size: portrait ? 40 : 52, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.5).lineLimit(1)
        }

        // Inline stat block shared by both orientations
        let stats = HStack(spacing: 0) {
            Divider()
                .frame(height: 36)
                .padding(.horizontal, 18)

            VStack(alignment: .leading, spacing: 3) {
                Text("Open P&L").vaultLabel()
                HStack(spacing: 6) {
                    Text(Money.signed(summary.openProfitLoss, currency: currency))
                    Text(Money.percent(summary.openReturnPercent))
                }
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.tone(summary.openProfitLoss))
                .lineLimit(1).minimumScaleFactor(0.7)
            }

            Divider()
                .frame(height: 36)
                .padding(.horizontal, 18)

            VStack(alignment: .leading, spacing: 3) {
                Text("Virtual cash").vaultLabel()
                Text(Money.currency0(viewModel.cash, currency: currency))
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }

            Spacer()
        }

        if portrait {
            VStack(alignment: .leading, spacing: 14) {
                equityValue
                stats
            }
        } else {
            HStack(alignment: .bottom, spacing: 0) {
                equityValue
                stats.padding(.bottom, 4)
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
                        NavigationLink(value: position) {
                            PaperPositionRowView(position: position, currency: currency)
                        }
                        .buttonStyle(.plain)
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
