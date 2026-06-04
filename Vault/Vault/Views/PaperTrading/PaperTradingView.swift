//
//  PaperTradingView.swift
//  Vault
//
//  The Paper Trading tab: virtual cash, equity, open positions, equity curve
//  and trade history.
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
    var onOpenSettings: () -> Void

    @State private var showBuy = false
    @State private var showSell = false

    private var currency: DisplayCurrency {
        _ = settings.fxToken   // re-render when live FX rates update
        return settings.displayCurrency
    }
    private var summary: PaperSummary { viewModel.summary(positions: positions) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            equityBand.padding(.top, 28).padding(.bottom, 24)
            content
        }
        .padding(.horizontal, 52)
        .padding(.top, 38)
        .padding(.bottom, 24)
        .toast($viewModel.toast)
        .sheet(isPresented: $showBuy) {
            BuyView(viewModel: viewModel, positions: positions, currency: currency)
        }
        .sheet(isPresented: $showSell) {
            SellView(viewModel: viewModel, positions: positions, currency: currency)
        }
        .task { await viewModel.refreshPrices(for: positions) }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Paper Trading").font(.system(size: 28, weight: .semibold)).foregroundStyle(Theme.ink)
                Text("Practice with virtual money · no real funds at risk")
                    .font(.system(size: 14)).foregroundStyle(Theme.inkDim)
            }
            Spacer()
            HStack(spacing: 12) {
                HeaderButton(systemImage: "arrow.clockwise", isBusy: viewModel.isRefreshing) {
                    Task { await viewModel.refreshPrices(for: positions) }
                }
                HeaderButton(systemImage: "gearshape", action: onOpenSettings)
                Button(action: onOpenAI) {
                    HStack(spacing: 9) {
                        Image(systemName: "sparkles").foregroundStyle(Theme.aiPurple)
                        Text("AI Analysis").font(.system(size: 15.5, weight: .semibold)).foregroundStyle(Theme.ink)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12).glassPill()
                }.buttonStyle(.plain)

                // virtual cash pill + buy
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Virtual cash").vaultLabel()
                        Text(Money.currency(viewModel.cash, currency: currency))
                            .font(.system(size: 23, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.ink)
                    }
                    Button { showBuy = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus").font(.system(size: 16, weight: .bold))
                            Text("Buy").font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(Theme.onButton)
                        .padding(.horizontal, 24).padding(.vertical, 13)
                        .background(Capsule().fill(LinearGradient(colors: [Theme.gainButton, Theme.gainButton.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    }.buttonStyle(.plain)
                }
                .padding(.leading, 22).padding(.trailing, 13).padding(.vertical, 13)
                .glassCard(cornerRadius: 999)
            }
        }
    }

    // MARK: Equity band

    private var equityBand: some View {
        HStack(alignment: .bottom, spacing: 44) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Account equity").vaultLabel()
                Text(Money.currency(summary.equity, currency: currency))
                    .font(.system(size: 64, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.6).lineLimit(1)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Open P&L").vaultLabel()
                Text(Money.signed(summary.openProfitLoss, currency: currency))
                    .font(.system(size: 30, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.tone(summary.openProfitLoss))
                Text(Money.percent(summary.openReturnPercent))
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.tone(summary.openProfitLoss))
            }
            .padding(.bottom, 8)
            Spacer()
        }
    }

    // MARK: Content

    private var content: some View {
        HStack(alignment: .top, spacing: 22) {
            // left: positions + equity curve
            VStack(alignment: .leading, spacing: 18) {
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
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(positions.sorted { $0.currentValue > $1.currentValue }) { position in
                                PaperPositionRowView(position: position, currency: currency)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxHeight: 280)
                }

                equityCurve
            }
            .frame(maxWidth: .infinity)

            TradeHistoryView(trades: trades, currency: currency)
                .frame(width: 396)
        }
        .frame(maxHeight: .infinity)
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
            .frame(maxWidth: .infinity)
            .frame(height: 150)
        }
        .padding(.horizontal, 26).padding(.vertical, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassCard()
    }

    private var emptyPositions: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray").font(.system(size: 40)).foregroundStyle(Theme.inkFaint)
            Text("No open positions").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.ink)
            Text("Tap Buy to place your first paper order.").font(.system(size: 14)).foregroundStyle(Theme.inkDim)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .glassCard(cornerRadius: 22)
    }
}

#Preview(traits: .landscapeLeft) {
    ZStack {
        VaultBackground(performance: 0.4)
        PaperTradingView(viewModel: PaperTradingViewModel(), onOpenAI: {}, onOpenSettings: {})
            .environment(AppSettings())
    }
    .modelContainer(MockData.previewContainer())
}
