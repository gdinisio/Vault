//
//  NewsSection.swift
//  Vault
//
//  Recent company headlines for a ticker, shared by every detail view
//  (search, holding, paper position, watchlist). Loads best-effort from
//  Finnhub (needs a key); shows tidy loading / empty states otherwise.
//  Each item links out to the full article.
//

import SwiftUI

struct NewsSection: View {
    let symbol: String

    @State private var items: [CompanyNews] = []
    @State private var state: LoadState = .loading

    private enum LoadState { case loading, loaded, unavailable }

    /// Cap to keep the page glanceable; the chart is the headline act.
    private var shown: [CompanyNews] { Array(items.prefix(8)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("News")
                .font(.title3.weight(.semibold))
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
                .font(.subheadline).foregroundStyle(Theme.inkDim)
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
                .font(.subheadline).foregroundStyle(Theme.inkDim)
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
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(item.source)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.inkDim)
                    Text("·").font(.caption).foregroundStyle(Theme.inkFaint)
                    Text(item.date.formatted(.relative(presentation: .named)))
                        .font(.caption.monospacedDigit())
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
