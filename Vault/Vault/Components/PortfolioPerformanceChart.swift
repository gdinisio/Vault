//
//  PortfolioPerformanceChart.swift
//  Vault
//
//  The hero chart above the holdings list: real portfolio value over time with
//  a range selector (1D/1W/1M/3M/1Y/ALL) and drag-to-scrub. Falls back to a
//  cosmetic line while loading or if history is unavailable.
//

import SwiftUI
import Charts

struct PortfolioPerformanceChart: View {
    let holdings: [Holding]
    var currency: DisplayCurrency = .gbp
    var viewModel: PortfolioViewModel
    var fallbackUp: Bool = true

    @State private var range: ChartRange = .month
    @State private var points: [PricePoint] = []
    @State private var loading = true
    @State private var selectedDate: Date?

    private var hasReal: Bool { points.count > 1 }
    private var up: Bool {
        if let first = points.first?.close, let last = points.last?.close { return last >= first }
        return fallbackUp
    }
    private var lineColor: Color { up ? Theme.gain : Theme.loss }

    private var selectedPoint: PricePoint? {
        guard let selectedDate, hasReal else { return nil }
        return points.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    private var rangeChange: (abs: Double, pct: Double)? {
        guard let first = points.first?.close, let last = points.last?.close, first != 0 else { return nil }
        return (last - first, (last - first) / first * 100)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            chips
            chartArea
                .frame(height: 92)
                .overlay(alignment: .topLeading) { caption }
        }
        .task(id: "\(range.rawValue)-\(holdings.count)") { await load() }
    }

    // MARK: Caption (scrub value / range change)

    @ViewBuilder
    private var caption: some View {
        if let point = selectedPoint {
            VStack(alignment: .leading, spacing: 1) {
                Text(Money.currency(point.close, currency: currency))
                    .font(.system(size: 15, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.ink)
                Text(point.date.formatted(date: .abbreviated, time: range.isIntraday ? .shortened : .omitted))
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.inkDim)
            }
        } else if let change = rangeChange {
            HStack(spacing: 6) {
                Text("\(Money.signed(change.abs, currency: currency)) · \(Money.percent(change.pct))")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(lineColor)
                Text(range.rawValue).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.inkDim)
            }
        }
    }

    // MARK: Range chips

    private var chips: some View {
        Picker("Range", selection: $range) {
            ForEach(ChartRange.allCases) { r in
                Text(r.rawValue).tag(r)
            }
        }
        .pickerStyle(.segmented)
        .sensoryFeedback(.selection, trigger: range)
    }

    // MARK: Chart

    @ViewBuilder
    private var chartArea: some View {
        if hasReal {
            chart
        } else {
            // cosmetic placeholder while loading / when unavailable
            SparklineView(points: Spark.series(seed: 7.3, count: 60, trendingUp: fallbackUp),
                          color: (fallbackUp ? Theme.gain : Theme.loss).opacity(loading ? 0.4 : 0.6))
        }
    }

    private var chart: some View {
        let minV = points.map(\.close).min() ?? 0
        let maxV = points.map(\.close).max() ?? 1
        let pad = (maxV - minV) * 0.12

        return Chart {
            ForEach(points) { point in
                AreaMark(x: .value("Date", point.date),
                         yStart: .value("Min", max(0, minV - pad)),
                         yEnd: .value("Value", point.close))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [lineColor.opacity(0.30), lineColor.opacity(0)],
                                                    startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Date", point.date), y: .value("Value", point.close))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .foregroundStyle(lineColor)
            }
            if let sel = selectedPoint {
                RuleMark(x: .value("Date", sel.date))
                    .foregroundStyle(Theme.inkDim.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                PointMark(x: .value("Date", sel.date), y: .value("Value", sel.close))
                    .foregroundStyle(lineColor).symbolSize(70)
            }
        }
        .chartYScale(domain: max(0, minV - pad)...(maxV + pad))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartXSelection(value: $selectedDate)
        .animation(.easeInOut(duration: 0.35), value: points)
    }

    // MARK: Load

    private func load() async {
        loading = true
        selectedDate = nil
        let series = await viewModel.performanceSeries(for: holdings, range: range)
        points = series
        loading = false
    }
}
