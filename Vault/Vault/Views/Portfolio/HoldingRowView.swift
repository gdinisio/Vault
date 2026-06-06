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
        HStack(spacing: 12) {
            TickerMark(ticker: holding.ticker, sector: holding.sector, size: 40)

            // Ticker + name
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(holding.ticker)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    if holding.isStale {
                        Image(systemName: "wifi.slash")
                            .font(.caption2)
                            .foregroundStyle(Theme.warn)
                    }
                }
                Text(holding.companyName)
                    .font(.caption2)
                    .foregroundStyle(Theme.inkDim)
                    .lineLimit(1)
            }
            .frame(minWidth: 60, maxWidth: 120, alignment: .leading)

            // Sparkline — fills remaining space
            TickerSparkline(symbol: holding.ticker, fallbackUp: up)
                .frame(maxWidth: .infinity)
                .frame(height: 28)

            // Value + P&L
            VStack(alignment: .trailing, spacing: 1) {
                Text(Money.currency(holding.currentValue, currency: currency))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 4) {
                    Text(Money.signed(holding.profitLoss, currency: currency))
                    Text(Money.percent(holding.returnPercent))
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
        VaultBackground(performance: 0.4)
        VStack(spacing: 10) {
            HoldingRowView(holding: MockData.holdings[0])
            HoldingRowView(holding: MockData.holdings[5])
        }
        .padding(40)
    }
}
