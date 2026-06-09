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

    @State private var showAddSheet = false

    private var sortedHoldings: [Holding] {
        holdings.sorted { $0.currentValue > $1.currentValue }
    }

    private var summary: PortfolioSummary { viewModel.summary(for: holdings) }
    private var currency: DisplayCurrency {
        _ = settings.fxToken   // re-render when live FX rates update
        return settings.displayCurrency
    }

    var body: some View {
        GeometryReader { geo in
            let portrait = geo.size.height > geo.size.width
            if holdings.isEmpty {
                emptyState
                    .vaultPagePadding()
            } else {
                // The whole page scrolls in both orientations — inner List
                // sizes to its rows so nothing is clipped at the bottom and the
                // page owns scrolling end-to-end.
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        heroBand(portrait: portrait)
                            .padding(.top, portrait ? 6 : 10)
                            .padding(.bottom, portrait ? 16 : 22)
                        content(portrait: portrait)
                    }
                    .vaultPagePadding()
                }
                .scrollIndicators(.hidden)
                .scrollEdgeEffectStyle(.soft, for: .top)
                .refreshable { await viewModel.refreshPrices(for: holdings) }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Portfolio")
        .toolbar { toolbarContent }
        .toast($viewModel.toast)
        .sheet(isPresented: $showAddSheet) {
            AddHoldingView(currency: currency) { holding in
                viewModel.add(holding, in: context)
                Task { await viewModel.refreshPrices(for: [holding]) }
            }
        }
        .task { await viewModel.refreshPrices(for: holdings) }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Leading: utility (refresh) — plain glass.
        ToolbarItem(placement: .topBarLeading) {
            Button {
                Task { await viewModel.refreshPrices(for: holdings) }
            } label: {
                if viewModel.isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .disabled(viewModel.isRefreshing)
        }
        // Trailing: primary tools (AI + Add).
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onOpenAI) {
                Image(systemName: "sparkles")
            }
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            Button { showAddSheet = true } label: {
                Image(systemName: "plus")
            }
        }
    }

    // MARK: Hero

    @ViewBuilder
    private func heroBand(portrait: Bool) -> some View {
        let figures = VStack(alignment: .leading, spacing: 0) {
            Text("Total portfolio value").vaultLabel().padding(.bottom, 8)
            Text(Money.currency(summary.currentValue, currency: currency))
                .font(.system(size: portrait ? 44 : 60, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            HStack(spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: summary.profitLoss >= 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.tone(summary.profitLoss))
                        .frame(width: 22, height: 22)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Theme.tone(summary.profitLoss).opacity(0.18)))
                    Text(Money.signed(summary.profitLoss, currency: currency))
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.tone(summary.profitLoss))
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text(Money.percent(summary.returnPercent))
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.tone(summary.profitLoss))
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Text("Ann. \(Money.percent(summary.annualisedReturn))")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Theme.inkDim)
                    .lineLimit(1)
            }
            .padding(.top, 10)
        }
        let chart = PortfolioPerformanceChart(
            holdings: holdings,
            currency: currency,
            viewModel: viewModel,
            fallbackUp: summary.profitLoss >= 0
        )

        if portrait {
            VStack(alignment: .leading, spacing: 18) {
                figures
                chart.frame(maxWidth: .infinity)
            }
        } else {
            HStack(alignment: .bottom) {
                figures
                Spacer()
                chart.frame(width: 380)
            }
        }
    }

    // MARK: Content (orientation-adaptive)

    /// Landscape: allocation + holdings side by side. Portrait: holdings first
    /// (so they're always visible), allocation below.
    @ViewBuilder
    private func content(portrait: Bool) -> some View {
        Group {
            if portrait {
                VStack(alignment: .leading, spacing: 22) {
                    holdingsColumn
                    AllocationCardView(slices: viewModel.allocations(for: holdings), currency: currency)
                        .frame(maxWidth: .infinity)
                }
            } else {
                HStack(alignment: .top, spacing: 22) {
                    AllocationCardView(slices: viewModel.allocations(for: holdings), currency: currency)
                        .frame(width: 408)
                    holdingsColumn
                        .frame(maxWidth: .infinity)
                }
            }
        }
        // Rebuild when the live FX rate lands so rows + allocation use it too.
        .id(settings.fxToken)
    }

    /// Approximate rendered height of one holding row (content + separator).
    private let holdingRowHeight: CGFloat = 68

    /// Holdings list sized to its rows so the outer ScrollView owns scrolling
    /// in both orientations — no clipping, no nested scroll-gesture fight.
    private var holdingsColumn: some View {
        let listHeight = CGFloat(holdings.count) * holdingRowHeight

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Holdings").font(.system(size: 21, weight: .semibold)).foregroundStyle(Theme.ink)
                Spacer()
                Text("\(holdings.count) positions").font(.system(size: 14, design: .monospaced)).foregroundStyle(Theme.inkDim)
            }
            .padding(.horizontal, 4).padding(.bottom, 14)

            List {
                ForEach(sortedHoldings) { holding in
                    NavigationLink(value: holding) {
                        HoldingRowView(holding: holding, currency: currency)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                    .listRowBackground(Color.clear)
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
            .scrollDisabled(true)
            .frame(height: listHeight)
        }
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
        PortfolioView(viewModel: PortfolioViewModel(), onOpenAI: {})
            .environment(AppSettings())
    }
    .modelContainer(MockData.previewContainer())
}
