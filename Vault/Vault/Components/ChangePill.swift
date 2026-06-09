//
//  ChangePill.swift
//  Vault
//
//  Apple Stocks–style filled pill showing a change figure (% or signed value),
//  tinted by direction. Shared across the search, portfolio, paper and watch rows.
//

import SwiftUI

struct ChangePill: View {
    let text: String
    var color: Color = Theme.gain

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule(style: .continuous).fill(color))
            .contentTransition(.numericText())
    }
}
