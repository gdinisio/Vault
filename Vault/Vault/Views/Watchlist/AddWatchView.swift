//
//  AddWatchView.swift
//  Vault
//
//  Search and add a ticker to the watchlist.
//

import SwiftUI
import SwiftData

struct AddWatchView: View {
    var existing: [String]
    var listName: String = "Watchlist"
    var onAdd: (WatchItem) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [AddHoldingView.SymbolResult] = []
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var note: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").font(.system(size: 16)).foregroundStyle(Theme.inkDim)
                    TextField("Search ticker or company…", text: $query)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                        .onChange(of: query) { _, v in scheduleSearch(v) }
                    if searching {
                        ProgressView().controlSize(.small)
                    } else if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16)).foregroundStyle(Theme.inkFaint)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .glassEffect(.regular, in: .capsule)
                .padding(.horizontal, 30)
                .padding(.top, 8)

                if let note {
                    Text(note).font(.system(size: 13)).foregroundStyle(Theme.inkDim)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 30).padding(.top, 10)
                }

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(results) { r in
                            Button { add(r) } label: { row(r) }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24).padding(.top, 14)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Add to watchlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Cancel")
                }
            }
        }
        .presentationBackground(.ultraThickMaterial)
        .presentationCornerRadius(Theme.sheetRadius)
        .presentationDetents([.large, .medium])
    }

    private func row(_ r: AddHoldingView.SymbolResult) -> some View {
        let already = existing.contains(r.symbol)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(r.symbol).font(.system(size: 15, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.ink)
                Text(r.name).font(.system(size: 12.5)).foregroundStyle(Theme.inkDim).lineLimit(1)
            }
            Spacer()
            Image(systemName: already ? "checkmark.circle.fill" : "plus.circle")
                .font(.system(size: 18)).foregroundStyle(already ? Theme.gain : Theme.accent)
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.line.opacity(0.05)))
        .contentShape(Rectangle())
        .opacity(already ? 0.6 : 1)
    }

    private func scheduleSearch(_ text: String) {
        note = nil
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
        searching = true
        defer { searching = false }
        if KeychainService.shared.has(.finnhub),
           let symbols = try? await FinnhubService.shared.search(text), !symbols.isEmpty {
            results = symbols.map { .init(symbol: $0.symbol, name: $0.description, sector: "Technology", price: nil) }
            return
        }
        let upper = text.uppercased()
        results = AddHoldingView.localUniverse.filter { $0.symbol.contains(upper) || $0.name.uppercased().contains(upper) }
        if results.isEmpty { note = "No matching symbols found." }
    }

    private func add(_ r: AddHoldingView.SymbolResult) {
        guard !existing.contains(r.symbol) else { return }
        onAdd(WatchItem(ticker: r.symbol, companyName: r.name, sector: r.sector, listName: listName))
        Haptics.success()
        dismiss()
    }
}

#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        AddWatchView(existing: []) { _ in }
    }
}
