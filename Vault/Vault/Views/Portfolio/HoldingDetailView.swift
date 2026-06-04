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
                header
                valueBlock
                PriceChartView(symbol: holding.ticker, sector: holding.sector, currency: currency)
                analyseButton

                section("Cost basis breakdown") {
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

                // Fee-drag note
                feeImpactNote

                editDeleteRow
            }
            .padding(28)
        }
        .background(Theme.bgDeep.opacity(0.001)) // ensure scroll fills
        .presentationBackground(.ultraThickMaterial)
        .presentationCornerRadius(Theme.sheetRadius)
        .presentationDetents([.large, .medium])
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

    private var editDeleteRow: some View {
        HStack(spacing: 12) {
            Button { Haptics.impact(.light); showEdit = true } label: {
                Label("Edit", systemImage: "pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.line.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.line.opacity(0.14), lineWidth: 0.5))
                    )
            }.buttonStyle(.plain)

            Button(role: .destructive) { Haptics.warning(); showDeleteConfirm = true } label: {
                Label("Delete", systemImage: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.loss)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.loss.opacity(0.14))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.loss.opacity(0.3), lineWidth: 0.5))
                    )
            }.buttonStyle(.plain)
        }
    }

    private func deleteHolding() {
        context.delete(holding)
        try? context.save()
        Haptics.success()
        dismiss()
    }

    private var analyseButton: some View {
        Button { showAnalysis = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").foregroundStyle(Theme.aiPurple)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Analyse with Claude")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text("News-driven read on \(holding.ticker) — hold, trim or add")
                        .font(.system(size: 12.5)).foregroundStyle(Theme.inkDim)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.inkDim)
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.aiPurple.opacity(0.14))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.aiPurple.opacity(0.3), lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack(spacing: 16) {
            TickerMark(ticker: holding.ticker, sector: holding.sector, size: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(holding.ticker)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(holding.companyName)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.inkDim)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Theme.line.opacity(0.08)))
            }
        }
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
        .glassCard()
    }

    private var feeImpactNote: some View {
        let totalFees = holding.fxCharge + holding.brokerFee
        let dragPct = holding.costBasis > 0 ? totalFees / holding.costBasis * 100 : 0
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle")
                .foregroundStyle(Theme.accent)
            Text("FX (\(Money.currency(holding.fxCharge, currency: currency))) and broker fees (\(Money.currency(holding.brokerFee, currency: currency))) added \(Money.currency(totalFees, currency: currency)) to your cost basis — a \(String(format: "%.2f", dragPct))% drag on entry.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.line.opacity(0.05))
        )
    }

    // MARK: Building blocks

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).vaultLabel()
            VStack(spacing: 12) { content() }
                .padding(20)
                .glassCard()
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
