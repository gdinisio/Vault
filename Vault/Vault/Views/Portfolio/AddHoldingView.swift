//
//  AddHoldingView.swift
//  Vault
//
//  Bottom sheet to add a holding: ticker search (Finnhub), shares, price,
//  date, FX charge and broker fee, with a live cost-basis preview. The user
//  chooses the currency they entered the price/fees in (USD or GBP); amounts
//  are converted to the USD base for storage.
//

import SwiftUI
import SwiftData

struct AddHoldingView: View {
    var currency: DisplayCurrency = .gbp
    var onAdd: (Holding) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [SymbolResult] = []
    @State private var selected: SymbolResult?
    @State private var searching = false
    @State private var inlineError: String?

    @State private var entryCurrency: DisplayCurrency
    @State private var sharesText = ""
    @State private var priceText = ""
    @State private var purchaseDate = Date.now
    @State private var fxText = ""
    @State private var feeText = ""

    @State private var searchTask: Task<Void, Never>?

    init(currency: DisplayCurrency = .gbp, onAdd: @escaping (Holding) -> Void) {
        self.currency = currency
        self.onAdd = onAdd
        _entryCurrency = State(initialValue: currency)
    }

    private var shares: Double { Double(sharesText) ?? 0 }
    private var price: Double { Double(priceText) ?? 0 }
    private var fx: Double { Double(fxText) ?? 0 }
    private var fee: Double { Double(feeText) ?? 0 }
    /// Cost basis in the entry currency (for the live preview).
    private var costBasis: Double { shares * price + fx + fee }
    private var canAdd: Bool { selected != nil && shares > 0 && price > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    searchField
                    currencyToggle
                    fieldGrid
                    if let inlineError {
                        Label(inlineError, systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 13.5))
                            .foregroundStyle(Theme.loss)
                    }
                    totalRow
                }
                .padding(.horizontal, 36)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .navigationTitle("Add holding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { commit() }
                        .buttonStyle(.glassProminent)
                        .tint(Theme.gainButton)
                        .disabled(!canAdd)
                }
            }
        }
        .presentationBackground(.ultraThickMaterial)
        .presentationCornerRadius(Theme.sheetRadius)
        .presentationDetents([.large])
    }

    // MARK: Search

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stock ticker").vaultLabel()
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.inkDim)
                TextField("Search ticker or company…", text: $query)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .foregroundStyle(Theme.ink)
                    .onChange(of: query) { _, newValue in scheduleSearch(newValue) }
                if searching { ProgressView().controlSize(.small) }
                else if let selected { Text(selected.sector).font(.system(size: 13, design: .monospaced)).foregroundStyle(Theme.inkDim) }
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .fieldBackground()

            if !results.isEmpty {
                VStack(spacing: 4) {
                    ForEach(results) { result in
                        Button { pick(result) } label: { resultRow(result) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(7)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThickMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.line.opacity(0.12), lineWidth: 0.5))
                )
            }
        }
    }

    private func resultRow(_ result: SymbolResult) -> some View {
        HStack(spacing: 12) {
            TickerMark(ticker: result.symbol, sector: result.sector, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(result.symbol).font(.system(size: 15, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.ink)
                Text(result.name).font(.system(size: 12.5)).foregroundStyle(Theme.inkDim).lineLimit(1)
            }
            Spacer()
            if let priceUSD = result.price {
                // Search universe prices are USD — show in the entry currency.
                Text(Money.literal(Money.convert(priceUSD, to: entryCurrency), currency: entryCurrency))
                    .font(.system(size: 13, design: .monospaced)).foregroundStyle(Theme.inkDim)
            }
        }
        .padding(.horizontal, 11).padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    // MARK: Currency toggle

    private var currencyToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amounts entered in").vaultLabel()
            Picker("Entry currency", selection: $entryCurrency) {
                ForEach(DisplayCurrency.allCases, id: \.self) { c in
                    Text("\(c.symbol)  \(c.rawValue)").tag(c)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: entryCurrency) { old, new in convertEntries(from: old, to: new) }
        }
    }

    // MARK: Fields

    private var fieldGrid: some View {
        Grid(horizontalSpacing: 22, verticalSpacing: 16) {
            GridRow {
                labelledField("Number of shares") {
                    numericField($sharesText, placeholder: "0")
                }
                labelledField("Purchase price (\(entryCurrency.symbol))") {
                    numericField($priceText, placeholder: "0.00")
                }
            }
            GridRow {
                labelledField("Purchase date") {
                    DatePicker("", selection: $purchaseDate, in: ...Date.now, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .fieldBackground()
                }
                HStack(spacing: 16) {
                    labelledField("FX charge (\(entryCurrency.symbol))") { numericField($fxText, placeholder: "0.00") }
                    labelledField("Broker fee (\(entryCurrency.symbol))") { numericField($feeText, placeholder: "0.00") }
                }
            }
        }
    }

    private var totalRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Total cost basis").vaultLabel()
                Text("shares × price + FX + fee")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.inkDim)
            }
            Spacer()
            Text(Money.literal(costBasis, currency: entryCurrency))
                .font(.system(size: 38, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.2), value: costBasis)
        }
        .padding(.top, 14)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.line.opacity(0.1)).frame(height: 1)
        }
    }

    // MARK: Helpers

    private func labelledField(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).vaultLabel()
            content()
        }
    }

    private func numericField(_ text: Binding<String>, placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .keyboardType(.decimalPad)
            .font(.system(size: 17, design: .monospaced))
            .foregroundStyle(Theme.ink)
            .onChange(of: text.wrappedValue) { _, newValue in
                let filtered = newValue.filter { $0.isNumber || $0 == "." }
                if filtered != newValue { text.wrappedValue = filtered }
            }
            .padding(.horizontal, 15).padding(.vertical, 12)
            .fieldBackground()
    }

    /// Re-express the entered price/fx/fee when the entry currency changes so
    /// the underlying value is preserved.
    private func convertEntries(from old: DisplayCurrency, to new: DisplayCurrency) {
        func reExpress(_ text: String) -> String {
            guard let value = Double(text) else { return text }
            let converted = Money.convert(Money.toBase(value, from: old), to: new)
            return String(format: "%.2f", converted)
        }
        if !priceText.isEmpty { priceText = reExpress(priceText) }
        if !fxText.isEmpty { fxText = reExpress(fxText) }
        if !feeText.isEmpty { feeText = reExpress(feeText) }
    }

    // MARK: Actions

    private func scheduleSearch(_ text: String) {
        selected = nil
        inlineError = nil
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 1 else { results = []; return }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            await runSearch(trimmed)
        }
    }

    @MainActor
    private func runSearch(_ text: String) async {
        searching = true
        defer { searching = false }

        if KeychainService.shared.has(.finnhub) {
            do {
                let symbols = try await FinnhubService.shared.search(text)
                guard !Task.isCancelled else { return }
                results = symbols.map { SymbolResult(symbol: $0.symbol, name: $0.description, sector: "Technology", price: nil) }
                if results.isEmpty { inlineError = "No matching symbols found." }
                return
            } catch {
                // fall through to local universe
            }
        }
        // Offline fallback
        let upper = text.uppercased()
        results = Self.localUniverse.filter {
            $0.symbol.contains(upper) || $0.name.uppercased().contains(upper)
        }
        if results.isEmpty { inlineError = "No matching symbols found." }
    }

    private func pick(_ result: SymbolResult) {
        selected = result
        query = result.symbol
        results = []
        inlineError = nil
        if let priceUSD = result.price, priceText.isEmpty {
            priceText = String(format: "%.2f", Money.convert(priceUSD, to: entryCurrency))
        }
        // Best-effort live price fill.
        Task { await fillLivePrice(result.symbol) }
    }

    @MainActor
    private func fillLivePrice(_ symbol: String) async {
        guard KeychainService.shared.has(.finnhub) else { return }
        if let quote = try? await FinnhubService.shared.quote(for: symbol) {
            // Quote is USD → express in the entry currency.
            priceText = String(format: "%.2f", Money.convert(quote.c, to: entryCurrency))
        }
    }

    private func commit() {
        guard let selected, canAdd else {
            inlineError = "Choose a valid ticker first."
            return
        }
        // Convert entered amounts from the entry currency into the USD base.
        let priceUSD = Money.toBase(price, from: entryCurrency)
        let fxUSD = Money.toBase(fx, from: entryCurrency)
        let feeUSD = Money.toBase(fee, from: entryCurrency)
        let holding = Holding(
            ticker: selected.symbol,
            companyName: selected.name,
            sector: selected.sector,
            shares: shares,
            purchasePricePerShare: priceUSD,
            purchaseDate: purchaseDate,
            fxCharge: fxUSD,
            brokerFee: feeUSD,
            currentPrice: priceUSD,
            lastUpdated: .now
        )
        onAdd(holding)
        Haptics.success()
        dismiss()
    }

    // MARK: Offline search universe (used when no Finnhub key is set)

    struct SymbolResult: Identifiable, Hashable {
        let symbol: String
        let name: String
        let sector: String
        let price: Double?
        var id: String { symbol }
    }

    static let localUniverse: [SymbolResult] = [
        .init(symbol: "AAPL", name: "Apple Inc.", sector: "Technology", price: 214.20),
        .init(symbol: "MSFT", name: "Microsoft Corp.", sector: "Technology", price: 441.20),
        .init(symbol: "NVDA", name: "NVIDIA Corp.", sector: "Technology", price: 131.60),
        .init(symbol: "GOOGL", name: "Alphabet Inc.", sector: "Technology", price: 178.30),
        .init(symbol: "AMZN", name: "Amazon.com Inc.", sector: "Consumer", price: 201.40),
        .init(symbol: "TSLA", name: "Tesla Inc.", sector: "Consumer", price: 214.80),
        .init(symbol: "VOO", name: "Vanguard S&P 500 ETF", sector: "Index Fund", price: 498.75),
        .init(symbol: "VWRL", name: "Vanguard FTSE All-World", sector: "Index Fund", price: 112.40),
        .init(symbol: "LLY", name: "Eli Lilly & Co.", sector: "Healthcare", price: 824.10),
        .init(symbol: "JPM", name: "JPMorgan Chase", sector: "Financials", price: 212.60),
        .init(symbol: "COST", name: "Costco Wholesale", sector: "Consumer", price: 794.10),
        .init(symbol: "PLTR", name: "Palantir Technologies", sector: "Technology", price: 31.85)
    ]
}

// MARK: - Field background helper

private extension View {
    func fieldBackground() -> some View {
        background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.line.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line.opacity(0.12), lineWidth: 0.5))
        )
    }
}

#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        AddHoldingView(onAdd: { _ in })
    }
}
