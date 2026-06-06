//
//  WatchlistGroupDetailView.swift
//  Vault
//
//  Shows all tickers in a named watchlist. Tapping a row pushes WatchDetailView.
//

import SwiftUI
import SwiftData

struct WatchlistGroupDetailView: View {
    let group: WatchlistGroup

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @Query private var items: [WatchItem]

    @State private var showAdd = false
    @State private var editMode: EditMode = .inactive

    init(group: WatchlistGroup) {
        self.group = group
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
        ToolbarItem(placement: .topBarLeading) {
            if !items.isEmpty {
                Button {
                    withAnimation { editMode = editMode == .active ? .inactive : .active }
                } label: {
                    Image(systemName: editMode == .active ? "checkmark" : "pencil")
                }
            }
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
                WatchRowView(item: item, currency: currency)
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .overlay { NavigationLink(value: item) { Color.clear } }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Haptics.impact(.rigid)
                            context.delete(item)
                            try? context.save()
                        } label: { Label("Remove", systemImage: "trash") }
                    }
            }
            .onDelete(perform: delete)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
    }

    private func delete(at offsets: IndexSet) {
        Haptics.impact(.rigid)
        for index in offsets {
            context.delete(items[index])
        }
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
            WatchlistGroupDetailView(group: WatchlistGroup(name: "Tech"))
                .environment(AppSettings())
        }
    }
    .modelContainer(MockData.previewContainer())
    .preferredColorScheme(.dark)
}
