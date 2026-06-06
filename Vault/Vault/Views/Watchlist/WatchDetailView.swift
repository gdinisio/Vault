//
//  WatchDetailView.swift
//  Vault
//
//  Detail for a watched ticker: real price chart + AI decision-support.
//

import SwiftUI
import SwiftData

struct WatchDetailView: View {
    let item: WatchItem
    var currency: DisplayCurrency = .gbp

    @State private var latestClose: Double = 0
    @State private var showAnalysis = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                PriceChartView(symbol: item.ticker, sector: item.sector, currency: currency)
                analyseButton
            }
            .padding(28)
        }
        .background(Theme.bgDeep.opacity(0.001))
        .navigationTitle(item.ticker)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAnalysis) {
            StockAnalysisView(
                snapshot: StockSnapshot(ticker: item.ticker, companyName: item.companyName, sector: item.sector,
                                        shares: 0, averageCost: 0, currentPrice: latestClose, returnPercent: 0),
                currency: currency
            )
        }
        .task {
            if let history = try? await PriceHistoryService.shared.history(for: item.ticker, range: .month),
               let last = history.last?.close {
                latestClose = last
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            TickerMark(ticker: item.ticker, sector: item.sector, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.ticker).font(.system(size: 26, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(item.companyName).font(.system(size: 15)).foregroundStyle(Theme.inkDim)
            }
            Spacer()
        }
    }

    private var analyseButton: some View {
        Button { Haptics.impact(.light); showAnalysis = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").foregroundStyle(Theme.aiPurple)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Analyse with AI").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text("News-driven read on \(item.ticker) — is it worth buying?")
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

#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        WatchDetailView(item: MockData.watchlist[0])
    }
    .modelContainer(MockData.previewContainer())
}
