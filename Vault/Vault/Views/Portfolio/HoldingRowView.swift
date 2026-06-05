//
//  HoldingRowView.swift
//  Vault
//
//  A single holding as a glass-surface card: ticker mark, name, shares,
//  sparkline, value and P&L.
//

import SwiftUI

struct HoldingRowView: View {
    let holding: Holding
    var currency: DisplayCurrency = .gbp

    private var up: Bool { holding.profitLoss >= 0 }

    var body: some View {
        HStack(spacing: 16) {
            TickerMark(ticker: holding.ticker, sector: holding.sector, size: 48)

            // ticker + name
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(holding.ticker)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    if holding.isStale {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.warn)
                            .help("Showing last-known price")
                    }
                }
                Text(holding.companyName)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.inkDim)
                    .lineLimit(1)
            }
            .frame(width: 168, alignment: .leading)

            // shares / cost
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(holding.shares)) sh")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Theme.inkSoft)
                Text("@ \(Money.currency(holding.purchasePricePerShare, currency: currency))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.inkDim)
            }
            .frame(width: 96, alignment: .leading)

            // real price sparkline
            TickerSparkline(symbol: holding.ticker, fallbackUp: up)
                .frame(maxWidth: .infinity)
                .frame(height: 34)

            // value + P&L
            VStack(alignment: .trailing, spacing: 2) {
                Text(Money.currency(holding.currentValue, currency: currency))
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                Text("\(Money.signed(holding.profitLoss, currency: currency)) · \(Money.percent(holding.returnPercent))")
                    .font(.system(size: 13.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(up ? Theme.gain : Theme.loss)
            }
            .frame(width: 168, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .contentCard(cornerRadius: 22)
    }
}

#Preview {
    ZStack {
        VaultBackground(performance: 0.4)
        VStack(spacing: 12) {
            HoldingRowView(holding: MockData.holdings[0])
            HoldingRowView(holding: MockData.holdings[5])
        }
        .padding(40)
    }
}
