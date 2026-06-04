//
//  Stepper.swift
//  Vault
//
//  Quantity stepper used in the Buy/Sell sheets: −  [value]  +
//

import SwiftUI

struct QuantityStepper: View {
    @Binding var value: Int
    var step: Int = 10
    var min: Int = 1

    var body: some View {
        HStack(spacing: 12) {
            button("minus") { value = Swift.max(min, value - step) }
            TextField("", value: $value, format: .number)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.line.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line.opacity(0.12), lineWidth: 0.5))
                )
            button("plus") { value += step }
        }
    }

    private func button(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Theme.line.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Theme.line.opacity(0.14), lineWidth: 0.5))
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuantityStepper(value: .constant(50))
        .padding(40)
        .background(Theme.bgDeep)
}
