//
//  PriceChartView.swift
//  Vault
//
//  Real historical price chart (Swift Charts) with a range selector and
//  interactive scrubbing. Prices are base-currency (USD) and shown in the
//  chosen display currency.
//

import SwiftUI
import Charts

struct PriceChartView: View {
    let symbol: String
    var sector: String = "Technology"
    var currency: DisplayCurrency = .gbp

    @State private var range: ChartRange = .month
    @State private var points: [PricePoint] = []
    @State private var isLoading = true
    @State private var failed = false
    @State private var selectedDate: Date?

    private var up: Bool {
        guard let first = points.first?.close, let last = points.last?.close else { return true }
        return last >= first
    }
    private var lineColor: Color { up ? Theme.gain : Theme.loss }

    private var selectedPoint: PricePoint? {
        guard let selectedDate, !points.isEmpty else { return nil }
        return points.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private var change: (abs: Double, pct: Double)? {
        guard let first = points.first?.close, let last = points.last?.close, first != 0 else { return nil }
        return (last - first, (last - first) / first * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow
            chartArea
                .frame(height: 200)
            RangePicker(range: $range)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .task(id: range) { await load() }
    }

    // MARK: Header

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Price").vaultLabel()
                if let point = selectedPoint {
                    Text(Money.currency(point.close, currency: currency))
                        .font(.system(size: 26, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                    Text(point.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 12.5, design: .monospaced)).foregroundStyle(Theme.inkDim)
                } else if let last = points.last {
                    Text(Money.currency(last.close, currency: currency))
                        .font(.system(size: 26, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                    if let change {
                        Text("\(Money.signed(change.abs, currency: currency)) · \(Money.percent(change.pct)) · \(range.rawValue)")
                            .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(lineColor)
                    }
                } else {
                    Text("—").font(.system(size: 26, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.inkDim)
                }
            }
            Spacer()
        }
    }

    // MARK: Chart

    @ViewBuilder
    private var chartArea: some View {
        if isLoading {
            ProgressView().controlSize(.regular).tint(Theme.inkDim)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if failed || points.count < 2 {
            VStack(spacing: 8) {
                Image(systemName: "chart.xyaxis.line").font(.system(size: 30)).foregroundStyle(Theme.inkFaint)
                Text("No price history for \(symbol)").font(.system(size: 13)).foregroundStyle(Theme.inkDim)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            chart
        }
    }

    private var chart: some View {
        let minClose = points.map(\.close).min() ?? 0
        let maxClose = points.map(\.close).max() ?? 1
        let pad = (maxClose - minClose) * 0.08

        return Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Min", max(0, minClose - pad)),
                    yEnd: .value("Price", point.close)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(LinearGradient(colors: [lineColor.opacity(0.28), lineColor.opacity(0)],
                                                startPoint: .top, endPoint: .bottom))

                LineMark(x: .value("Date", point.date), y: .value("Price", point.close))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .foregroundStyle(lineColor)
            }

            if let sel = selectedPoint {
                RuleMark(x: .value("Date", sel.date))
                    .foregroundStyle(Theme.inkDim.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                PointMark(x: .value("Date", sel.date), y: .value("Price", sel.close))
                    .foregroundStyle(lineColor)
                    .symbolSize(90)
            }
        }
        .chartYScale(domain: max(0, minClose - pad)...(maxClose + pad))
        .chartXAxis {
            AxisMarks(preset: .aligned) { _ in
                AxisGridLine().foregroundStyle(Theme.line.opacity(0.06))
                AxisValueLabel(format: range.isIntraday ? .dateTime.hour() : .dateTime.month(.abbreviated).day())
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.inkDim)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine().foregroundStyle(Theme.line.opacity(0.06))
                AxisValueLabel {
                    if let usd = value.as(Double.self) {
                        Text(Money.currency0(usd, currency: currency))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Theme.inkDim)
                    }
                }
            }
        }
        .chartXSelection(value: $selectedDate)
        .animation(.easeInOut(duration: 0.35), value: points)
    }

    // MARK: Load

    private func load() async {
        isLoading = points.isEmpty
        failed = false
        selectedDate = nil
        do {
            let data = try await PriceHistoryService.shared.history(for: symbol, range: range)
            await MainActor.run {
                points = data
                isLoading = false
            }
        } catch {
            await MainActor.run {
                failed = true
                isLoading = false
            }
        }
    }
}

// MARK: - Range picker

private struct RangePicker: View {
    @Binding var range: ChartRange

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ChartRange.allCases) { r in
                Button {
                    range = r
                } label: {
                    Text(r.rawValue)
                        .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(range == r ? Theme.ink : Theme.inkDim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Theme.line.opacity(range == r ? 0.14 : 0)))
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: range == r)
            }
        }
        .padding(4)
        .glassPill()
    }
}

#Preview {
    ZStack {
        VaultBackground(performance: 0.4)
        PriceChartView(symbol: "AAPL", sector: "Technology")
            .frame(width: 520)
            .padding(40)
    }
}
