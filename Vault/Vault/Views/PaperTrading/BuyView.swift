//
//  BuyView.swift
//  Vault
//
//  Paper buy modal: search ticker, choose quantity, see cost × quantity, and
//  deduct from virtual cash on confirm.
//

import SwiftUI
import SwiftData

struct BuyView: View {
    @Bindable var viewModel: PaperTradingViewModel
    let positions: [PaperPosition]
    var currency: DisplayCurrency = .gbp

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [AddHoldingView.SymbolResult] = []
    @State private var selected: AddHoldingView.SymbolResult?
    @State private var shares = 10
    @State private var price: Double = 0
    @State private var inlineError: String?
    @State private var placed = false
    @State private var searchTask: Task<Void, Never>?

    private let fee = 1.50
    private var cost: Double { Double(shares) * price + fee }
    private var canBuy: Bool { selected != nil && shares > 0 && price > 0 }

    var body: some View {
        NavigationStack {
            Group {
                if placed { confirmation } else { form }
            }
            .padding(.horizontal, 30)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .navigationTitle(placed ? "Order placed" : "Buy · Paper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !placed { Button("Cancel") { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if placed {
                        Button("Done") { dismiss() }
                    } else {
                        Button("Buy") { placeOrder() }
                            .buttonStyle(.glassProminent)
                            .tint(Theme.gainButton)
                            .disabled(!canBuy)
                    }
                }
            }
        }
        .presentationBackground(.ultraThickMaterial)
        .presentationCornerRadius(Theme.sheetRadius)
        .presentationDetents([.medium, .large])
        .sensoryFeedback(.success, trigger: placed)
    }

    // MARK: Form

    private var form: some View {
        VStack(alignment: .leading, spacing: 18) {
            // search
            VStack(alignment: .leading, spacing: 8) {
                Text("Ticker").vaultLabel()
                HStack(spacing: 12) {
                    if let selected {
                        TickerMark(ticker: selected.symbol, sector: selected.sector, size: 36)
                    } else {
                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.inkDim)
                    }
                    TextField("Search ticker…", text: $query)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .font(.system(size: 17, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                        .onChange(of: query) { _, v in scheduleSearch(v) }
                    if price > 0 {
                        Text(Money.currency(price, currency: currency))
                            .font(.system(size: 16, design: .monospaced)).foregroundStyle(Theme.inkSoft)
                    }
                }
                .padding(.horizontal, 15).padding(.vertical, 12)
                .fieldBox()

                if !results.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(results) { r in
                            Button { pick(r) } label: {
                                HStack(spacing: 12) {
                                    TickerMark(ticker: r.symbol, sector: r.sector, size: 32)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(r.symbol).font(.system(size: 14, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.ink)
                                        Text(r.name).font(.system(size: 12)).foregroundStyle(Theme.inkDim).lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThickMaterial))
                }
            }

            // quantity
            VStack(alignment: .leading, spacing: 8) {
                Text("Shares").vaultLabel()
                QuantityStepper(value: $shares, step: 10, min: 1)
            }

            if let inlineError {
                Label(inlineError, systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 13.5)).foregroundStyle(Theme.loss)
            }

            VStack(spacing: 6) {
                summaryRow("Est. cost (incl. \(Money.currency(fee, currency: currency)) fee)",
                           Money.currency(cost, currency: currency), emphasised: true)
                summaryRow("Available virtual cash", Money.currency(viewModel.cash, currency: currency))
            }
            .padding(.top, 14)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line.opacity(0.1)).frame(height: 1) }
        }
    }

    private var confirmation: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Theme.gain)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Theme.gain.opacity(0.18)))
            Text("Paper order placed").font(.system(size: 21, weight: .semibold)).foregroundStyle(Theme.ink)
            Text("Bought \(shares) \(selected?.symbol ?? "") @ \(Money.currency(price, currency: currency))")
                .font(.system(size: 14)).foregroundStyle(Theme.inkDim)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }

    // MARK: Pieces

    private func summaryRow(_ label: String, _ value: String, emphasised: Bool = false) -> some View {
        HStack {
            Text(label).font(.system(size: 14)).foregroundStyle(Theme.inkDim)
            Spacer()
            Text(value).font(.system(size: emphasised ? 22 : 15, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.ink)
        }
    }

    // MARK: Actions

    private func scheduleSearch(_ text: String) {
        selected = nil; price = 0; inlineError = nil
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { results = []; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            await runSearch(trimmed)
        }
    }

    @MainActor
    private func runSearch(_ text: String) async {
        if KeychainService.shared.has(.finnhub),
           let symbols = try? await FinnhubService.shared.search(text), !symbols.isEmpty {
            results = symbols.map { .init(symbol: $0.symbol, name: $0.description, sector: "Technology", price: nil) }
            return
        }
        let upper = text.uppercased()
        results = AddHoldingView.localUniverse.filter { $0.symbol.contains(upper) || $0.name.uppercased().contains(upper) }
    }

    private func pick(_ r: AddHoldingView.SymbolResult) {
        selected = r; query = r.symbol; results = []
        if let p = r.price { price = p }
        Task {
            if KeychainService.shared.has(.finnhub), let q = try? await FinnhubService.shared.quote(for: r.symbol) {
                price = q.c
            }
        }
    }

    private func placeOrder() {
        guard let selected, canBuy else { return }
        let result = viewModel.buy(ticker: selected.symbol, companyName: selected.name, sector: selected.sector,
                                   shares: Double(shares), price: price,
                                   existing: positions, in: context)
        switch result {
        case .ok: withAnimation { placed = true }
        case .insufficientCash: inlineError = "Not enough virtual cash for this order."
        case .insufficientShares: inlineError = "Invalid quantity."
        }
    }
}

private extension View {
    func fieldBox() -> some View {
        background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Theme.line.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line.opacity(0.12), lineWidth: 0.5)))
    }
}

#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        BuyView(viewModel: PaperTradingViewModel(), positions: MockData.positions)
    }
    .modelContainer(MockData.previewContainer())
}
