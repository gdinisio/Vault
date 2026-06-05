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
    @State private var selectedHolding: Holding?

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
                    .padding(.horizontal, portrait ? 28 : 52)
            } else if portrait {
                // Portrait: whole page scrolls; holdings list sizes to its rows.
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        heroBand(portrait: true)
                            .padding(.top, 6)
                            .padding(.bottom, 16)
                        content(portrait: true)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            } else {
                // Landscape: fixed two-column layout, columns fill the height.
                VStack(alignment: .leading, spacing: 0) {
                    heroBand(portrait: false)
                        .padding(.top, 10)
                        .padding(.bottom, 22)
                    content(portrait: false)
                }
                .padding(.horizontal, 52)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
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
        // Trailing: primary tools (AI + Add) — prominent, each its own capsule.
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onOpenAI) {
                Image(systemName: "sparkles")
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.aiPurpleButton)
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            Button { showAddSheet = true } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.gainButton)
        }
    }

    // MARK: Hero

    @ViewBuilder
    private func heroBand(portrait: Bool) -> some View {
        let figures = VStack(alignment: .leading, spacing: 0) {
            Text("Total portfolio value").vaultLabel().padding(.bottom, 10)
            Text(Money.currency(summary.currentValue, currency: currency))
                .font(.system(size: portrait ? 56 : 76, weight: .semibold, design: .monospaced))
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
                    holdingsColumn(portrait: true)
                    AllocationCardView(slices: viewModel.allocations(for: holdings), currency: currency)
                        .frame(maxWidth: .infinity)
                }
            } else {
                HStack(alignment: .top, spacing: 22) {
                    AllocationCardView(slices: viewModel.allocations(for: holdings), currency: currency)
                        .frame(width: 408)
                    holdingsColumn(portrait: false)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: .infinity)
            }
        }
        // Rebuild when the live FX rate lands so rows + allocation use it too.
        .id(settings.fxToken)
    }

    /// Approximate rendered height of one holding row (content + list insets).
    private let holdingRowHeight: CGFloat = 90

    private func holdingsColumn(portrait: Bool) -> some View {
        // Portrait: the list is exactly as tall as its rows, up to 5; beyond
        // that it caps and scrolls internally. Landscape: fills the column.
        let visibleRows = min(holdings.count, 5)
        let portraitHeight = CGFloat(visibleRows) * holdingRowHeight

        return VStack(alignment: .leading, spacing: 0) {
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
            .frame(maxHeight: portrait ? portraitHeight : .infinity)
            .scrollDisabled(portrait && holdings.count <= 5)
            .refreshable { await viewModel.refreshPrices(for: holdings) }
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
