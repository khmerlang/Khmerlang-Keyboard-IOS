//
//  SpellCheckClient.swift
//  Khmerlang
//
//  Client for the Khmerlang server spell checker (the Android
//  SpellSuggestionManager API): POST /v1/spelling-check on user request,
//  POST /v2/words/selection when a suggestion is picked. Network calls only
//  work when the user grants Full Access (RequestsOpenAccess).
//
//  Index semantics (verified against the live API): start_index/end_index are
//  Unicode scalar (code-point) offsets and end_index is INCLUSIVE.
//

import Foundation

struct SpellCheckTypo: Decodable {
    /// Scalar offset of the typo's first character (inclusive).
    let startIndex: Int
    /// Scalar offset of the typo's last character (INCLUSIVE — server convention).
    let endIndex: Int
    let word: String
    let suggestions: [String]
    let scores: [Double]?
    let type: String?

    enum CodingKeys: String, CodingKey {
        case startIndex = "start_index"
        case endIndex = "end_index"
        case word, suggestions, scores, type
    }
}

enum SpellCheckError: Error {
    case network(Error)
    case rateLimited
    case server(Int)
    case emptyText

    var userMessage: String {
        switch self {
        case .network:     return "No connection. Check the internet and try again."
        case .rateLimited: return "Too many requests — please wait a moment."
        case .server:      return "The spell-check service is unavailable right now."
        case .emptyText:   return "Nothing to check — type some Khmer text first."
        }
    }
}

final class SpellCheckClient {

    static let shared = SpellCheckClient()

    private let session: URLSession
    private let base = URL(string: "https://api.khmerlang.com")!

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        // The API's WAF rejects some default agents; identify ourselves.
        config.httpAdditionalHeaders = ["User-Agent": "Khmerlang-Keyboard-iOS/1.0"]
        session = URLSession(configuration: config)
    }

    private struct CheckRequest: Encodable { let text: String }
    private struct CheckResponse: Decodable { let results: [SpellCheckTypo] }

    /// Check `text` for typos; the completion is delivered on the main queue.
    func check(text: String, completion: @escaping (Result<[SpellCheckTypo], SpellCheckError>) -> Void) {
        func finish(_ result: Result<[SpellCheckTypo], SpellCheckError>) {
            DispatchQueue.main.async { completion(result) }
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            finish(.failure(.emptyText))
            return
        }
        var request = URLRequest(url: base.appendingPathComponent("v1/spelling-check"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(CheckRequest(text: text))
        session.dataTask(with: request) { data, response, error in
            if let error {
                finish(.failure(.network(error)))
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200, let data,
                  let decoded = try? JSONDecoder().decode(CheckResponse.self, from: data) else {
                finish(.failure(status == 429 ? .rateLimited : .server(status)))
                return
            }
            finish(.success(decoded.results))
        }.resume()
    }

    /// Log which suggestion the user picked (fire-and-forget; the Android
    /// /v2/words/selection telemetry that improves the service's ranking).
    func logSelection(word: String, selected: String) {
        struct SelectionRequest: Encodable { let word: String; let selected: String }
        var request = URLRequest(url: base.appendingPathComponent("v2/words/selection"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(SelectionRequest(word: word, selected: selected))
        session.dataTask(with: request).resume()
    }
}

// MARK: - Replacement planning (pure, testable)

extension SpellCheckClient {

    struct ReplacementPlan {
        /// Unicode scalars to delete backwards from the cursor (scalar units,
        /// not Characters — Khmer clusters and backspace granularity differ).
        let deleteScalars: Int
        /// Text to type after deleting (the suggestion plus the preserved tail
        /// that sat between the typo and the cursor).
        let insert: String
    }

    /// Plan replacing `typo` inside `beforeText` (whose end is the cursor).
    /// The typo is re-located near its reported offset instead of trusting the
    /// index blindly, so the plan survives small edits made since the check.
    /// Returns nil when the typo text can no longer be found.
    static func plan(replacing typo: SpellCheckTypo, with suggestion: String,
                     in beforeText: String) -> ReplacementPlan? {
        guard let range = locate(word: typo.word, nearScalarOffset: typo.startIndex, in: beforeText) else {
            return nil
        }
        let tail = String(beforeText[range.upperBound...])
        return ReplacementPlan(deleteScalars: beforeText[range.lowerBound...].unicodeScalars.count,
                               insert: suggestion + tail)
    }

    /// The occurrence of `word` in `text` whose scalar offset is closest to
    /// `offset`.
    static func locate(word: String, nearScalarOffset offset: Int,
                       in text: String) -> Range<String.Index>? {
        guard !word.isEmpty else { return nil }
        var best: (range: Range<String.Index>, distance: Int)?
        var searchFrom = text.startIndex
        while let found = text.range(of: word, range: searchFrom..<text.endIndex) {
            let scalarStart = text.unicodeScalars.distance(
                from: text.unicodeScalars.startIndex,
                to: found.lowerBound.samePosition(in: text.unicodeScalars) ?? text.unicodeScalars.startIndex)
            let distance = abs(scalarStart - offset)
            if best == nil || distance < best!.distance {
                best = (found, distance)
            }
            searchFrom = found.upperBound
        }
        return best?.range
    }
}
