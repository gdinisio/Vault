//
//  FXService.swift
//  Vault
//
//  Fetches live foreign-exchange rates relative to USD (the app's base
//  currency) so values can be shown accurately in GBP or USD. Uses a free,
//  key-less endpoint (open.er-api.com).
//

import Foundation

actor FXService {
    static let shared = FXService()

    private let url = URL(string: "https://open.er-api.com/v6/latest/USD")
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private struct Response: Decodable {
        let result: String
        let rates: [String: Double]
    }

    /// Returns USD→currency rates for the app's display currencies, or nil on
    /// failure (callers keep the last-known/default rates).
    func fetchRates() async -> [DisplayCurrency: Double]? {
        guard let url else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            guard decoded.result == "success" else { return nil }
            var out: [DisplayCurrency: Double] = [.usd: 1.0]
            if let gbp = decoded.rates["GBP"] { out[.gbp] = gbp }
            return out
        } catch {
            return nil
        }
    }
}
