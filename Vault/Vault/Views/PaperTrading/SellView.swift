//
//  SellView.swift
//  Vault
//
//  Paper sell modal: pick an open position, choose quantity, see proceeds, and
//  add to virtual cash on confirm.
//

import SwiftUI
import SwiftData

struct SellView: View {
    @Bindable var viewModel: PaperTradingViewModel
    let positions: [PaperPosition]
    var currency: DisplayCurrency = .gbp

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var selectedID: PaperPosition.ID?
    @State private var shares = 1
    @State private var inlineError: String?
    @State private var sold = false

    private var selected: PaperPosition? {
        positions.first { $0.id == selectedID } ?? positions.first
    }
    private var proceeds: Double { Double(shares) * (selected?.currentPrice ?? 0) }
    private var canSell: Bool {
        guard let selected else { return false }
        return shares > 0 && Double(shares) <= selected.shares
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Theme.line.opacity(0.22)).frame(width: 42, height: 5)
                .padding(.top, 14).padding(.bottom, 8)
            if sold { confirmation } else { form }
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 28)
        .presentationBackground(.ultraThickMaterial)
        .presentationCornerRadius(Theme.sheetRadius)
        .presentationDetents([.medium, .large])
        .sensoryFeedback(.success, trigger: sold)
        .onAppear {
            if selectedID == nil { selectedID = positions.first?.id }
            shares = Int(selected?.shares ?? 1)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Sell · Paper").font(.system(size: 21, weight: .semibold)).foregroundStyle(Theme.ink)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                        .frame(width: 38, height: 38).background(Circle().fill(Theme.line.opacity(0.08)))
                }.buttonStyle(.plain)
            }

            if positions.isEmpty {
                Text("You have no open positions to sell.")
                    .font(.system(size: 15)).foregroundStyle(Theme.inkDim)
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 30)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Position").vaultLabel()
                    Menu {
                        ForEach(positions) { p in
                            Button {
                                selectedID = p.id
                                shares = Int(p.shares)
                            } label: {
                                Text("\(p.ticker) — \(Int(p.shares)) sh")
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if let selected {
                                TickerMark(ticker: selected.ticker, sector: selected.sector, size: 36)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(selected.ticker).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                                    Text("\(Int(selected.shares)) sh @ \(Money.currency(selected.currentPrice, currency: currency))")
                                        .font(.system(size: 12.5, design: .monospaced)).foregroundStyle(Theme.inkDim)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 13)).foregroundStyle(Theme.inkDim)
                        }
                        .padding(.horizontal, 15).padding(.vertical, 11)
                        .fieldBoxSell()
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Shares to sell").vaultLabel()
                        Spacer()
                        if let selected {
                            Button("Max") { shares = Int(selected.shares) }
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.accent)
                        }
                    }
                    QuantityStepper(value: $shares, step: 1, min: 1)
                }

                if let inlineError {
                    Label(inlineError, systemImage: "exclamationmark.circle.fill")
                        .font(.system(size: 13.5)).foregroundStyle(Theme.loss)
                }

                VStack(spacing: 6) {
                    summaryRow("Proceeds", Money.currency(proceeds, currency: currency), emphasised: true)
                    if let selected {
                        let pl = (selected.currentPrice - selected.averageCost) * Double(shares)
                        summaryRow("Realised P&L", Money.signed(pl, currency: currency), tint: Theme.tone(pl))
                    }
                }
                .padding(.top, 14)
                .overlay(alignment: .top) { Rectangle().fill(Theme.line.opacity(0.1)).frame(height: 1) }

                Button { sell() } label: {
                    Text("Place paper sell").font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(colors: [Theme.lossButton, Theme.lossButton.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                }
                .buttonStyle(.plain).opacity(canSell ? 1 : 0.4).disabled(!canSell)
            }
        }
    }

    private var confirmation: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark")
                .font(.system(size: 32, weight: .bold)).foregroundStyle(Theme.gain)
                .frame(width: 64, height: 64).background(Circle().fill(Theme.gain.opacity(0.18)))
            Text("Paper sale placed").font(.system(size: 21, weight: .semibold)).foregroundStyle(Theme.ink)
            Text("Sold \(shares) \(selected?.ticker ?? "") for \(Money.currency(proceeds, currency: currency))")
                .font(.system(size: 14)).foregroundStyle(Theme.inkDim)
            Button { dismiss() } label: {
                Text("Done").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 28).padding(.vertical, 13)
                    .background(Capsule().fill(Theme.line.opacity(0.08)).overlay(Capsule().strokeBorder(Theme.line.opacity(0.16), lineWidth: 0.5)))
            }.buttonStyle(.plain).padding(.top, 8)
        }
        .padding(.vertical, 24).frame(maxWidth: .infinity)
    }

    private func summaryRow(_ label: String, _ value: String, emphasised: Bool = false, tint: Color = Theme.ink) -> some View {
        HStack {
            Text(label).font(.system(size: 14)).foregroundStyle(Theme.inkDim)
            Spacer()
            Text(value).font(.system(size: emphasised ? 22 : 15, weight: .semibold, design: .monospaced)).foregroundStyle(tint)
        }
    }

    private func sell() {
        guard let selected, canSell else { return }
        let result = viewModel.sell(position: selected, shares: Double(shares), price: selected.currentPrice, in: context)
        switch result {
        case .ok: withAnimation { sold = true }
        case .insufficientShares: inlineError = "You only hold \(Int(selected.shares)) shares."
        case .insufficientCash: inlineError = "Unexpected error."
        }
    }
}

private extension View {
    func fieldBoxSell() -> some View {
        background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Theme.line.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line.opacity(0.12), lineWidth: 0.5)))
    }
}

#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        SellView(viewModel: PaperTradingViewModel(), positions: MockData.positions)
    }
    .modelContainer(MockData.previewContainer())
}
