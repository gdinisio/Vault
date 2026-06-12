//
//  BackupService.swift
//  Vault
//
//  Manual backup: serialise the full app state — holdings, paper positions,
//  trades, watchlists and watchlist groups, plus cash, starting cash and the
//  display-currency setting — to a JSON file the user can save into Files /
//  iCloud Drive, and restore it later. Works on a free Apple account: no
//  iCloud entitlement needed, because the user picks the destination via the
//  system document picker.
//
//  API keys are deliberately NOT included — they live in the Keychain and must
//  never leave the device inside a plain-text backup file.
//

import Foundation
import SwiftData
import UniformTypeIdentifiers
import SwiftUI

// MARK: - Codable snapshot

struct VaultBackup: Codable {
    /// Bumped to 2 when watchlists were added. The watch arrays are optional so
    /// older v1 files (which lack them) still decode — a missing optional key
    /// decodes to nil rather than throwing.
    var version: Int = 2
    var exportedAt: Date = .now
    var cash: Double
    var startingCash: Double
    var currency: String
    var holdings: [HoldingDTO]
    var positions: [PositionDTO]
    var trades: [TradeDTO]
    var watchItems: [WatchItemDTO]? = nil   // v2+
    var watchlists: [WatchlistDTO]? = nil   // v2+

    struct HoldingDTO: Codable {
        var id: UUID
        var ticker: String
        var companyName: String
        var sector: String
        var shares: Double
        var purchasePricePerShare: Double
        var purchaseDate: Date
        var fxCharge: Double
        var brokerFee: Double
        var currentPrice: Double
        var lastUpdated: Date
    }

    struct PositionDTO: Codable {
        var id: UUID
        var ticker: String
        var companyName: String
        var sector: String
        var shares: Double
        var averageCost: Double
        var currentPrice: Double
        var lastUpdated: Date
    }

    struct TradeDTO: Codable {
        var id: UUID
        var ticker: String
        var shares: Double
        var price: Double
        var type: String
        var timestamp: Date
    }

    struct WatchItemDTO: Codable {
        var id: UUID
        var ticker: String
        var companyName: String
        var sector: String
        var addedDate: Date
        var listName: String
    }

    struct WatchlistDTO: Codable {
        var id: UUID
        var name: String
        var sortIndex: Int
        var createdDate: Date
    }
}

// MARK: - Service

enum BackupService {

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    struct Counts { var holdings = 0; var positions = 0; var trades = 0; var watchItems = 0 }

    /// Build a JSON snapshot of everything currently stored.
    @MainActor
    static func makeBackupData(context: ModelContext, settings: AppSettings, cash: Double) throws -> Data {
        let holdings   = (try? context.fetch(FetchDescriptor<Holding>())) ?? []
        let positions  = (try? context.fetch(FetchDescriptor<PaperPosition>())) ?? []
        let trades     = (try? context.fetch(FetchDescriptor<PaperTrade>())) ?? []
        let watchItems = (try? context.fetch(FetchDescriptor<WatchItem>())) ?? []
        let watchlists = (try? context.fetch(FetchDescriptor<WatchlistGroup>())) ?? []

        let backup = VaultBackup(
            cash: cash,
            startingCash: settings.startingPaperCash,
            currency: settings.displayCurrency.rawValue,
            holdings: holdings.map {
                .init(id: $0.id, ticker: $0.ticker, companyName: $0.companyName, sector: $0.sector,
                      shares: $0.shares, purchasePricePerShare: $0.purchasePricePerShare,
                      purchaseDate: $0.purchaseDate, fxCharge: $0.fxCharge, brokerFee: $0.brokerFee,
                      currentPrice: $0.currentPrice, lastUpdated: $0.lastUpdated)
            },
            positions: positions.map {
                .init(id: $0.id, ticker: $0.ticker, companyName: $0.companyName, sector: $0.sector,
                      shares: $0.shares, averageCost: $0.averageCost,
                      currentPrice: $0.currentPrice, lastUpdated: $0.lastUpdated)
            },
            trades: trades.map {
                .init(id: $0.id, ticker: $0.ticker, shares: $0.shares, price: $0.price,
                      type: $0.typeRaw, timestamp: $0.timestamp)
            },
            watchItems: watchItems.map {
                .init(id: $0.id, ticker: $0.ticker, companyName: $0.companyName, sector: $0.sector,
                      addedDate: $0.addedDate, listName: $0.listName)
            },
            watchlists: watchlists.map {
                .init(id: $0.id, name: $0.name, sortIndex: $0.sortIndex, createdDate: $0.createdDate)
            }
        )
        return try encoder.encode(backup)
    }

    /// Replace all stored data with the contents of a backup file.
    @MainActor
    @discardableResult
    static func restore(from data: Data, into context: ModelContext,
                        settings: AppSettings, paperVM: PaperTradingViewModel) throws -> Counts {
        let backup = try decoder.decode(VaultBackup.self, from: data)
        let watchItems = backup.watchItems ?? []
        let watchlists = backup.watchlists ?? []

        // Wipe existing data first.
        try context.delete(model: Holding.self)
        try context.delete(model: PaperPosition.self)
        try context.delete(model: PaperTrade.self)
        try context.delete(model: WatchItem.self)
        try context.delete(model: WatchlistGroup.self)

        for h in backup.holdings {
            context.insert(Holding(id: h.id, ticker: h.ticker, companyName: h.companyName, sector: h.sector,
                                   shares: h.shares, purchasePricePerShare: h.purchasePricePerShare,
                                   purchaseDate: h.purchaseDate, fxCharge: h.fxCharge, brokerFee: h.brokerFee,
                                   currentPrice: h.currentPrice, lastUpdated: h.lastUpdated))
        }
        for p in backup.positions {
            context.insert(PaperPosition(id: p.id, ticker: p.ticker, companyName: p.companyName, sector: p.sector,
                                         shares: p.shares, averageCost: p.averageCost,
                                         currentPrice: p.currentPrice, lastUpdated: p.lastUpdated))
        }
        for t in backup.trades {
            context.insert(PaperTrade(id: t.id, ticker: t.ticker, shares: t.shares, price: t.price,
                                      type: TradeType(rawValue: t.type) ?? .buy, timestamp: t.timestamp))
        }
        for w in watchItems {
            context.insert(WatchItem(id: w.id, ticker: w.ticker, companyName: w.companyName,
                                     sector: w.sector, addedDate: w.addedDate, listName: w.listName))
        }
        for g in watchlists {
            // WatchlistGroup's init mints a fresh id/date; assign the backed-up
            // values afterwards so groups round-trip exactly.
            let group = WatchlistGroup(name: g.name, sortIndex: g.sortIndex)
            group.id = g.id
            group.createdDate = g.createdDate
            context.insert(group)
        }
        try context.save()

        // Restore cash + currency.
        settings.startingPaperCash = backup.startingCash
        if let currency = DisplayCurrency(rawValue: backup.currency) {
            settings.displayCurrency = currency
        }
        paperVM.resetCash(to: backup.cash)

        return Counts(holdings: backup.holdings.count,
                      positions: backup.positions.count,
                      trades: backup.trades.count,
                      watchItems: watchItems.count)
    }

    static var suggestedFilename: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "vault-backup-\(f.string(from: .now))"
    }
}

// MARK: - FileDocument for .fileExporter

struct VaultBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
