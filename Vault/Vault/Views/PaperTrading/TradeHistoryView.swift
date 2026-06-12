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
    /// When false the rows lay out inline (no internal scroll / no greedy
    /// height) so a parent ScrollView can own the scrolling — used in portrait.
    var scrolls: Bool = true

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(trades.enumerated()), id: \.element.id) { index, trade in
                TradeRow(trade: trade, currency: currency)
                if index < trades.count - 1 {
                    Divider().overlay(Theme.line.opacity(0.08))
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Trade history")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .padding(.bottom, 18)

            if trades.isEmpty {
                Text("No trades yet. Place a paper order to get started.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkDim)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(maxHeight: scrolls ? .infinity : nil, alignment: .topLeading)
            } else if scrolls {
                ScrollView { rows }
                    .scrollIndicators(.hidden)
            } else {
                rows
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: scrolls ? .infinity : nil, alignment: .top)
        .contentCard()
    }
}

private struct TradeRow: View {
    let trade: PaperTrade
    var currency: DisplayCurrency

    private var buy: Bool { trade.type == .buy }
    private var tint: Color { buy ? Theme.gain : Theme.loss }

    var body: some View {
        HStack(spacing: 12) {
            Text(trade.type.rawValue)
                .font(.caption2.weight(.bold)).tracking(0.5)
                .foregroundStyle(tint)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(tint.opacity(0.16)))

            VStack(alignment: .leading, spacing: 2) {
                Text(trade.ticker)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(Int(trade.shares)) sh @ \(Money.currency(trade.price, currency: currency))")
                    .font(.caption)
                    .foregroundStyle(Theme.inkDim)
                Text("\(trade.timestamp.formatted(.dateTime.day().month(.abbreviated).hour().minute()))")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkFaint)
            }

            Spacer(minLength: 8)

            Text("\(buy ? "−" : "+")\(Money.currency(trade.shares * trade.price, currency: currency))")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(buy ? Theme.inkSoft : Theme.gain)
        }
        .padding(.vertical, 12)
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
