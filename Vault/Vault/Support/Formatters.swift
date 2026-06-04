//
//  Formatters.swift
//  Vault
//
//  Currency / percent formatting. The app stores all monetary values in a
//  single base currency (USD — what Finnhub/Stooq quote in). `Money` converts
//  to the chosen display currency at format time using a live FX rate.
//

import Foundation

nonisolated enum DisplayCurrency: String, CaseIterable, Codable {
    case gbp = "GBP"
    case usd = "USD"

    var symbol: String { self == .gbp ? "£" : "$" }
}

enum Money {
    /// Live FX rates relative to the base currency (USD). Updated by FXService.
    /// Read on the main thread during view rendering and written on the main
    /// thread after a fetch.
    nonisolated(unsafe) static var rates: [DisplayCurrency: Double] = [.usd: 1.0, .gbp: 0.79]

    static func rate(_ currency: DisplayCurrency) -> Double { rates[currency] ?? 1 }

    /// Convert a base-currency (USD) amount into the display currency.
    static func convert(_ usd: Double, to currency: DisplayCurrency) -> Double {
        usd * rate(currency)
    }

    /// Convert a display-currency amount back into base currency (USD).
    static func toBase(_ amount: Double, from currency: DisplayCurrency) -> Double {
        let r = rate(currency)
        return r == 0 ? amount : amount / r
    }

    /// Currency with grouping, e.g. "£14,962.50".
    static func currency(_ usd: Double, currency: DisplayCurrency = .gbp, fractionDigits: Int = 2) -> String {
        currency.symbol + number(convert(usd, to: currency), fractionDigits: fractionDigits)
    }

    /// Rounded, no decimals: "£14,963".
    static func currency0(_ usd: Double, currency: DisplayCurrency = .gbp) -> String {
        currency.symbol + number(convert(usd, to: currency).rounded(), fractionDigits: 0)
    }

    /// Signed currency: "+£1,399.50" / "−£415.50". Uses the proper minus glyph.
    static func signed(_ usd: Double, currency: DisplayCurrency = .gbp, fractionDigits: Int = 2) -> String {
        let value = convert(usd, to: currency)
        let sign = value >= 0 ? "+\(currency.symbol)" : "−\(currency.symbol)"
        return sign + number(abs(value), fractionDigits: fractionDigits)
    }

    /// Format a value that is ALREADY in the given currency (no FX conversion).
    /// Used by entry forms where the user types amounts in a chosen currency.
    static func literal(_ value: Double, currency: DisplayCurrency, fractionDigits: Int = 2) -> String {
        currency.symbol + number(value, fractionDigits: fractionDigits)
    }

    /// Signed percent: "+13.9%" / "−11.4%". (Ratios — no FX conversion.)
    static func percent(_ value: Double, fractionDigits: Int = 1) -> String {
        let sign = value >= 0 ? "+" : "−"
        return sign + String(format: "%.\(fractionDigits)f", abs(value)) + "%"
    }

    private static func number(_ value: Double, fractionDigits: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_GB")
        f.minimumFractionDigits = fractionDigits
        f.maximumFractionDigits = fractionDigits
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.\(fractionDigits)f", value)
    }
}
