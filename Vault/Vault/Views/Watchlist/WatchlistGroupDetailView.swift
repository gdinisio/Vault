//
//  WatchlistGroupDetailView.swift
//  Vault
//
//  Shows all tickers in a named watchlist. Tapping a row pushes WatchDetailView.
//  Deletion uses the native List affordances — swipe-to-delete and the
//  edit-mode red minus → slide → Delete confirmation (`.onDelete`).
//

import SwiftUI
import SwiftData

struct WatchlistGroupDetailView: View {
    let group: WatchlistGroup
    let viewModel: PaperTradingViewModel

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @Query private var items: [WatchItem]

    @State private var showAdd = false
    @State private var editMode: EditMode = .inactive
    @State private var navItem: WatchItem?

    init(group: WatchlistGroup, viewModel: PaperTradingViewModel) {
        self.group = group
        self.viewModel = viewModel
        let name = group.name
        _items = Query(
            filter: #Predicate<WatchItem> { $0.listName == name },
            sort: \.addedDate,
            order: .reverse
        )
    }

    private var currency: DisplayCurrency {
        _ = settings.fxToken
        return settings.displayCurrency
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if items.isEmpty {
                emptyState
            } else {
                tickerList
            }
        }
        .vaultPagePadding()
        .id(settings.fxToken)
        .environment(\.editMode, $editMode)
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .navigationDestination(item: $navItem) { item in
            WatchDetailView(item: item, currency: currency, viewModel: viewModel)
        }
        .sheet(isPresented: $showAdd) {
            AddWatchView(existing: items.map(\.ticker), listName: group.name) { item in
                context.insert(item)
                try? context.save()
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Matches WatchlistsView: edit + add on the trailing side so they keep
        // the same screen position when the system back button takes leading.
        if !items.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation { editMode = editMode == .active ? .inactive : .active }
                } label: {
                    Image(systemName: editMode == .active ? "checkmark" : "pencil")
                }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showAdd = true } label: {
                Image(systemName: "plus")
            }
        }
    }

    // MARK: List

    private var tickerList: some View {
        List {
            ForEach(items) { item in
                Button { navItem = item } label: {
                    WatchRowView(item: item, currency: currency)
                }
                .buttonStyle(PressableRowStyle())
                .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { remove(item) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onDelete(perform: deleteAt)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
    }

    private func deleteAt(_ offsets: IndexSet) {
        Haptics.impact(.rigid)
        offsets.map { items[$0] }.forEach { context.delete($0) }
        try? context.save()
    }

    private func remove(_ item: WatchItem) {
        Haptics.impact(.rigid)
        context.delete(item)
        try? context.save()
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star").font(.system(size: 54)).foregroundStyle(Theme.inkFaint)
            Text("\(group.name) is empty").font(.system(size: 22, weight: .semibold)).foregroundStyle(Theme.ink)
            Text("Add tickers you're tracking to keep an eye on prices and get AI analysis.")
                .font(.system(size: 15)).foregroundStyle(Theme.inkDim).multilineTextAlignment(.center)
            Button { showAdd = true } label: {
                Text("Add ticker")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 20).padding(.vertical, 8)
            }.buttonStyle(.glassProminent).padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
}

#Preview {
    ZStack {
        VaultBackground(performance: 0.3)
        NavigationStack {
            WatchlistGroupDetailView(group: WatchlistGroup(name: "Tech"), viewModel: PaperTradingViewModel())
                .environment(AppSettings())
        }
    }
    .modelContainer(MockData.previewContainer())
    .preferredColorScheme(.dark)
}
