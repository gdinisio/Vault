//
//  PaperPositionRowView.swift
//  Vault
//
//  An open paper position card — same visual style as a portfolio holding.
//

import SwiftUI

struct PaperPositionRowView: View {
    let position: PaperPosition
    var currency: DisplayCurrency = .gbp

    private var up: Bool { position.profitLoss >= 0 }

    var body: some View {
        HStack(spacing: 15) {
            TickerMark(ticker: position.ticker, sector: position.sector, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(position.ticker)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(Int(position.shares)) sh @ \(Money.currency(position.averageCost, currency: currency))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.inkDim)
            }
            Spacer()
            SparklineView(
                points: Spark.series(seed: position.averageCost + 3, count: 20, trendingUp: up),
                color: up ? Theme.gain : Theme.loss
            )
            .frame(width: 84, height: 30)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Money.currency(position.currentValue, currency: currency))
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                Text("\(Money.percent(position.returnPercent)) · \(Money.signed(position.profitLoss, currency: currency))")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(up ? Theme.gain : Theme.loss)
            }
            .frame(width: 150, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 22)
    }
}

#Preview {
    ZStack {
        VaultBackground(performance: 0.3)
        VStack(spacing: 12) {
            PaperPositionRowView(position: MockData.positions[0])
            PaperPositionRowView(position: MockData.positions[1])
        }
        .padding(40)
    }
}
