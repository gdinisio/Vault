//
//  WatchlistsView.swift
//  Vault
//
//  Top-level "Watchlists" tab: shows all named watchlists as cards.
//  Tapping a card pushes WatchlistGroupDetailView with that group's tickers.
//

import SwiftUI
import SwiftData

struct WatchlistsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @Query(sort: \WatchlistGroup.sortIndex) private var groups: [WatchlistGroup]
    @Query private var allItems: [WatchItem]

    @State private var showNewGroup = false
    @State private var newGroupName = ""
    @State private var editMode: EditMode = .inactive

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if groups.isEmpty {
                    emptyState
                } else {
                    ForEach(groups) { group in
                        let groupItems = allItems.filter { $0.listName == group.name }
                        if editMode == .active {
                            HStack(spacing: 12) {
                                Button(role: .destructive) {
                                    deleteGroup(group)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Theme.loss)
                                }
                                .buttonStyle(.plain)
                                groupCard(group: group, items: groupItems)
                            }
                        } else {
                            NavigationLink(value: group) {
                                groupCard(group: group, items: groupItems)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteGroup(group)
                                } label: {
                                    Label("Delete Watchlist", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .vaultPagePadding()
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Watchlists")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .alert("New Watchlist", isPresented: $showNewGroup) {
            TextField("Name (e.g. Tech, Growth…)", text: $newGroupName)
                .autocorrectionDisabled()
            Button("Create") { createGroup() }
                .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) { newGroupName = "" }
        }
        .onAppear { ensureDefaultGroup() }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if !groups.isEmpty {
                Button {
                    withAnimation { editMode = editMode == .active ? .inactive : .active }
                } label: {
                    Image(systemName: editMode == .active ? "checkmark" : "pencil")
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showNewGroup = true } label: {
                Image(systemName: "plus")
            }
        }
    }

    // MARK: Group card

    private func groupCard(group: WatchlistGroup, items: [WatchItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(items.count == 1 ? "1 ticker" : "\(items.count) tickers")
                        .font(.caption)
                        .foregroundStyle(Theme.inkDim)
                        .monospacedDigit()
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkFaint)
            }

            if items.isEmpty {
                Text("No tickers yet — tap to add some")
                    .font(.caption)
                    .foregroundStyle(Theme.inkFaint)
            } else {
                HStack(spacing: 6) {
                    ForEach(items.prefix(5)) { item in
                        TickerMark(ticker: item.ticker, sector: item.sector, size: 34)
                    }
                    if items.count > 5 {
                        Text("+\(items.count - 5)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Theme.inkDim)
                            .padding(.leading, 2)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard(cornerRadius: 20)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star").font(.system(size: 54)).foregroundStyle(Theme.inkFaint)
            Text("No watchlists yet").font(.system(size: 22, weight: .semibold)).foregroundStyle(Theme.ink)
            Text("Create a named watchlist and fill it with tickers to track.")
                .font(.system(size: 15)).foregroundStyle(Theme.inkDim).multilineTextAlignment(.center)
            Button { showNewGroup = true } label: {
                Text("Create watchlist")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 20)
            }
            .buttonStyle(.glassProminent).padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    // MARK: Actions

    private func ensureDefaultGroup() {
        guard groups.isEmpty else { return }
        let defaultGroup = WatchlistGroup(name: "Watchlist", sortIndex: 0)
        context.insert(defaultGroup)
        try? context.save()
    }

    private func createGroup() {
        let trimmed = newGroupName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let group = WatchlistGroup(name: trimmed, sortIndex: groups.count)
        context.insert(group)
        try? context.save()
        newGroupName = ""
        Haptics.success()
    }

    private func deleteGroup(_ group: WatchlistGroup) {
        let itemsToDelete = allItems.filter { $0.listName == group.name }
        itemsToDelete.forEach { context.delete($0) }
        context.delete(group)
        try? context.save()
        Haptics.impact(.rigid)
    }
}

#Preview(traits: .landscapeLeft) {
    ZStack {
        VaultBackground(performance: 0.3)
        NavigationStack {
            WatchlistsView()
                .environment(AppSettings())
        }
    }
    .modelContainer(MockData.previewContainer())
    .preferredColorScheme(.dark)
}
