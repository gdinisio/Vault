//
//  WatchItem.swift
//  Vault
//
//  A ticker the user is watching but doesn't own. Persisted with SwiftData.
//

import Foundation
import SwiftData

@Model
final class WatchItem {
    @Attribute(.unique) var id: UUID
    var ticker: String
    var companyName: String
    var sector: String
    var addedDate: Date

    init(id: UUID = UUID(),
         ticker: String,
         companyName: String,
         sector: String = "Technology",
         addedDate: Date = .now) {
        self.id = id
        self.ticker = ticker
        self.companyName = companyName
        self.sector = sector
        self.addedDate = addedDate
    }
}
