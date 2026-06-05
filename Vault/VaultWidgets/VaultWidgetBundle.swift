//
//  VaultWidgetBundle.swift
//  VaultWidgets
//
//  Entry point for the widget extension — registers all four widgets.
//

import WidgetKit
import SwiftUI

@main
struct VaultWidgetBundle: WidgetBundle {
    var body: some Widget {
        PortfolioSummaryWidget()
        PaperSummaryWidget()
        SingleTickerWidget()
        WatchlistWidget()
    }
}
