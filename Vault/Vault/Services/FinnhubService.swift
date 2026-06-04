//
//  FinnhubService.swift
//  Vault
//
//  async/await URLSession wrapper around the Finnhub REST API for live price
//  quotes and symbol search. The API key is read from the Keychain.
//

import Foundation

// MARK: - DTOs

/// /quote response. `c` = current, `pc` = previous close, etc.
nonisolated struct FinnhubQuote: Decodable {
    let c: Double   // current price
    let d: Double?  // change
    let dp: Double? // percent change
    let pc: Double  // previous close
}

/// /search response.
nonisolated struct FinnhubSearchResponse: Decodable {
    let result: [FinnhubSymbol]
}

nonisolated struct FinnhubSymbol: Decodable, Identifiable, Hashable {
    let symbol: String
    let description: String
    let type: String
    var id: String { symbol }
}

/// /company-news item.
nonisolated struct CompanyNews: Decodable, Identifiable, Hashable {
    let id: Int
    let headline: String
    let summary: String
    let source: String
    let url: String
    let datetime: TimeInterval

    var date: Date { Date(timeIntervalSince1970: datetime) }
}

/// /stock/recommendation trend (one period).
nonisolated struct RecommendationTrend: Decodable, Hashable {
    let period: String
    let strongBuy: Int
    let buy: Int
    let hold: Int
    let sell: Int
    let strongSell: Int

    var totalBuy: Int { strongBuy + buy }
    var totalSell: Int { sell + strongSell }
    var total: Int { totalBuy + hold + totalSell }

    /// A short human consensus label, e.g. "Buy" / "Hold".
    var consensus: String {
        guard total > 0 else { return "No coverage" }
        if totalBuy > hold + totalSell { return strongBuy >= buy ? "Strong Buy" : "Buy" }
        if totalSell > hold + totalBuy { return "Sell" }
        return "Hold"
    }
}

// MARK: - Errors

nonisolated enum FinnhubError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case http(Int)
    case decoding
    case noData
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Add a Finnhub API key in Settings to fetch live prices."
        case .invalidURL: return "Could not build the request URL."
        case .http(let code): return "Finnhub returned an error (HTTP \(code))."
        case .decoding: return "Couldn't read the response from Finnhub."
        case .noData: return "No data returned for that symbol."
        case .transport(let message): return message
        }
    }
}

// MARK: - Service

actor FinnhubService {
    static let shared = FinnhubService()

    private let base = "https://finnhub.io/api/v1"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private var apiKey: String? {
        KeychainService.shared.get(.finnhub)
    }

    /// Fetch a single live quote. Returns the current price.
    func quote(for symbol: String) async throws -> FinnhubQuote {
        guard let key = apiKey, !key.isEmpty else { throw FinnhubError.missingAPIKey }
        guard var components = URLComponents(string: "\(base)/quote") else { throw FinnhubError.invalidURL }
        components.queryItems = [
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "token", value: key)
        ]
        guard let url = components.url else { throw FinnhubError.invalidURL }

        let quote: FinnhubQuote = try await get(url)
        guard quote.c > 0 else { throw FinnhubError.noData }
        return quote
    }

    /// Symbol search for the Add Holding / Buy flows.
    func search(_ query: String) async throws -> [FinnhubSymbol] {
        guard let key = apiKey, !key.isEmpty else { throw FinnhubError.missingAPIKey }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard var components = URLComponents(string: "\(base)/search") else { throw FinnhubError.invalidURL }
        components.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "token", value: key)
        ]
        guard let url = components.url else { throw FinnhubError.invalidURL }

        let response: FinnhubSearchResponse = try await get(url)
        // Prefer common stock / ETF symbols without exchange suffixes.
        return response.result
            .filter { !$0.symbol.contains(".") }
            .prefix(8)
            .map { $0 }
    }

    /// Recent company news headlines (defaults to the last 14 days).
    func companyNews(for symbol: String, days: Int = 14) async throws -> [CompanyNews] {
        guard let key = apiKey, !key.isEmpty else { throw FinnhubError.missingAPIKey }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let to = Date.now
        let from = Calendar.current.date(byAdding: .day, value: -days, to: to) ?? to
        guard var components = URLComponents(string: "\(base)/company-news") else { throw FinnhubError.invalidURL }
        components.queryItems = [
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "from", value: f.string(from: from)),
            URLQueryItem(name: "to", value: f.string(from: to)),
            URLQueryItem(name: "token", value: key)
        ]
        guard let url = components.url else { throw FinnhubError.invalidURL }
        let news: [CompanyNews] = try await get(url)
        return news.sorted { $0.datetime > $1.datetime }
    }

    /// Latest analyst recommendation trend for a symbol.
    func recommendation(for symbol: String) async throws -> RecommendationTrend? {
        guard let key = apiKey, !key.isEmpty else { throw FinnhubError.missingAPIKey }
        guard var components = URLComponents(string: "\(base)/stock/recommendation") else { throw FinnhubError.invalidURL }
        components.queryItems = [
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "token", value: key)
        ]
        guard let url = components.url else { throw FinnhubError.invalidURL }
        let trends: [RecommendationTrend] = try await get(url)
        return trends.sorted { $0.period > $1.period }.first
    }

    // MARK: Networking

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else { throw FinnhubError.noData }
            guard (200..<300).contains(http.statusCode) else { throw FinnhubError.http(http.statusCode) }
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw FinnhubError.decoding
            }
        } catch let error as FinnhubError {
            throw error
        } catch {
            throw FinnhubError.transport(error.localizedDescription)
        }
    }
}
