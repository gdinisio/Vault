//
//  PaperPositionRowView.swift
//  Vault
//
//  An open paper position card — compact to fit the split-view detail column.
//

import SwiftUI

struct PaperPositionRowView: View {
    let position: PaperPosition
    var currency: DisplayCurrency = .gbp

    private var up: Bool { position.profitLoss >= 0 }

    var body: some View {
        HStack(spacing: 12) {
            TickerMark(ticker: position.ticker, sector: position.sector, size: 40)

            VStack(alignment: .leading, spacing: 1) {
                Text(position.ticker)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(Int(position.shares)) sh @ \(Money.currency(position.averageCost, currency: currency))")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(Theme.inkDim)
                    .lineLimit(1)
            }
            .frame(minWidth: 60, maxWidth: 120, alignment: .leading)

            TickerSparkline(symbol: position.ticker, fallbackUp: up)
                .frame(maxWidth: .infinity)
                .frame(height: 28)

            VStack(alignment: .trailing, spacing: 1) {
                Text(Money.currency(position.currentValue, currency: currency))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 4) {
                    Text(Money.percent(position.returnPercent))
                    Text(Money.signed(position.profitLoss, currency: currency))
                }
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(up ? Theme.gain : Theme.loss)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }
            .frame(minWidth: 70, maxWidth: 110, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentCard(cornerRadius: 18)
    }
}

#Preview {
    ZStack {
        VaultBackground(performance: 0.3)
        VStack(spacing: 10) {
            PaperPositionRowView(position: MockData.positions[0])
            PaperPositionRowView(position: MockData.positions[1])
        }
        .padding(40)
    }
}
