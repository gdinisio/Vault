//
//  TickerMark.swift
//  Vault
//
//  Rounded glassy square showing a ticker symbol, tinted by sector hue.
//

import SwiftUI

struct TickerMark: View {
    let ticker: String
    var sector: String = "Technology"
    var size: CGFloat = 48

    private var hue: Double { Theme.sectorHue(sector) }

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.oklch(0.55, 0.13, hue, alpha: 0.55),
                        Color.oklch(0.40, 0.10, hue, alpha: 0.22)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                    .strokeBorder(Color.oklch(0.70, 0.12, hue, alpha: 0.40), lineWidth: 1)
            }
            .overlay {
                Text(String(ticker.prefix(4)))
                    .font(.system(size: size * 0.30, weight: .semibold, design: .monospaced))
                    .tracking(-0.5)
                    .foregroundStyle(Color.oklch(0.92, 0.05, hue))
            }
            .frame(width: size, height: size)
            .shadow(color: Color.oklch(0.50, 0.15, hue, alpha: 0.5), radius: 8, x: 0, y: 6)
    }
}

#Preview {
    HStack(spacing: 16) {
        TickerMark(ticker: "VOO", sector: "Index Fund")
        TickerMark(ticker: "AAPL", sector: "Technology")
        TickerMark(ticker: "TSLA", sector: "Consumer")
        TickerMark(ticker: "LLY", sector: "Healthcare")
    }
    .padding(40)
    .background(Theme.bgDeep)
}
