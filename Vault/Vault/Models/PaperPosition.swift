//
//  PaperPosition.swift
//  Vault
//
//  An open paper-trading position, persisted with SwiftData.
//

import Foundation
import SwiftData

@Model
final class PaperPosition {
    @Attribute(.unique) var id: UUID
    var ticker: String
    var companyName: String
    var sector: String
    var shares: Double
    var averageCost: Double
    var currentPrice: Double
    var lastUpdated: Date
    var isStale: Bool

    init(
        id: UUID = UUID(),
        ticker: String,
        companyName: String,
        sector: String = "Technology",
        shares: Double,
        averageCost: Double,
        currentPrice: Double = 0,
        lastUpdated: Date = .now,
        isStale: Bool = false
    ) {
        self.id = id
        self.ticker = ticker
        self.companyName = companyName
        self.sector = sector
        self.shares = shares
        self.averageCost = averageCost
        self.currentPrice = currentPrice
        self.lastUpdated = lastUpdated
        self.isStale = isStale
    }
}

// MARK: - Derived metrics

extension PaperPosition {
    var costBasis: Double { shares * averageCost }
    var currentValue: Double { shares * currentPrice }
    /// P&L = (current price − average cost) × shares.
    var profitLoss: Double { (currentPrice - averageCost) * shares }
    var returnPercent: Double {
        guard costBasis > 0 else { return 0 }
        return profitLoss / costBasis * 100
    }
}
