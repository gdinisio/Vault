//
//  PaperPositionDetailView.swift
//  Vault
//
//  Detail sheet for an open paper position — value, live price chart, AI
//  analysis and a breakdown of cost basis and P&L. Mirrors HoldingDetailView
//  so paper positions feel just like real holdings.
//

import SwiftUI

struct PaperPositionDetailView: View {
    let position: PaperPosition
    var currency: DisplayCurrency = .gbp
    /// Asks the parent to open the Sell sheet (the parent dismisses this first,
    /// so we never read a position that selling may have deleted).
    var onSell: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var showAnalysis = false

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
                header
                valueBlock
                PriceChartView(symbol: position.ticker, sector: position.sector, currency: currency)
                analyseButton

                section("Position") {
                    detailRow("Shares", "\(Int(position.shares))")
                    detailRow("Average cost", Money.currency(position.averageCost, currency: currency))
                    detailRow("Cost basis", Money.currency(position.costBasis, currency: currency))
                    Divider().overlay(Theme.inkFaint.opacity(0.4))
                    detailRow("Current price", Money.currency(position.currentPrice, currency: currency))
                    detailRow("Current value", Money.currency(position.currentValue, currency: currency), emphasised: true)
                }

                section("Performance") {
                    detailRow("Profit / loss", Money.signed(position.profitLoss, currency: currency), tint: up ? Theme.gain : Theme.loss)
                    detailRow("Return", Money.percent(position.returnPercent), tint: up ? Theme.gain : Theme.loss)
                    detailRow("Last updated", position.lastUpdated.formatted(date: .abbreviated, time: .shortened))
                }

                sellButton
            }
            .padding(28)
        }
        .background(Theme.bgDeep.opacity(0.001))
        .presentationBackground(.ultraThickMaterial)
        .presentationCornerRadius(Theme.sheetRadius)
        .presentationDetents([.large, .medium])
        .sheet(isPresented: $showAnalysis) {
            StockAnalysisView(snapshot: snapshot, currency: currency)
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            TickerMark(ticker: position.ticker, sector: position.sector, size: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(position.ticker)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(position.companyName)
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
            }.buttonStyle(.plain)
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
        .glassCard()
    }

    private var analyseButton: some View {
        Button { Haptics.impact(.light); showAnalysis = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").foregroundStyle(Theme.aiPurple)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Analyse with AI")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text("News-driven read on \(position.ticker) — hold, trim or add")
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

    private var sellButton: some View {
        Button { Haptics.impact(.rigid); onSell() } label: {
            Label("Sell \(position.ticker)", systemImage: "arrow.down.right")
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
        PaperPositionDetailView(position: MockData.positions[0])
    }
}
