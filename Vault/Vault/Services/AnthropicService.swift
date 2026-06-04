//
//  AnthropicService.swift
//  Vault
//
//  async/await wrapper around the Anthropic Messages API. Used by the AI
//  Analysis sheet to generate portfolio commentary and answer follow-ups.
//  The API key is stored in the Keychain alongside the Finnhub key.
//

import Foundation

// MARK: - Conversation model

nonisolated struct ChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    var text: String
}

// MARK: - Errors

nonisolated enum AnthropicError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case http(Int, String?)
    case decoding
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Add an Anthropic API key in Settings to use AI Analysis."
        case .invalidURL: return "Could not build the request URL."
        case .http(let code, let message): return message ?? "Claude returned an error (HTTP \(code))."
        case .decoding: return "Couldn't read Claude's response."
        case .transport(let message): return message
        }
    }
}

// MARK: - Service

actor AnthropicService {
    static let shared = AnthropicService()

    private let url = URL(string: "https://api.anthropic.com/v1/messages")
    private let model = "claude-sonnet-4-20250514"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private var apiKey: String? {
        KeychainService.shared.get(.anthropic)
    }

    /// Send the conversation (plus a system prompt) and return Claude's reply.
    /// Set `enableWebSearch` to let Claude pull live news via the server-side
    /// web-search tool; if that fails it transparently retries without it.
    func send(messages: [ChatMessage], systemPrompt: String, enableWebSearch: Bool = false) async throws -> String {
        guard let key = apiKey, !key.isEmpty else { throw AnthropicError.missingAPIKey }
        guard let url else { throw AnthropicError.invalidURL }

        do {
            return try await request(key: key, url: url, messages: messages,
                                     systemPrompt: systemPrompt, webSearch: enableWebSearch)
        } catch let AnthropicError.http(code, message) where enableWebSearch {
            // Web search may be unavailable on the account/model — retry plainly.
            _ = (code, message)
            return try await request(key: key, url: url, messages: messages,
                                     systemPrompt: systemPrompt, webSearch: false)
        }
    }

    private func request(key: String, url: URL, messages: [ChatMessage],
                         systemPrompt: String, webSearch: Bool) async throws -> String {
        let payload = RequestBody(
            model: model,
            max_tokens: 1536,
            system: systemPrompt,
            messages: messages.map {
                MessageBody(role: $0.role == .user ? "user" : "assistant", content: $0.text)
            },
            tools: webSearch ? [WebSearchTool()] : nil
        )

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONEncoder().encode(payload)

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw AnthropicError.decoding }
            guard (200..<300).contains(http.statusCode) else {
                let message = (try? JSONDecoder().decode(APIErrorBody.self, from: data))?.error.message
                throw AnthropicError.http(http.statusCode, message)
            }
            let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
            let text = decoded.content.compactMap { $0.text }.joined()
            guard !text.isEmpty else { throw AnthropicError.decoding }
            return text
        } catch let error as AnthropicError {
            throw error
        } catch is DecodingError {
            throw AnthropicError.decoding
        } catch {
            throw AnthropicError.transport(error.localizedDescription)
        }
    }

    // MARK: Wire types

    private struct RequestBody: Encodable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [MessageBody]
        var tools: [WebSearchTool]?
    }

    private struct MessageBody: Encodable {
        let role: String
        let content: String
    }

    /// Server-side web search tool (Anthropic runs the search).
    private struct WebSearchTool: Encodable {
        let type = "web_search_20250305"
        let name = "web_search"
        let max_uses = 5
    }

    private struct ResponseBody: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        let content: [Block]
    }

    private struct APIErrorBody: Decodable {
        struct Inner: Decodable { let message: String }
        let error: Inner
    }
}
