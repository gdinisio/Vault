//
//  HoldingRowView.swift
//  Vault
//
//  A single holding card: ticker mark, name, sparkline, value and P&L.
//  Compact enough to sit in the detail column of the split-view sidebar.
//

import SwiftUI

struct HoldingRowView: View {
    let holding: Holding
    var currency: DisplayCurrency = .gbp

    private var up: Bool { holding.profitLoss >= 0 }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(holding.ticker)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    if holding.isStale {
                        Image(systemName: "wifi.slash")
                            .font(.caption2)
                            .foregroundStyle(Theme.warn)
                    }
                }
                Text(holding.companyName)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkDim)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            TickerSparkline(symbol: holding.ticker, fallbackUp: up,
                            tint: up ? Theme.gain : Theme.loss)
                .frame(width: 62, height: 30)

            VStack(alignment: .trailing, spacing: 5) {
                Text(Money.currency(holding.currentValue, currency: currency))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                ChangePill(text: Money.percent(holding.returnPercent),
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
        VaultBackground(performance: 0.4)
        VStack(spacing: 10) {
            HoldingRowView(holding: MockData.holdings[0])
            HoldingRowView(holding: MockData.holdings[5])
        }
        .padding(40)
    }
}
