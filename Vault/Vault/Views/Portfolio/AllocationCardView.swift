//
//  AllocationCardView.swift
//  Vault
//
//  Glass card with a Swift Charts donut showing allocation by holding, plus a
//  legend list. Tapping/selecting a slice highlights it and updates the centre.
//

import SwiftUI
import Charts

struct AllocationCardView: View {
    let slices: [AllocationSlice]
    var currency: DisplayCurrency = .gbp

    @State private var selected: String?

    private var total: Double { slices.reduce(0) { $0 + $1.value } }
    private var selectedSlice: AllocationSlice? { slices.first { $0.ticker == selected } }

    private var centreValue: String {
        if let s = selectedSlice { return "\(Int((s.fraction * 100).rounded()))%" }
        return "100%"
    }
    private var centreLabel: String { selectedSlice?.ticker ?? "Total" }
    private var centreSub: String {
        if let s = selectedSlice, s.lotCount > 1 {
            return "\(Money.currency0(s.value, currency: currency)) · \(s.lotCount) lots"
        }
        return Money.currency0(selectedSlice?.value ?? total, currency: currency)
    }
    private var centreColor: Color {
        selectedSlice.map { Theme.sectorColor($0.sector) } ?? Theme.ink
    }

    /// Subtitle under the title: shows sector + lot count when relevant.
    private var subtitle: String {
        if let s = selectedSlice {
            if s.lotCount > 1 { return "\(s.sector) · \(s.lotCount) lots" }
            return s.sector
        }
        let positions = slices.count
        let lots = slices.reduce(0) { $0 + $1.lotCount }
        if lots > positions {
            return "\(positions) positions · \(lots) lots — tap a slice"
        }
        return "By position — tap a slice"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Allocation")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.inkDim)
                .contentTransition(.opacity)
                .padding(.bottom, 14)

            donut
                .frame(height: 224)
                .padding(.vertical, 6)

            legend
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentCard()
        .sensoryFeedback(.selection, trigger: selected)
    }

    private var donut: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Value", slice.value),
                innerRadius: .ratio(0.72),
                outerRadius: .ratio(selected == slice.ticker ? 1.0 : 0.9),
                angularInset: 2.5
            )
            .cornerRadius(6)
            .foregroundStyle(Theme.sectorColor(slice.sector))
            .opacity(selected == nil || selected == slice.ticker ? 1 : 0.3)
        }
        .chartLegend(.hidden)
        .chartBackground { _ in
            VStack(spacing: 3) {
                Text(centreValue)
                    .font(.largeTitle.weight(.semibold).monospacedDigit())
                    .foregroundStyle(centreColor)
                    .contentTransition(.numericText())
                Text(centreLabel)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                Text(centreSub)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.inkDim)
            }
            .animation(.easeInOut(duration: 0.2), value: selected)
        }
        .chartOverlay { _ in
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture().onEnded { value in
                            selectSlice(at: value.location, in: geo.size)
                        }
                    )
            }
        }
        .animation(.bouncy(duration: 0.35), value: selected)
    }

    /// Reliable hit-testing for the donut: map a tap's angle to its slice.
    /// `chartAngleSelection` misses taps near the angular insets / rounded
    /// slice edges; this covers the whole ring (and clears on a centre tap).
    private func selectSlice(at point: CGPoint, in size: CGSize) {
        guard total > 0 else { return }
        let dx = point.x - size.width / 2
        let dy = point.y - size.height / 2
        let radius = hypot(dx, dy)
        let maxR = min(size.width, size.height) / 2
        // Tap inside the centre hole clears the selection.
        if radius < maxR * 0.6 {
            if selected != nil { withAnimation(.bouncy(duration: 0.35)) { selected = nil } }
            return
        }
        guard radius <= maxR * 1.1 else { return }
        // Angle clockwise from 12 o'clock (SectorMark's start), 0..<2π.
        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }
        let target = angle / (2 * .pi) * total
        if let ticker = sliceFor(value: target)?.ticker {
            withAnimation(.bouncy(duration: 0.35)) {
                selected = (selected == ticker) ? nil : ticker
            }
        }
    }

    private var legend: some View {
        VStack(spacing: 2) {
            ForEach(slices) { slice in
                Button {
                    withAnimation(.bouncy(duration: 0.35)) {
                        selected = selected == slice.ticker ? nil : slice.ticker
                    }
                } label: {
                    HStack(spacing: 11) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Theme.sectorColor(slice.sector))
                            .frame(width: 11, height: 11)
                            .scaleEffect(selected == slice.ticker ? 1.25 : 1)
                        HStack(spacing: 5) {
                            Text(slice.ticker)
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(Theme.ink)
                            if slice.lotCount > 1 {
                                Text("×\(slice.lotCount)")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Theme.inkDim)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(
                                        Capsule().fill(Theme.line.opacity(0.10))
                                    )
                                    .accessibilityLabel("\(slice.lotCount) lots")
                            }
                        }
                        .frame(width: 84, alignment: .leading)
                        Text(Money.currency0(slice.value, currency: currency))
                            .font(.footnote)
                            .foregroundStyle(Theme.inkDim)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(format: "%.1f%%", slice.fraction * 100))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(selected == slice.ticker ? centreColorFor(slice) : Theme.ink)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selected == slice.ticker ? Theme.surfaceSelected : .clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func centreColorFor(_ slice: AllocationSlice) -> Color { Theme.sectorColor(slice.sector) }

    /// Map a value along the donut's angular axis to its slice (cumulative).
    private func sliceFor(value: Double) -> AllocationSlice? {
        var cumulative = 0.0
        for slice in slices {
            cumulative += slice.value
            if value <= cumulative { return slice }
        }
        return slices.last
    }
}

#Preview {
    let holdings = MockData.holdings
    let vm = PortfolioViewModel()
    return ZStack {
        VaultBackground(performance: 0.5)
        AllocationCardView(slices: vm.allocations(for: holdings))
            .frame(width: 408, height: 560)
            .padding(40)
    }
}
