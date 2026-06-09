//
//  TickerSparkline.swift
//  Vault
//
//  A small sparkline backed by REAL price history (cached), used in holding and
//  paper-position rows. Shows a cosmetic placeholder while loading or if the
//  fetch fails, so the list never blocks.
//

import SwiftUI

struct TickerSparkline: View {
    let symbol: String
    /// Fallback trend direction used before real data loads.
    var fallbackUp: Bool
    var range: ChartRange = .month
    /// Optional fixed line colour. When set (e.g. a position's P&L colour), the
    /// sparkline keeps the real price shape but uses this colour so it stays
    /// consistent with the row's P&L pill instead of the period's own trend.
    var tint: Color? = nil

    @State private var closes: [Double] = []

    private var hasReal: Bool { closes.count > 1 }
    private var up: Bool {
        if let first = closes.first, let last = closes.last { return last >= first }
        return fallbackUp
    }
    private var lineColor: Color { tint ?? (up ? Theme.gain : Theme.loss) }

    var body: some View {
        SparklineView(
            points: hasReal
                ? closes
                : Spark.series(seed: Double(abs(symbol.hashValue % 997)), count: 22, trendingUp: fallbackUp),
            color: lineColor
        )
        .opacity(hasReal ? 1 : 0.55)
        .animation(.easeInOut(duration: 0.3), value: hasReal)
        .task(id: symbol) { await load() }
    }

    private func load() async {
        guard let history = try? await PriceHistoryService.shared.history(for: symbol, range: range) else { return }
        let points = history.map(\.close)
        guard points.count > 1 else { return }
        await MainActor.run { closes = points }
    }
}
