//
//  Holding.swift
//  Vault
//
//  A real-money portfolio holding, persisted with SwiftData.
//

import Foundation
import SwiftData

@Model
final class Holding {
    @Attribute(.unique) var id: UUID
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
    /// True when the last price fetch failed and we're showing a stale value.
    var isStale: Bool

    init(
        id: UUID = UUID(),
        ticker: String,
        companyName: String,
        sector: String = "Technology",
        shares: Double,
        purchasePricePerShare: Double,
        purchaseDate: Date = .now,
        fxCharge: Double = 0,
        brokerFee: Double = 0,
        currentPrice: Double = 0,
        lastUpdated: Date = .now,
        isStale: Bool = false
    ) {
        self.id = id
        self.ticker = ticker
        self.companyName = companyName
        self.sector = sector
        self.shares = shares
        self.purchasePricePerShare = purchasePricePerShare
        self.purchaseDate = purchaseDate
        self.fxCharge = fxCharge
        self.brokerFee = brokerFee
        self.currentPrice = currentPrice
        self.lastUpdated = lastUpdated
        self.isStale = isStale
    }
}

// MARK: - Derived metrics

extension Holding {
    /// Total cost basis: shares × purchase price + FX charge + broker fee.
    var costBasis: Double {
        shares * purchasePricePerShare + fxCharge + brokerFee
    }

    /// Current market value of the position.
    var currentValue: Double {
        shares * currentPrice
    }

    /// Absolute profit/loss against full cost basis.
    var profitLoss: Double {
        currentValue - costBasis
    }

    /// Percentage return on cost basis.
    var returnPercent: Double {
        guard costBasis > 0 else { return 0 }
        return profitLoss / costBasis * 100
    }

    /// Annualised (CAGR) return based on holding period.
    var annualisedReturn: Double {
        guard costBasis > 0, currentValue > 0 else { return 0 }
        let years = max(Date.now.timeIntervalSince(purchaseDate) / (365.25 * 24 * 3600), 1.0 / 365.0)
        let growth = currentValue / costBasis
        return (pow(growth, 1.0 / years) - 1) * 100
    }
}
