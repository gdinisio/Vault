//
//  PressableRowStyle.swift
//  Vault
//
//  A button style for tappable list rows that gives immediate, tactile press
//  feedback — a neutral selection fill plus a subtle scale — so the user feels
//  confirmed in what they're tapping before navigation occurs.
//

import SwiftUI

struct PressableRowStyle: ButtonStyle {
    var cornerRadius: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.surfaceSelected)
                    .opacity(configuration.isPressed ? 1 : 0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
