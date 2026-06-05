//
//  AIService.swift
//  Vault
//
//  Multi-provider LLM analysis. Prefers Google Gemini Flash (better quality);
//  when Gemini is unavailable or its quota is exhausted it falls back to Groq
//  (Llama 3.3 70B). Both are fed pre-compiled portfolio/ticker data + news, so
//  no web-search tool is required.
//

import Foundation

enum AIProvider: String {
    case gemini = "Gemini Flash"
    case groq = "Llama 3.3 70B"
}

struct AIResult {
    let text: String
    let provider: AIProvider
}

enum AIError: LocalizedError {
    case noProvider
    case rateLimited
    case http(Int, String?)
    case decoding
    case transport(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .noProvider: return "Add a Gemini or Groq API key in Settings to run AI analysis."
        case .rateLimited: return "AI provider rate limit reached. Try again shortly."
        case .http(let code, let message): return message ?? "AI provider error (HTTP \(code))."
        case .decoding: return "Couldn't read the AI response."
        case .transport(let message): return message
        case .empty: return "The AI returned an empty response."
        }
    }
}

actor AIService {
    static let shared = AIService()

    private let geminiModel = "gemini-2.5-flash"
    private let groqModel = "llama-3.3-70b-versatile"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    var hasAnyProvider: Bool {
        KeychainService.shared.has(.gemini) || KeychainService.shared.has(.groq)
    }

    /// Run a chat completion. Tries Gemini first; on any Gemini failure (incl.
    /// quota/limit) falls back to Groq if configured.
    func chat(system: String, messages: [ChatMessage]) async throws -> AIResult {
        let hasGemini = KeychainService.shared.has(.gemini)
        let hasGroq = KeychainService.shared.has(.groq)
        guard hasGemini || hasGroq else { throw AIError.noProvider }

        if hasGemini, let key = KeychainService.shared.get(.gemini) {
            do {
                let text = try await callGemini(key: key, system: system, messages: messages)
                return AIResult(text: text, provider: .gemini)
            } catch {
                // Gemini failed (quota, error). Fall through to Groq if available.
                if !hasGroq { throw error }
            }
        }

        guard hasGroq, let key = KeychainService.shared.get(.groq) else { throw AIError.noProvider }
        let text = try await callGroq(key: key, system: system, messages: messages)
        return AIResult(text: text, provider: .groq)
    }

    // MARK: Gemini

    private func callGemini(key: String, system: String, messages: [ChatMessage]) async throws -> String {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(geminiModel):generateContent") else {
            throw AIError.transport("Bad URL")
        }
        let body = GeminiRequest(
            system_instruction: .init(parts: [.init(text: system)]),
            contents: messages.map {
                GeminiRequest.Content(role: $0.role == .user ? "user" : "model",
                                      parts: [.init(text: $0.text)])
            },
            generationConfig: .init(temperature: 0.7, maxOutputTokens: 2048)
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse else { throw AIError.decoding }
        if http.statusCode == 429 { throw AIError.rateLimited }
        guard (200..<300).contains(http.statusCode) else {
            throw AIError.http(http.statusCode, Self.geminiErrorMessage(data))
        }
        guard let decoded = try? JSONDecoder().decode(GeminiResponse.self, from: data) else { throw AIError.decoding }
        let text = decoded.candidates?.first?.content?.parts?.compactMap(\.text).joined() ?? ""
        guard !text.isEmpty else { throw AIError.empty }
        return text
    }

    // MARK: Groq (OpenAI-compatible)

    private func callGroq(key: String, system: String, messages: [ChatMessage]) async throws -> String {
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            throw AIError.transport("Bad URL")
        }
        var wire: [OpenAIMessage] = [OpenAIMessage(role: "system", content: system)]
        wire += messages.map { OpenAIMessage(role: $0.role == .user ? "user" : "assistant", content: $0.text) }
        let body = OpenAIRequest(model: groqModel, messages: wire, temperature: 0.7, max_tokens: 2048)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse else { throw AIError.decoding }
        if http.statusCode == 429 { throw AIError.rateLimited }
        guard (200..<300).contains(http.statusCode) else {
            throw AIError.http(http.statusCode, Self.openAIErrorMessage(data))
        }
        guard let decoded = try? JSONDecoder().decode(OpenAIResponse.self, from: data),
              let text = decoded.choices?.first?.message?.content, !text.isEmpty else {
            throw AIError.empty
        }
        return text
    }

    // MARK: Networking

    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw AIError.transport(error.localizedDescription)
        }
    }

    private static func geminiErrorMessage(_ data: Data) -> String? {
        struct E: Decodable { struct Inner: Decodable { let message: String? }; let error: Inner? }
        return (try? JSONDecoder().decode(E.self, from: data))?.error?.message
    }
    private static func openAIErrorMessage(_ data: Data) -> String? {
        struct E: Decodable { struct Inner: Decodable { let message: String? }; let error: Inner? }
        return (try? JSONDecoder().decode(E.self, from: data))?.error?.message
    }

    // MARK: Wire types

    private struct GeminiRequest: Encodable {
        struct Part: Encodable { let text: String }
        struct Content: Encodable { let role: String; let parts: [Part] }
        struct System: Encodable { let parts: [Part] }
        struct GenConfig: Encodable { let temperature: Double; let maxOutputTokens: Int }
        let system_instruction: System
        let contents: [Content]
        let generationConfig: GenConfig
    }
    private struct GeminiResponse: Decodable {
        struct Part: Decodable { let text: String? }
        struct Content: Decodable { let parts: [Part]? }
        struct Candidate: Decodable { let content: Content? }
        let candidates: [Candidate]?
    }

    private struct OpenAIMessage: Encodable { let role: String; let content: String }
    private struct OpenAIRequest: Encodable {
        let model: String
        let messages: [OpenAIMessage]
        let temperature: Double
        let max_tokens: Int
    }
    private struct OpenAIResponse: Decodable {
        struct Choice: Decodable { struct Msg: Decodable { let content: String? }; let message: Msg? }
        let choices: [Choice]?
    }
}
