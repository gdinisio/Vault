//
//  EditHoldingView.swift
//  Vault
//
//  Edit an existing holding's shares, purchase price, date, FX charge and
//  broker fee — e.g. to fix a mistyped entry. Amounts are entered in a chosen
//  currency (USD/GBP) and stored in the USD base.
//

import SwiftUI
import SwiftData

struct EditHoldingView: View {
    let holding: Holding
    var displayCurrency: DisplayCurrency = .gbp
    var onSaved: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var entryCurrency: DisplayCurrency
    @State private var sharesText: String
    @State private var priceText: String
    @State private var purchaseDate: Date
    @State private var fxText: String
    @State private var feeText: String

    init(holding: Holding, displayCurrency: DisplayCurrency = .gbp, onSaved: @escaping () -> Void = {}) {
        self.holding = holding
        self.displayCurrency = displayCurrency
        self.onSaved = onSaved
        _entryCurrency = State(initialValue: displayCurrency)
        // Pre-fill from the stored USD base, expressed in the entry currency.
        let fmt: (Double) -> String = { String(format: "%.2f", Money.convert($0, to: displayCurrency)) }
        _sharesText = State(initialValue: Self.trim(holding.shares))
        _priceText = State(initialValue: fmt(holding.purchasePricePerShare))
        _fxText = State(initialValue: fmt(holding.fxCharge))
        _feeText = State(initialValue: fmt(holding.brokerFee))
        _purchaseDate = State(initialValue: holding.purchaseDate)
    }

    private var shares: Double { Double(sharesText) ?? 0 }
    private var price: Double { Double(priceText) ?? 0 }
    private var fx: Double { Double(fxText) ?? 0 }
    private var fee: Double { Double(feeText) ?? 0 }
    private var costBasis: Double { shares * price + fx + fee }
    private var canSave: Bool { shares > 0 && price > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    identityHeader
                    currencyToggle
                    fieldGrid
                    totalRow
                }
                .padding(.horizontal, 36)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .navigationTitle("Edit \(holding.ticker)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: { Image(systemName: "checkmark") }
                        .accessibilityLabel("Save")
                        .buttonStyle(.glassProminent)
                        .tint(Theme.accentButton)
                        .disabled(!canSave)
                }
            }
        }
        .presentationBackground(.ultraThickMaterial)
        .presentationCornerRadius(Theme.sheetRadius)
        .presentationDetents([.large])
    }

    private var identityHeader: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.ticker).font(.system(size: 19, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(holding.companyName).font(.footnote).foregroundStyle(Theme.inkDim).lineLimit(1)
            }
            Spacer()
        }
    }

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

    private var fieldGrid: some View {
        Grid(horizontalSpacing: 22, verticalSpacing: 16) {
            GridRow {
                labelledField("Number of shares") { numericField($sharesText, placeholder: "0") }
                labelledField("Purchase price") { numericField($priceText, placeholder: "0.00") }
            }
            GridRow {
                labelledField("Purchase date") {
                    DatePicker("", selection: $purchaseDate, in: ...Date.now, displayedComponents: .date)
                        .labelsHidden().datePickerStyle(.compact)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 16) {
                    labelledField("FX charge") { numericField($fxText, placeholder: "0.00") }
                    labelledField("Broker fee") { numericField($feeText, placeholder: "0.00") }
                }
            }
        }
    }

    private var totalRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Total cost basis").vaultLabel()
                Text("shares × price + FX + fee").font(.system(size: 12.5)).foregroundStyle(Theme.inkDim)
            }
            Spacer()
            Text(Money.literal(costBasis, currency: entryCurrency))
                .font(.system(size: 38, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.2), value: costBasis)
        }
        .padding(.top, 14)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line.opacity(0.1)).frame(height: 1) }
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

    private func convertEntries(from old: DisplayCurrency, to new: DisplayCurrency) {
        func reExpress(_ text: String) -> String {
            guard let value = Double(text) else { return text }
            return String(format: "%.2f", Money.convert(Money.toBase(value, from: old), to: new))
        }
        if !priceText.isEmpty { priceText = reExpress(priceText) }
        if !fxText.isEmpty { fxText = reExpress(fxText) }
        if !feeText.isEmpty { feeText = reExpress(feeText) }
    }

    private func save() {
        guard canSave else { return }
        holding.shares = shares
        holding.purchasePricePerShare = Money.toBase(price, from: entryCurrency)
        holding.fxCharge = Money.toBase(fx, from: entryCurrency)
        holding.brokerFee = Money.toBase(fee, from: entryCurrency)
        holding.purchaseDate = purchaseDate
        try? context.save()
        Haptics.success()
        onSaved()
        dismiss()
    }

    private static func trim(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

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
        EditHoldingView(holding: MockData.holdings[1])
    }
    .modelContainer(MockData.previewContainer())
}
