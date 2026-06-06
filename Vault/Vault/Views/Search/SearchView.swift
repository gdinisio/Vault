//
//  SearchView.swift
//  Vault
//
//  Search any ticker or company (Finnhub when a key is set, local universe
//  otherwise). Tapping a result pushes a detail with a live chart, an
//  "Add to watchlist" action and AI analysis.
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query private var watch: [WatchItem]

    @State private var query = ""
    @State private var results: [AddHoldingView.SymbolResult] = []
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?

    private var currency: DisplayCurrency {
        _ = settings.fxToken
        return settings.displayCurrency
    }

    /// Results to show: live search results, or the popular universe when idle.
    private var rows: [AddHoldingView.SymbolResult] {
        query.trimmingCharacters(in: .whitespaces).isEmpty ? AddHoldingView.localUniverse : results
    }

    private var isIdle: Bool { query.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(isIdle ? "Popular" : "Results").vaultLabel()
                    if searching { ProgressView().controlSize(.mini) }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)

                ForEach(rows) { result in
                    NavigationLink(value: result) {
                        resultRow(result)
                    }
                    .buttonStyle(.plain)
                }

                if !isIdle && results.isEmpty && !searching {
                    Text("No matching symbols found.")
                        .font(.subheadline).foregroundStyle(Theme.inkDim)
                        .padding(.horizontal, 4).padding(.top, 8)
                }
            }
            .vaultPagePadding()
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Search")
        .searchable(text: $query)
        .onChange(of: query) { _, value in scheduleSearch(value) }
        .navigationDestination(for: AddHoldingView.SymbolResult.self) { result in
            TickerSearchDetailView(result: result)
        }
    }

    private func resultRow(_ r: AddHoldingView.SymbolResult) -> some View {
        let owned = watch.contains { $0.ticker == r.symbol }
        return HStack(spacing: 12) {
            TickerMark(ticker: r.symbol, sector: r.sector, size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(r.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(r.name)
                    .font(.caption2).foregroundStyle(Theme.inkDim).lineLimit(1)
            }
            Spacer()
            if owned {
                Image(systemName: "star.fill").font(.caption).foregroundStyle(Theme.warn)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .contentCard(cornerRadius: 16)
    }

    // MARK: - Search

    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { results = []; searching = false; return }
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
        results = AddHoldingView.localUniverse.filter {
            $0.symbol.contains(upper) || $0.name.uppercased().contains(upper)
        }
    }
}

// MARK: - Ticker search detail

struct TickerSearchDetailView: View {
    let result: AddHoldingView.SymbolResult

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query private var watch: [WatchItem]

    @State private var latestClose: Double = 0
    @State private var showAnalysis = false

    private var currency: DisplayCurrency {
        _ = settings.fxToken
        return settings.displayCurrency
    }
    private var isWatched: Bool { watch.contains { $0.ticker == result.symbol } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                PriceChartView(symbol: result.symbol, sector: result.sector, currency: currency)
                addButton
                analyseButton
            }
            .padding(28)
        }
        .background(Theme.bgDeep.opacity(0.001))
        .navigationTitle(result.symbol)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAnalysis) {
            StockAnalysisView(
                snapshot: StockSnapshot(ticker: result.symbol, companyName: result.name, sector: result.sector,
                                        shares: 0, averageCost: 0, currentPrice: latestClose, returnPercent: 0),
                currency: currency
            )
        }
        .task {
            if let history = try? await PriceHistoryService.shared.history(for: result.symbol, range: .month),
               let last = history.last?.close {
                latestClose = last
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            TickerMark(ticker: result.symbol, sector: result.sector, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(result.symbol).font(.system(size: 26, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(result.name).font(.system(size: 15)).foregroundStyle(Theme.inkDim)
            }
            Spacer()
        }
    }

    private var addButton: some View {
        Button {
            guard !isWatched else { return }
            Haptics.success()
            context.insert(WatchItem(ticker: result.symbol, companyName: result.name, sector: result.sector))
            try? context.save()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isWatched ? "star.fill" : "star")
                    .foregroundStyle(isWatched ? Theme.warn : Theme.accent)
                Text(isWatched ? "On your watchlist" : "Add to watchlist")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                Spacer()
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.line.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.line.opacity(0.12), lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
        .disabled(isWatched)
    }

    private var analyseButton: some View {
        Button { Haptics.impact(.light); showAnalysis = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").foregroundStyle(Theme.aiPurple)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Analyse with AI").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text("News-driven read on \(result.symbol) — is it worth buying?")
                        .font(.system(size: 12.5)).foregroundStyle(Theme.inkDim)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.inkDim)
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.aiPurple.opacity(0.14))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.aiPurple.opacity(0.3), lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
    }
}
