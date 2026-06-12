//
//  HoldingDetailView.swift
//  Vault
//
//  Detail sheet for a holding: full cost-basis breakdown including the impact
//  of FX charge and broker fee, plus current value, P&L and annualised return.
//

import SwiftUI
import SwiftData

struct HoldingDetailView: View {
    let holding: Holding
    var currency: DisplayCurrency = .gbp
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var showAnalysis = false
    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    private var up: Bool { holding.profitLoss >= 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                valueBlock
                PriceChartView(symbol: holding.ticker, sector: holding.sector, currency: currency)

                section("Cost basis breakdown", footnote: feeDragNote) {
                    detailRow("Shares", "\(Int(holding.shares))")
                    detailRow("Purchase price", Money.currency(holding.purchasePricePerShare, currency: currency))
                    detailRow("Shares × price", Money.currency(holding.shares * holding.purchasePricePerShare, currency: currency))
                    detailRow("FX charge", Money.currency(holding.fxCharge, currency: currency), tint: Theme.warn)
                    detailRow("Broker fee", Money.currency(holding.brokerFee, currency: currency), tint: Theme.warn)
                    Divider().overlay(Theme.inkFaint.opacity(0.4))
                    detailRow("Total cost basis", Money.currency(holding.costBasis, currency: currency), emphasised: true)
                }

                section("Performance") {
                    detailRow("Current price", Money.currency(holding.currentPrice, currency: currency))
                    detailRow("Current value", Money.currency(holding.currentValue, currency: currency))
                    detailRow("Profit / loss", Money.signed(holding.profitLoss, currency: currency), tint: up ? Theme.gain : Theme.loss)
                    detailRow("Return", Money.percent(holding.returnPercent), tint: up ? Theme.gain : Theme.loss)
                    detailRow("Annualised return", Money.percent(holding.annualisedReturn), tint: holding.annualisedReturn >= 0 ? Theme.gain : Theme.loss)
                    detailRow("Purchased", holding.purchaseDate.formatted(date: .abbreviated, time: .omitted))
                }

                NewsSection(symbol: holding.ticker)
            }
            .padding(28)
        }
        .background(Theme.bgDeep.opacity(0.001))
        .navigationTitle(holding.ticker)
        .navigationSubtitle(holding.companyName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Haptics.impact(.light); showAnalysis = true } label: {
                    Label("Analyse with AI", systemImage: "sparkles")
                }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { Haptics.impact(.light); showEdit = true } label: {
                        Label("Edit holding", systemImage: "pencil")
                    }
                    Button(role: .destructive) { Haptics.warning(); showDeleteConfirm = true } label: {
                        Label("Delete holding", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $showAnalysis) {
            StockAnalysisView(snapshot: StockSnapshot(holding: holding), currency: currency)
        }
        .sheet(isPresented: $showEdit) {
            EditHoldingView(holding: holding, displayCurrency: currency)
        }
        .confirmationDialog("Remove \(holding.ticker)?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete holding", role: .destructive) { deleteHolding() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \(holding.ticker) from your portfolio. This can't be undone.")
        }
    }

    private func deleteHolding() {
        context.delete(holding)
        try? context.save()
        Haptics.success()
        dismiss()
    }

    private var valueBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current value").vaultLabel()
            Text(Money.currency(holding.currentValue, currency: currency))
                .font(.system(size: 44, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.ink)
            Text("\(Money.signed(holding.profitLoss, currency: currency)) · \(Money.percent(holding.returnPercent))")
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundStyle(up ? Theme.gain : Theme.loss)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .contentCard()
    }

    /// Grouped-list footer text explaining the fee drag on entry.
    private var feeDragNote: String {
        let totalFees = holding.fxCharge + holding.brokerFee
        let dragPct = holding.costBasis > 0 ? totalFees / holding.costBasis * 100 : 0
        return "FX (\(Money.currency(holding.fxCharge, currency: currency))) and broker fees (\(Money.currency(holding.brokerFee, currency: currency))) added \(Money.currency(totalFees, currency: currency)) to your cost basis — a \(String(format: "%.2f", dragPct))% drag on entry."
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
    Color.black.sheet(isPresented: .constant(true)) {
        HoldingDetailView(holding: MockData.holdings[4])
    }
}
