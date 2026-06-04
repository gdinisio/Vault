//
//  PriceHistoryService.swift
//  Vault
//
//  Real price history for charts via Yahoo Finance's key-less chart endpoint
//  (prices are USD, the app's base currency). Per-range requests give proper
//  intraday for 1D/1W and daily/weekly for longer ranges. Cached per session.
//

import Foundation

nonisolated struct PricePoint: Identifiable, Hashable {
    let date: Date
    let close: Double
    var id: Date { date }
}

nonisolated enum ChartRange: String, CaseIterable, Identifiable {
    case day = "1D"
    case week = "1W"
    case month = "1M"
    case threeMonth = "3M"
    case year = "1Y"
    case all = "ALL"
    var id: String { rawValue }

    /// Yahoo `range` + `interval` query values.
    var query: (range: String, interval: String) {
        switch self {
        case .day:        return ("1d", "5m")
        case .week:       return ("5d", "30m")
        case .month:      return ("1mo", "1d")
        case .threeMonth: return ("3mo", "1d")
        case .year:       return ("1y", "1d")
        case .all:        return ("max", "1wk")
        }
    }

    /// Whether axis labels should show time rather than date.
    var isIntraday: Bool { self == .day || self == .week }
}

nonisolated enum PriceHistoryError: LocalizedError {
    case invalidSymbol, noData, transport
    var errorDescription: String? {
        switch self {
        case .invalidSymbol: return "Couldn't build a request for that symbol."
        case .noData: return "No price history available for that symbol."
        case .transport: return "Couldn't load price history."
        }
    }
}

actor PriceHistoryService {
    static let shared = PriceHistoryService()

    private let session: URLSession
    private var cache: [String: [PricePoint]] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Daily/intraday close history for a symbol over a range (cached).
    func history(for symbol: String, range: ChartRange) async throws -> [PricePoint] {
        let key = "\(symbol.uppercased())|\(range.rawValue)"
        if let cached = cache[key] { return cached }

        let (r, interval) = range.query
        let path = "v8/finance/chart/\(symbol.uppercased())"
        let query = "range=\(r)&interval=\(interval)"

        // Try both Yahoo hosts (one is sometimes rate-limited).
        for host in ["query1.finance.yahoo.com", "query2.finance.yahoo.com"] {
            guard let url = URL(string: "https://\(host)/\(path)?\(query)") else { continue }
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { continue }
                let points = try Self.parse(data)
                guard points.count > 1 else { continue }
                cache[key] = points
                return points
            } catch {
                continue
            }
        }
        throw PriceHistoryError.noData
    }

    // MARK: JSON parsing

    private struct ChartResponse: Decodable {
        struct Chart: Decodable { let result: [Result]? }
        struct Result: Decodable {
            let timestamp: [Double]?
            let indicators: Indicators
        }
        struct Indicators: Decodable { let quote: [Quote] }
        struct Quote: Decodable { let close: [Double?]? }
        let chart: Chart
    }

    private nonisolated static func parse(_ data: Data) throws -> [PricePoint] {
        let decoded = try JSONDecoder().decode(ChartResponse.self, from: data)
        guard let result = decoded.chart.result?.first,
              let timestamps = result.timestamp,
              let closes = result.indicators.quote.first?.close else {
            return []
        }
        var out: [PricePoint] = []
        for (i, ts) in timestamps.enumerated() where i < closes.count {
            if let close = closes[i] {
                out.append(PricePoint(date: Date(timeIntervalSince1970: ts), close: close))
            }
        }
        return out
    }
}
