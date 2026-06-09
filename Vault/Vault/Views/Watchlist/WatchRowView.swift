//
//  WatchRowView.swift
//  Vault
//
//  A watched ticker: real sparkline, latest price and range change.
//

import SwiftUI

struct WatchRowView: View {
    let item: WatchItem
    var currency: DisplayCurrency = .gbp

    @State private var closes: [Double] = []

    private var hasData: Bool { closes.count > 1 }
    private var last: Double? { closes.last }
    private var change: Double? {
        guard let first = closes.first, let last = closes.last, first != 0 else { return nil }
        return (last - first) / first * 100
    }
    private var up: Bool { (change ?? 0) >= 0 }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.ticker).font(.headline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(item.companyName).font(.subheadline).foregroundStyle(Theme.inkDim).lineLimit(1)
            }

            Spacer(minLength: 8)

            SparklineView(
                points: hasData ? closes : Spark.series(seed: Double(abs(item.ticker.hashValue % 997)), count: 20, trendingUp: up),
                color: up ? Theme.gain : Theme.loss
            )
            .opacity(hasData ? 1 : 0.5)
            .frame(width: 62, height: 30)

            VStack(alignment: .trailing, spacing: 5) {
                Text(last.map { Money.currency($0, currency: currency) } ?? "—")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                if let change {
                    ChangePill(text: Money.percent(change), color: up ? Theme.gain : Theme.loss)
                } else {
                    ChangePill(text: "—", color: Theme.inkFaint)
                }
            }
            .frame(minWidth: 76, alignment: .trailing)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .task(id: item.ticker) { await load() }
    }

    private func load() async {
        guard let history = try? await PriceHistoryService.shared.history(for: item.ticker, range: .month) else { return }
        let points = history.map(\.close)
        guard points.count > 1 else { return }
        await MainActor.run { closes = points }
    }
}

#Preview {
    ZStack {
        VaultBackground(performance: 0.3)
        VStack(spacing: 12) {
            WatchRowView(item: MockData.watchlist[0])
            WatchRowView(item: MockData.watchlist[1])
        }
        .padding(40)
    }
}
