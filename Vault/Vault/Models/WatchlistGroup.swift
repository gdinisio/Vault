//
//  WatchlistGroup.swift
//  Vault
//
//  A named watchlist that groups WatchItems together. Items are associated
//  via their `listName` string property to avoid SwiftData relationship
//  migration complexity.
//

import Foundation
import SwiftData

@Model
final class WatchlistGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var sortIndex: Int
    var createdDate: Date

    init(name: String, sortIndex: Int = 0) {
        self.id = UUID()
        self.name = name
        self.sortIndex = sortIndex
        self.createdDate = .now
    }
}
