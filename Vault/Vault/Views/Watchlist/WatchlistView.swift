//
//  WatchlistView.swift
//  Vault
//
//  The Watchlist tab: tickers you're tracking but don't own.
//

import SwiftUI
import SwiftData

struct WatchlistView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: \WatchItem.addedDate, order: .reverse) private var items: [WatchItem]

    var onOpenSettings: () -> Void

    @State private var showAdd = false
    @State private var selected: WatchItem?

    private var currency: DisplayCurrency {
        _ = settings.fxToken
        return settings.displayCurrency
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if items.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .padding(.horizontal, 52)
        .padding(.top, 38)
        .padding(.bottom, 24)
        .id(settings.fxToken)
        .sheet(isPresented: $showAdd) {
            AddWatchView(existing: items.map(\.ticker)) { item in
                context.insert(item)
                try? context.save()
            }
        }
        .sheet(item: $selected) { item in
            WatchDetailView(item: item, currency: currency)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Watchlist").font(.system(size: 28, weight: .semibold)).foregroundStyle(Theme.ink)
                Text("Tickers you're tracking · \(currency.rawValue)").font(.system(size: 14)).foregroundStyle(Theme.inkDim)
            }
            Spacer()
            HStack(spacing: 12) {
                HeaderButton(systemImage: "gearshape", action: onOpenSettings)
                Button { showAdd = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(size: 16, weight: .bold))
                        Text("Add ticker").font(.system(size: 15.5, weight: .semibold))
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .background(Capsule().fill(Theme.line.opacity(0.10)).overlay(Capsule().strokeBorder(Theme.line.opacity(0.14), lineWidth: 0.5)))
                }.buttonStyle(.plain)
            }
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Watching").font(.system(size: 21, weight: .semibold)).foregroundStyle(Theme.ink)
                Spacer()
                Text("\(items.count) tickers").font(.system(size: 14, design: .monospaced)).foregroundStyle(Theme.inkDim)
            }
            .padding(.horizontal, 4).padding(.top, 24).padding(.bottom, 14)

            List {
                ForEach(items) { item in
                    WatchRowView(item: item, currency: currency)
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .contentShape(Rectangle())
                        .onTapGesture { selected = item }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Haptics.impact(.rigid)
                                context.delete(item)
                                try? context.save()
                            } label: { Label("Remove", systemImage: "trash") }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star").font(.system(size: 54)).foregroundStyle(Theme.inkFaint)
            Text("Your watchlist is empty").font(.system(size: 22, weight: .semibold)).foregroundStyle(Theme.ink)
            Text("Track tickers you're considering — see live charts and get an AI read before you buy.")
                .font(.system(size: 15)).foregroundStyle(Theme.inkDim).multilineTextAlignment(.center)
            Button { showAdd = true } label: {
                Text("Add ticker").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.onButton)
                    .padding(.horizontal, 28).padding(.vertical, 14).background(Capsule().fill(Theme.accentButton))
            }.buttonStyle(.plain).padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview(traits: .landscapeLeft) {
    ZStack {
        VaultBackground(performance: 0.3)
        WatchlistView(onOpenSettings: {})
            .environment(AppSettings())
    }
    .modelContainer(MockData.previewContainer())
    .preferredColorScheme(.dark)
}
