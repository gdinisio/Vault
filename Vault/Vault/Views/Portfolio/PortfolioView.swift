//
//  PortfolioView.swift
//  Vault
//
//  The Portfolio tab: summary header, allocation donut and holdings list.
//

import SwiftUI
import SwiftData

struct PortfolioView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Holding.purchaseDate) private var holdings: [Holding]

    @Bindable var viewModel: PortfolioViewModel
    var onOpenAI: () -> Void
    var onOpenSettings: () -> Void

    @State private var showAddSheet = false
    @State private var selectedHolding: Holding?
    @State private var range = "1M"

    private var sortedHoldings: [Holding] {
        holdings.sorted { $0.currentValue > $1.currentValue }
    }

    private var summary: PortfolioSummary { viewModel.summary(for: holdings) }
    private var currency: DisplayCurrency {
        _ = settings.fxToken   // re-render when live FX rates update
        return settings.displayCurrency
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if holdings.isEmpty {
                emptyState
            } else {
                heroBand
                    .padding(.top, 26)
                    .padding(.bottom, 22)
                columns
            }
        }
        .padding(.horizontal, 52)
        .padding(.top, 38)
        .padding(.bottom, 24)
        .toast($viewModel.toast)
        .sheet(isPresented: $showAddSheet) {
            AddHoldingView(currency: currency) { holding in
                viewModel.add(holding, in: context)
                Task { await viewModel.refreshPrices(for: [holding]) }
            }
        }
        .sheet(item: $selectedHolding) { holding in
            HoldingDetailView(holding: holding, currency: currency)
        }
        .task { await viewModel.refreshPrices(for: holdings) }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Portfolio")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Your live holdings · \(currency.rawValue)")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkDim)
            }
            Spacer()
            HStack(spacing: 12) {
                HeaderButton(systemImage: "arrow.clockwise", isBusy: viewModel.isRefreshing) {
                    Task { await viewModel.refreshPrices(for: holdings) }
                }
                HeaderButton(systemImage: "gearshape", action: onOpenSettings)
                Button(action: onOpenAI) {
                    HStack(spacing: 9) {
                        Image(systemName: "sparkles").foregroundStyle(Theme.aiPurple)
                        Text("AI Analysis").font(.system(size: 15.5, weight: .semibold)).foregroundStyle(Theme.ink)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .glassPill()
                }
                .buttonStyle(.plain)
                Button { showAddSheet = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(size: 16, weight: .bold))
                        Text("Add holding").font(.system(size: 15.5, weight: .semibold))
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .background(
                        Capsule().fill(Theme.line.opacity(0.10))
                            .overlay(Capsule().strokeBorder(Theme.line.opacity(0.14), lineWidth: 0.5))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Hero

    private var heroBand: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Total portfolio value").vaultLabel().padding(.bottom, 10)
                Text(Money.currency(summary.currentValue, currency: currency))
                    .font(.system(size: 76, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                HStack(spacing: 18) {
                    HStack(spacing: 7) {
                        Image(systemName: summary.profitLoss >= 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.tone(summary.profitLoss))
                            .frame(width: 26, height: 26)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.tone(summary.profitLoss).opacity(0.18)))
                        Text(Money.signed(summary.profitLoss, currency: currency))
                            .font(.system(size: 21, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.tone(summary.profitLoss))
                        Text(Money.percent(summary.returnPercent))
                            .font(.system(size: 21, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.tone(summary.profitLoss))
                    }
                    Text("Annualised \(Money.percent(summary.annualisedReturn))")
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(Theme.inkDim)
                }
                .padding(.top, 14)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 14) {
                RangeChips(value: $range)
                SparklineView(
                    points: Spark.series(seed: 7.3, count: 60, trendingUp: summary.profitLoss >= 0),
                    color: Theme.tone(summary.profitLoss)
                )
                .frame(width: 360, height: 96)
            }
        }
    }

    // MARK: Columns

    private var columns: some View {
        HStack(alignment: .top, spacing: 22) {
            AllocationCardView(slices: viewModel.allocations(for: holdings), currency: currency)
                .frame(width: 408)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Holdings").font(.system(size: 21, weight: .semibold)).foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(holdings.count) positions").font(.system(size: 14, design: .monospaced)).foregroundStyle(Theme.inkDim)
                }
                .padding(.horizontal, 4).padding(.bottom, 14)

                List {
                    ForEach(sortedHoldings) { holding in
                        HoldingRowView(holding: holding, currency: currency)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedHolding = holding }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Haptics.impact(.rigid)
                                    viewModel.delete(holding, in: context)
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .refreshable { await viewModel.refreshPrices(for: holdings) }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 54))
                .foregroundStyle(Theme.inkFaint)
            Text("No holdings yet")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Add your first position to see live value, allocation and P&L.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.inkDim)
                .multilineTextAlignment(.center)
            Button { showAddSheet = true } label: {
                Text("Add holding")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.onButton)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(Capsule().fill(Theme.gainButton))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Header icon button

struct HeaderButton: View {
    let systemImage: String
    var isBusy: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isBusy {
                    ProgressView().controlSize(.small).tint(Theme.inkSoft)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .frame(width: 44, height: 44)
            .glassPill()
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }
}

// MARK: - Range chips

struct RangeChips: View {
    @Binding var value: String
    private let ranges = ["1D", "1W", "1M", "1Y", "ALL"]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ranges, id: \.self) { r in
                Button { value = r } label: {
                    Text(r)
                        .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(value == r ? Theme.ink : Theme.inkDim)
                        .padding(.horizontal, 15).padding(.vertical, 7)
                        .background(
                            Capsule().fill(Theme.line.opacity(value == r ? 0.14 : 0))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .glassPill()
    }
}

#Preview(traits: .landscapeLeft) {
    ZStack {
        VaultBackground(performance: 0.5)
        PortfolioView(viewModel: PortfolioViewModel(), onOpenAI: {}, onOpenSettings: {})
            .environment(AppSettings())
    }
    .modelContainer(MockData.previewContainer())
}
