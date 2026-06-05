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

    private var centreValue: String {
        if let selected, let slice = slices.first(where: { $0.ticker == selected }) {
            return "\(Int((slice.fraction * 100).rounded()))%"
        }
        return "100%"
    }

    private var centreLabel: String { selected ?? "Total" }

    private var centreColor: Color {
        if let selected, let slice = slices.first(where: { $0.ticker == selected }) {
            return Theme.sectorColor(slice.sector)
        }
        return Theme.ink
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Allocation")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("By position")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkDim)
                .padding(.bottom, 14)

            donut
                .frame(height: 224)
                .padding(.vertical, 6)

            legend
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentCard()
    }

    private var donut: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Value", slice.value),
                innerRadius: .ratio(0.72),
                angularInset: 2.5
            )
            .cornerRadius(6)
            .foregroundStyle(Theme.sectorColor(slice.sector))
            .opacity(selected == nil || selected == slice.ticker ? 1 : 0.32)
        }
        .chartLegend(.hidden)
        .chartBackground { _ in
            VStack(spacing: 4) {
                Text(centreValue)
                    .font(.system(size: 34, weight: .semibold, design: .monospaced))
                    .foregroundStyle(centreColor)
                Text(centreLabel)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.inkDim)
            }
            .animation(.easeInOut(duration: 0.2), value: selected)
        }
    }

    private var legend: some View {
        VStack(spacing: 2) {
            ForEach(slices) { slice in
                HStack(spacing: 11) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Theme.sectorColor(slice.sector))
                        .frame(width: 11, height: 11)
                    Text(slice.ticker)
                        .font(.system(size: 14.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 56, alignment: .leading)
                    Text(Money.currency0(slice.value, currency: currency))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Theme.inkDim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(format: "%.1f%%", slice.fraction * 100))
                        .font(.system(size: 14.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.line.opacity(selected == slice.ticker ? 0.07 : 0))
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selected = selected == slice.ticker ? nil : slice.ticker
                    }
                }
            }
        }
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
