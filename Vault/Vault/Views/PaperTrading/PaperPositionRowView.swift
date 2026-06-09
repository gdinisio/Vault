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
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(position.ticker)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(Int(position.shares)) sh @ \(Money.currency(position.averageCost, currency: currency))")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(Theme.inkDim)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            TickerSparkline(symbol: position.ticker, fallbackUp: up,
                            tint: up ? Theme.gain : Theme.loss)
                .frame(width: 62, height: 30)

            VStack(alignment: .trailing, spacing: 5) {
                Text(Money.currency(position.currentValue, currency: currency))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                ChangePill(text: Money.percent(position.returnPercent),
                           color: up ? Theme.gain : Theme.loss)
            }
            .frame(minWidth: 76, alignment: .trailing)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
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
