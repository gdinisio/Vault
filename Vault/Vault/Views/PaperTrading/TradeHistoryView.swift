//
//  TradeHistoryView.swift
//  Vault
//
//  Scrollable trade-history timeline shown beside the open positions.
//

import SwiftUI

struct TradeHistoryView: View {
    let trades: [PaperTrade]
    var currency: DisplayCurrency = .gbp

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Trade history")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.bottom, 18)

            if trades.isEmpty {
                Text("No trades yet. Place a paper order to get started.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkDim)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(trades.enumerated()), id: \.element.id) { index, trade in
                            TradeRow(trade: trade, currency: currency, isLast: index == trades.count - 1)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 24)
        .frame(maxHeight: .infinity, alignment: .top)
        .glassCard()
    }
}

private struct TradeRow: View {
    let trade: PaperTrade
    var currency: DisplayCurrency
    let isLast: Bool

    private var buy: Bool { trade.type == .buy }
    private var tint: Color { buy ? Theme.gain : Theme.loss }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // timeline marker + connector
            VStack(spacing: 0) {
                Circle()
                    .fill(tint)
                    .frame(width: 13, height: 13)
                    .shadow(color: tint.opacity(0.5), radius: 5)
                    .padding(.top, 4)
                if !isLast {
                    Rectangle()
                        .fill(LinearGradient(colors: [Theme.line.opacity(0.16), Theme.line.opacity(0.04)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 2)
                        .padding(.vertical, 4)
                }
            }
            .frame(width: 14)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 9) {
                    Text(trade.type.rawValue)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(tint)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(tint.opacity(0.18)))
                    Text(trade.ticker)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("\(Int(trade.shares)) sh @ \(Money.currency(trade.price, currency: currency))")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Theme.inkDim)
                }
                Text(trade.timestamp.formatted(.dateTime.day().month(.abbreviated).year().hour().minute()))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.inkDim)
            }
            .padding(.bottom, 20)

            Spacer(minLength: 8)

            Text("\(buy ? "−" : "+")\(Money.currency(trade.shares * trade.price, currency: currency))")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(buy ? Theme.inkSoft : Theme.gain)
                .padding(.top, 2)
        }
    }
}

#Preview {
    ZStack {
        VaultBackground(performance: 0.3)
        TradeHistoryView(trades: MockData.trades)
            .frame(width: 396, height: 560)
            .padding(40)
    }
}
