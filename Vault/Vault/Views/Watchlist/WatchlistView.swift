//
//  WatchlistsView.swift
//  Vault
//
//  Top-level "Watchlists" tab: shows all named watchlists as cards.
//  Tapping a card pushes WatchlistGroupDetailView with that group's tickers.
//  Deletion uses the native List affordances — swipe-to-delete and the
//  edit-mode red minus → slide → Delete confirmation (`.onDelete`).
//

import SwiftUI
import SwiftData

struct WatchlistsView: View {
    let viewModel: PaperTradingViewModel

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @Query(sort: \WatchlistGroup.sortIndex) private var groups: [WatchlistGroup]
    @Query private var allItems: [WatchItem]

    @State private var showNewGroup = false
    @State private var newGroupName = ""
    @State private var editMode: EditMode = .inactive
    @State private var navGroup: WatchlistGroup?

    var body: some View {
        Group {
            if groups.isEmpty {
                emptyState
                    .vaultPagePadding()
            } else {
                groupList
            }
        }
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .environment(\.editMode, $editMode)
        .navigationTitle("Watchlists")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        // Button + item destination (not NavigationLink) so the rows carry no
        // disclosure chevron — matches the ticker rows in the detail view.
        .navigationDestination(item: $navGroup) { group in
            WatchlistGroupDetailView(group: group, viewModel: viewModel)
        }
        .alert("New Watchlist", isPresented: $showNewGroup) {
            TextField("Name (e.g. Tech, Growth…)", text: $newGroupName)
                .autocorrectionDisabled()
            Button("Create") { createGroup() }
                .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) { newGroupName = "" }
        }
        .onAppear { ensureDefaultGroup() }
    }

    // MARK: List

    /// One pass over all items per render instead of a filter per row.
    private var itemsByList: [String: [WatchItem]] {
        Dictionary(grouping: allItems, by: \.listName)
    }

    private var groupList: some View {
        let itemsByList = self.itemsByList
        return List {
            ForEach(groups) { group in
                let groupItems = itemsByList[group.name] ?? []
                Button { navGroup = group } label: {
                    groupCard(group: group, items: groupItems)
                }
                .buttonStyle(PressableRowStyle(cornerRadius: 0))
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { deleteGroup(group) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        deleteGroup(group)
                    } label: {
                        Label("Delete Watchlist", systemImage: "trash")
                    }
                }
            }
            .onDelete(perform: deleteAt)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Edit + add live on the trailing side in both this view and its
        // pushed detail view, so they keep the same anchor when the back
        // button claims the leading slot.
        if !groups.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation { editMode = editMode == .active ? .inactive : .active }
                } label: {
                    Image(systemName: editMode == .active ? "checkmark" : "pencil")
                }
                .accessibilityLabel(editMode == .active ? "Done" : "Edit watchlists")
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showNewGroup = true } label: {
                Image(systemName: "rectangle.stack.badge.plus")
            }
            .accessibilityLabel("New watchlist")
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
            }

            if items.isEmpty {
                Text("No tickers yet — tap to add some")
                    .font(.caption)
                    .foregroundStyle(Theme.inkFaint)
            } else {
                WatchlistGroupPreview(items: items)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star").font(.system(size: 54)).foregroundStyle(Theme.inkFaint)
            Text("No watchlists yet").font(.title2.weight(.semibold)).foregroundStyle(Theme.ink)
            Text("Create a named watchlist and fill it with tickers to track.")
                .font(.subheadline).foregroundStyle(Theme.inkDim).multilineTextAlignment(.center)
            Button { showNewGroup = true } label: {
                Text("Create watchlist")
                    .font(.body.weight(.semibold))
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

    private func deleteAt(_ offsets: IndexSet) {
        Haptics.impact(.rigid)
        offsets.map { groups[$0] }.forEach { deleteGroupCascade($0) }
        try? context.save()
    }

    private func deleteGroup(_ group: WatchlistGroup) {
        Haptics.impact(.rigid)
        deleteGroupCascade(group)
        try? context.save()
    }

    private func deleteGroupCascade(_ group: WatchlistGroup) {
        let itemsToDelete = allItems.filter { $0.listName == group.name }
        itemsToDelete.forEach { context.delete($0) }
        context.delete(group)
    }
}

// MARK: - Group preview (per-ticker change chips)

/// A glanceable preview for a watchlist card: each visible ticker with its
/// own %P/L, plus a `+N` overflow.
private struct WatchlistGroupPreview: View {
    let items: [WatchItem]

    private var shown: [WatchItem] { Array(items.prefix(4)) }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                TickerChangeChip(ticker: item.ticker)
                if index < shown.count - 1 {
                    Text("·").font(.caption).foregroundStyle(Theme.inkFaint)
                }
            }
            if items.count > 4 {
                Text("·").font(.caption).foregroundStyle(Theme.inkFaint)
                Text("+\(items.count - 4)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.inkFaint)
            }
            Spacer(minLength: 0)
        }
        .lineLimit(1)
    }
}

/// A single ticker code + its live 1-month % change.
private struct TickerChangeChip: View {
    let ticker: String
    @State private var change: Double?

    var body: some View {
        HStack(spacing: 4) {
            Text(ticker)
                .font(.caption.weight(.semibold).monospaced())
                .foregroundStyle(Theme.ink)
            if let change {
                Text(Money.percent(change))
                    .font(.caption2.weight(.semibold).monospaced())
                    .foregroundStyle(change >= 0 ? Theme.gain : Theme.loss)
            }
        }
        .task(id: ticker) {
            if let history = try? await PriceHistoryService.shared.history(for: ticker, range: .month),
               let first = history.first?.close, let last = history.last?.close, first != 0 {
                change = (last - first) / first * 100
            }
        }
    }
}

#Preview(traits: .landscapeLeft) {
    ZStack {
        VaultBackground(performance: 0.3)
        NavigationStack {
            WatchlistsView(viewModel: PaperTradingViewModel())
                .environment(AppSettings())
        }
    }
    .modelContainer(MockData.previewContainer())
    .preferredColorScheme(.dark)
}
