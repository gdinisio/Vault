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
        HStack(spacing: 12) {
            TickerMark(ticker: item.ticker, sector: item.sector, size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.ticker).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(item.companyName).font(.caption2).foregroundStyle(Theme.inkDim).lineLimit(1)
            }
            .frame(minWidth: 60, maxWidth: 120, alignment: .leading)

            SparklineView(
                points: hasData ? closes : Spark.series(seed: Double(abs(item.ticker.hashValue % 997)), count: 20, trendingUp: up),
                color: up ? Theme.gain : Theme.loss
            )
            .opacity(hasData ? 1 : 0.5)
            .frame(maxWidth: .infinity)
            .frame(height: 28)

            VStack(alignment: .trailing, spacing: 1) {
                Text(last.map { Money.currency($0, currency: currency) } ?? "—")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(change.map { "\(Money.percent($0)) · 1M" } ?? " ")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(up ? Theme.gain : Theme.loss)
                    .lineLimit(1).minimumScaleFactor(0.75)
            }
            .frame(minWidth: 70, maxWidth: 110, alignment: .trailing)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .contentCard(cornerRadius: 18)
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
