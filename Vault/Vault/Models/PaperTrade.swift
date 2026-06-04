//
//  PaperTrade.swift
//  Vault
//
//  An executed paper trade (buy or sell), persisted with SwiftData.
//

import Foundation
import SwiftData

enum TradeType: String, Codable {
    case buy = "BUY"
    case sell = "SELL"
}

@Model
final class PaperTrade {
    @Attribute(.unique) var id: UUID
    var ticker: String
    var shares: Double
    var price: Double
    /// Stored as raw string for SwiftData compatibility; access via `type`.
    var typeRaw: String
    var timestamp: Date

    var type: TradeType {
        get { TradeType(rawValue: typeRaw) ?? .buy }
        set { typeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        ticker: String,
        shares: Double,
        price: Double,
        type: TradeType,
        timestamp: Date = .now
    ) {
        self.id = id
        self.ticker = ticker
        self.shares = shares
        self.price = price
        self.typeRaw = type.rawValue
        self.timestamp = timestamp
    }
}

extension PaperTrade {
    /// Signed cash impact: negative for buys (cash out), positive for sells.
    var cashImpact: Double {
        let gross = shares * price
        return type == .buy ? -gross : gross
    }
}
