//
//  SearchView.swift
//  Vault
//
//  Dedicated Search tab. Searches stocks & ETFs (Finnhub when a key is set,
//  a local universe otherwise) and presents results as Apple-ecosystem style
//  ticker cards built on the iOS 26 / WWDC25 Liquid Glass material.
//
//  The search field itself is owned by the TabView's `.searchable` (see
//  ContentView); this view receives the live query as a binding and reacts.
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Query private var watch: [WatchItem]

    @State private var query = ""
    @State private var results: [AddHoldingView.SymbolResult] = []
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?

    /// The selected ticker. On iPad (regular width) it drives the inspector
    /// panel; on iPhone (compact width) it drives a `navigationDestination`
    /// push — back button returns to the search list.
    @State private var selected: AddHoldingView.SymbolResult?
    @State private var inspectorPresented = true

    private var isCompact: Bool { hSizeClass == .compact }

    /// Binding that only feeds the navigation destination in compact width —
    /// nil on iPad so the push never fires there.
    private var pushSelection: Binding<AddHoldingView.SymbolResult?> {
        Binding(
            get: { isCompact ? selected : nil },
            set: { newValue in
                guard isCompact else { return }
                selected = newValue
            }
        )
    }

    /// Inspector is gated to regular width. On iPhone we route via push, so
    /// the inspector never auto-adapts into an unwanted sheet.
    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { !isCompact && inspectorPresented },
            set: { newValue in
                guard !isCompact else { return }
                inspectorPresented = newValue
            }
        )
    }

    /// Recently inspected tickers, persisted as JSON (most recent first).
    @AppStorage("vault.recentSearches") private var recentsData = Data()

    /// The Recent rail snapshot held for the current "idle session". We freeze
    /// the visible rail when the tab appears (and re-snapshot whenever the
    /// user returns from a search) so taps never cause cards to shuffle
    /// under the user's finger — matches Spotlight / App Store behaviour.
    @State private var displayedRecents: [RecentTicker] = []

    private var currency: DisplayCurrency {
        _ = settings.fxToken
        return settings.displayCurrency
    }

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }
    private var isIdle: Bool { trimmed.isEmpty }

    /// Names of the watchlists a symbol currently belongs to.
    private func watchlists(for symbol: String) -> [String] {
        Array(Set(watch.filter { $0.ticker == symbol }.map(\.listName))).sorted()
    }

    /// Recently inspected tickers (most recent first).
    private var recents: [RecentTicker] {
        (try? JSONDecoder().decode([RecentTicker].self, from: recentsData)) ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if isIdle {
                        idleContent
                    } else {
                        resultsContent
                    }
                }
                .vaultPagePadding()
            }
            .scrollIndicators(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search stocks & ETFs")
            .onChange(of: query) { _, value in scheduleSearch(value) }
            .onAppear { refreshRailSnapshot() }
            .onChange(of: isIdle) { _, idle in
                // Re-snapshot the rail when the user returns from search to
                // idle — a natural break point where reorder is unsurprising.
                if idle { refreshRailSnapshot() }
            }
            // iPhone (compact): push the detail full-screen. Back button
            // returns to the search list. On iPad this binding stays nil.
            .navigationDestination(item: pushSelection) { result in
                SearchTickerDetailView(result: result)
            }
        }
        // iPad (regular): right-hand inspector — never adapts to sheet on
        // iPhone because the binding clamps it off in compact width.
        .inspector(isPresented: inspectorBinding) {
            NavigationStack {
                inspectorContent
            }
            .inspectorColumnWidth(min: 380, ideal: 460, max: 600)
        }
    }

    // MARK: Idle content — Recent (horizontal) + Popular

    @ViewBuilder
    private var idleContent: some View {
        if !displayedRecents.isEmpty {
            sectionLabel("Recent")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(displayedRecents) { recent in
                        RecentTickerCard(
                            recent: recent,
                            isSelected: selected?.symbol == recent.symbol,
                            onTap: {
                                select(AddHoldingView.SymbolResult(
                                    symbol: recent.symbol, name: recent.name,
                                    sector: recent.sector, price: nil
                                ))
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
            .padding(.bottom, 18)
        }

        sectionLabel("Popular")
        tickerList(AddHoldingView.localUniverse)
    }

    // MARK: Results content (or no-results page)

    @ViewBuilder
    private var resultsContent: some View {
        if results.isEmpty && !searching {
            ContentUnavailableView {
                Label("No Results", systemImage: "magnifyingglass")
            } description: {
                Text("No stocks or ETFs match \"\(trimmed)\".")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else {
            HStack(spacing: 8) {
                Text("Results").font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                ProgressView().controlSize(.small).opacity(searching ? 1 : 0)
                Spacer()
            }
            .padding(.horizontal, 4).padding(.top, 4).padding(.bottom, 8)

            tickerList(results)
        }
    }

    // MARK: Row list

    @ViewBuilder
    private func tickerList(_ list: [AddHoldingView.SymbolResult]) -> some View {
        ForEach(Array(list.enumerated()), id: \.element.id) { index, result in
            let isSel = selected?.symbol == result.symbol
            let nextSel = index + 1 < list.count && selected?.symbol == list[index + 1].symbol

            Button { select(result) } label: {
                SearchTickerRow(
                    result: result,
                    currency: currency,
                    watchlists: watchlists(for: result.symbol)
                )
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSel ? Theme.surfaceSelected : Color.clear)
            )

            if index < list.count - 1 && !isSel && !nextSel {
                Divider().padding(.leading, 12)
            }
        }
        .animation(.easeOut(duration: 0.15), value: selected?.symbol)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    // MARK: Inspector (right panel)

    @ViewBuilder
    private var inspectorContent: some View {
        if let selected {
            SearchTickerDetailView(result: selected)
                .id(selected.symbol)
        } else {
            ContentUnavailableView(
                "Select a Ticker",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Choose a stock or ETF from the list to inspect its chart and AI analysis.")
            )
        }
    }

    // MARK: Selection + recents

    private func select(_ result: AddHoldingView.SymbolResult) {
        Haptics.impact(.light)
        selected = result
        inspectorPresented = true
        recordRecent(result)
    }

    /// Record a tapped ticker into recents. **No-bump**: if it's already in
    /// the list we leave its position alone — re-tapping a card should never
    /// reorder the rail. Only first-time encounters prepend (and push the
    /// oldest out when the cap is reached).
    private func recordRecent(_ r: AddHoldingView.SymbolResult) {
        var list = recents
        if list.contains(where: { $0.symbol == r.symbol }) { return }
        list.insert(RecentTicker(symbol: r.symbol, name: r.name, sector: r.sector), at: 0)
        list = Array(list.prefix(12))
        recentsData = (try? JSONEncoder().encode(list)) ?? recentsData
    }

    /// Take a fresh snapshot of the persisted recents into the view-state
    /// rail. Called on tab appear and on transitions back to idle.
    private func refreshRailSnapshot() {
        displayedRecents = recents
    }

    // MARK: Search

    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        let q = text.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { results = []; searching = false; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            await runSearch(q)
        }
    }

    @MainActor
    private func runSearch(_ text: String) async {
        searching = true
        defer { searching = false }
        if KeychainService.shared.has(.finnhub),
           let symbols = try? await FinnhubService.shared.search(text), !symbols.isEmpty {
            results = symbols.map {
                .init(symbol: $0.symbol, name: $0.description, sector: "Technology", price: nil)
            }
            return
        }
        let upper = text.uppercased()
        results = AddHoldingView.localUniverse.filter {
            $0.symbol.contains(upper) || $0.name.uppercased().contains(upper)
        }
    }
}

// MARK: - Recent search model (persisted)

struct RecentTicker: Codable, Identifiable, Hashable {
    let symbol: String
    let name: String
    let sector: String
    var id: String { symbol }
}

// MARK: - Recent ticker card (compact, with sparkline + 1M %)

/// A tight horizontal card for the Recent rail: symbol + 1M sparkline + %
/// change pill. Owns its own price load so each card animates in as data
/// arrives, without blocking the rest of the rail.
private struct RecentTickerCard: View {
    let recent: RecentTicker
    let isSelected: Bool
    let onTap: () -> Void

    @State private var closes: [Double] = []

    private var hasData: Bool { closes.count > 1 }
    private var change: Double? {
        guard let first = closes.first, let last = closes.last, first != 0 else { return nil }
        return (last - first) / first * 100
    }
    private var up: Bool { (change ?? 0) >= 0 }
    private var tint: Color { up ? Theme.gain : Theme.loss }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(recent.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    changePill
                }
                Text(recent.name)
                    .font(.caption2)
                    .foregroundStyle(Theme.inkDim)
                    .lineLimit(1)

                SparklineView(
                    points: hasData
                        ? closes
                        : Spark.series(seed: Double(abs(recent.symbol.hashValue % 997)),
                                       count: 18, trendingUp: up),
                    color: tint
                )
                .frame(height: 22)
                .opacity(hasData ? 1 : 0.35)
                .padding(.top, 2)
            }
            .frame(width: 132, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Theme.surfaceSelected : Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.surfaceStroke, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .task(id: recent.symbol) { await load() }
    }

    /// Filled % pill, mirrors the Apple Stocks treatment used in `SearchTickerRow`.
    private var changePill: some View {
        Text(change.map { Money.percent($0) } ?? "—")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(change == nil ? Theme.inkFaint : tint))
            .contentTransition(.numericText())
    }

    private func load() async {
        guard let history = try? await PriceHistoryService.shared.history(for: recent.symbol, range: .month) else { return }
        let points = history.map(\.close)
        guard points.count > 1 else { return }
        await MainActor.run { closes = points }
    }
}

// MARK: - Apple-ecosystem ticker card (Liquid Glass)

private struct SearchTickerRow: View {
    let result: AddHoldingView.SymbolResult
    var currency: DisplayCurrency
    var watchlists: [String] = []

    @State private var closes: [Double] = []

    private var hasData: Bool { closes.count > 1 }
    private var last: Double? { closes.last ?? result.price }
    private var change: Double? {
        guard let first = closes.first, let lastClose = closes.last, first != 0 else { return nil }
        return (lastClose - first) / first * 100
    }
    private var up: Bool { (change ?? 0) >= 0 }
    private var tint: Color { up ? Theme.gain : Theme.loss }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(result.symbol)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    if !watchlists.isEmpty {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.warn)
                    }
                }
                Text(result.name)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkDim)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            SparklineView(
                points: hasData
                    ? closes
                    : Spark.series(seed: Double(abs(result.symbol.hashValue % 997)), count: 20, trendingUp: up),
                color: tint
            )
            .frame(width: 62, height: 30)
            .opacity(hasData ? 1 : 0.4)

            VStack(alignment: .trailing, spacing: 5) {
                Text(last.map { Money.currency($0, currency: currency) } ?? "—")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                changePill
            }
            .frame(minWidth: 76, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .task(id: result.symbol) { await load() }
    }

    /// Apple Stocks signature: a small filled pill with the % change.
    private var changePill: some View {
        Text(change.map { Money.percent($0) } ?? "—")
            .font(.caption.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(change == nil ? Theme.inkFaint : tint))
            .contentTransition(.numericText())
    }

    private func load() async {
        guard let history = try? await PriceHistoryService.shared.history(for: result.symbol, range: .month) else { return }
        let points = history.map(\.close)
        guard points.count > 1 else { return }
        await MainActor.run { closes = points }
    }
}

// MARK: - Ticker detail (pushed from a result)

struct SearchTickerDetailView: View {
    let result: AddHoldingView.SymbolResult

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query private var watch: [WatchItem]
    @Query(sort: \WatchlistGroup.sortIndex) private var groups: [WatchlistGroup]

    @State private var latestClose: Double = 0
    @State private var showAnalysis = false
    @State private var showNewList = false
    @State private var newListName = ""

    private var currency: DisplayCurrency {
        _ = settings.fxToken
        return settings.displayCurrency
    }
    private var memberLists: [String] {
        Array(Set(watch.filter { $0.ticker == result.symbol }.map(\.listName))).sorted()
    }
    private var isWatched: Bool { !memberLists.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                PriceChartView(symbol: result.symbol, sector: result.sector, currency: currency)
                NewsSection(symbol: result.symbol)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 28)
        }
        .background(Theme.bgDeep.opacity(0.001))
        // The prominent title lives in-content so it's always large and sits
        // tight to the chart; the inline bar title carries the symbol once the
        // header scrolls away (App Store product-page pattern). This also
        // sidesteps the large-title-collapses-to-inline glitch that occurs
        // when pushing from a `.searchable` root.
        .navigationTitle(result.symbol)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showAnalysis) {
            StockAnalysisView(
                snapshot: StockSnapshot(ticker: result.symbol, companyName: result.name, sector: result.sector,
                                        shares: 0, averageCost: 0, currentPrice: latestClose, returnPercent: 0),
                currency: currency
            )
        }
        .alert("New Watchlist", isPresented: $showNewList) {
            TextField("Name (e.g. Tech, Growth…)", text: $newListName)
                .autocorrectionDisabled()
            Button("Create & Add") { createListAndAdd() }
                .disabled(newListName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) { newListName = "" }
        }
        .task {
            if let history = try? await PriceHistoryService.shared.history(for: result.symbol, range: .month),
               let last = history.last?.close {
                latestClose = last
            }
        }
    }

    // MARK: In-content header (always-large title)

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(result.symbol)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(result.name)
                .font(.system(size: 16))
                .foregroundStyle(Theme.inkDim)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Toolbar — ticker actions

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                ForEach(groups) { group in
                    Toggle(isOn: Binding(
                        get: { isIn(group) },
                        set: { _ in toggle(group) }
                    )) {
                        Text(group.name)
                    }
                }
                if !groups.isEmpty { Divider() }
                Button {
                    newListName = ""
                    showNewList = true
                } label: {
                    Label("New Watchlist…", systemImage: "plus")
                }
            } label: {
                Label("Add to Watchlist", systemImage: isWatched ? "star.fill" : "star")
            }
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Haptics.impact(.light)
                showAnalysis = true
            } label: {
                Label("Analyse with AI", systemImage: "sparkles")
            }
        }
    }

    // MARK: Watchlist membership

    private func isIn(_ group: WatchlistGroup) -> Bool {
        watch.contains { $0.ticker == result.symbol && $0.listName == group.name }
    }

    private func toggle(_ group: WatchlistGroup) {
        if let existing = watch.first(where: { $0.ticker == result.symbol && $0.listName == group.name }) {
            context.delete(existing)
            Haptics.impact(.rigid)
        } else {
            context.insert(WatchItem(ticker: result.symbol, companyName: result.name,
                                     sector: result.sector, listName: group.name))
            Haptics.success()
        }
        try? context.save()
    }

    private func createListAndAdd() {
        let name = newListName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let group = WatchlistGroup(name: name, sortIndex: groups.count)
        context.insert(group)
        context.insert(WatchItem(ticker: result.symbol, companyName: result.name,
                                 sector: result.sector, listName: name))
        try? context.save()
        Haptics.success()
        newListName = ""
    }
}

// MARK: - News

/// Recent company headlines for a ticker. Loads best-effort from Finnhub
/// (needs a key); shows tidy loading / empty states otherwise. Each item links
/// out to the full article.
private struct NewsSection: View {
    let symbol: String

    @State private var items: [CompanyNews] = []
    @State private var state: LoadState = .loading

    private enum LoadState { case loading, loaded, unavailable }

    /// Cap to keep the page glanceable; the chart is the headline act.
    private var shown: [CompanyNews] { Array(items.prefix(8)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("News")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 4)

            switch state {
            case .loading:
                loadingCard
            case .unavailable:
                messageCard("No recent news for \(symbol).")
            case .loaded:
                newsCard
            }
        }
        .task(id: symbol) { await load() }
    }

    private var newsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                Link(destination: URL(string: item.url) ?? URL(string: "https://finnhub.io")!) {
                    NewsRow(item: item)
                }
                .buttonStyle(.plain)

                if index < shown.count - 1 {
                    Divider().overlay(Theme.line.opacity(0.10)).padding(.leading, 12)
                }
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .contentCard()
    }

    private var loadingCard: some View {
        HStack {
            ProgressView().controlSize(.small)
            Text("Loading headlines…")
                .font(.system(size: 14)).foregroundStyle(Theme.inkDim)
            Spacer()
        }
        .padding(.horizontal, 18).padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard()
    }

    private func messageCard(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "newspaper")
                .font(.system(size: 18)).foregroundStyle(Theme.inkFaint)
            Text(text)
                .font(.system(size: 14)).foregroundStyle(Theme.inkDim)
            Spacer()
        }
        .padding(.horizontal, 18).padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard()
    }

    private func load() async {
        state = .loading
        items = []
        guard let news = try? await FinnhubService.shared.companyNews(for: symbol, days: 21),
              !news.isEmpty else {
            state = .unavailable
            return
        }
        items = news
        state = .loaded
    }
}

/// A single headline row: thumbnail (when available) + headline + source/time.
private struct NewsRow: View {
    let item: CompanyNews

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.headline)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(item.source)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.inkDim)
                    Text("·").font(.system(size: 12)).foregroundStyle(Theme.inkFaint)
                    Text(item.date.formatted(.relative(presentation: .named)))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.inkFaint)
                }
            }

            Spacer(minLength: 4)

            thumbnail
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let url = item.imageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    placeholder
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.surfaceStroke, lineWidth: 0.5)
            )
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Theme.surface)
            .overlay(
                Image(systemName: "newspaper")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.inkFaint)
            )
    }
}
