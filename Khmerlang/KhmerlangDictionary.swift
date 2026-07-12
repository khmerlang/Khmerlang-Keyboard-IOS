//
//  KhmerlangDictionary.swift
//  Khmerlang
//
//  Read-only access to the bundled Khmerlang n-gram database (khmerlang.sqlite,
//  converted from the Android app's mobile-keyboard-data.bin). Provides the two
//  query paths used by the suggestion bar:
//    - prefix completion of the word being typed (unigrams, per language)
//    - next-word prediction from context (bi-/tri-grams)
//  This mirrors SpellCorrector.getNextWords / the word-completion path, using
//  frequency counts for ranking. No network is required.
//

import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class KhmerlangDictionary {

    /// Language codes as stored in the database (matches the Android app).
    static let langKhmer: Int32 = 0
    static let langEnglish: Int32 = 1

    private var db: OpaquePointer?

    init?() {
        guard let path = Bundle.main.path(forResource: "khmerlang", ofType: "sqlite") else {
            return nil
        }
        // FULLMUTEX: the same connection is used from the main thread (completions)
        // and the background tree-build thread (corrector).
        if sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) != SQLITE_OK {
            sqlite3_close(db)
            return nil
        }
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Queries

    /// Words that begin with `prefix` for the given language, ranked by frequency.
    func completions(prefix: String, lang: Int32, limit: Int32) -> [String] {
        guard !prefix.isEmpty, let upper = Self.upperBound(of: prefix) else { return [] }
        let sql = """
            SELECT keyword FROM ngram
            WHERE gram = 1 AND lang = ? AND keyword >= ? AND keyword < ? AND keyword != '<s>'
            ORDER BY count DESC LIMIT ?
            """
        var results: [String] = []
        query(sql) { stmt in
            sqlite3_bind_int(stmt, 1, lang)
            sqlite3_bind_text(stmt, 2, prefix, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, upper, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 4, limit)
        } row: { stmt in
            if let word = column(stmt, 0), word != prefix {
                results.append(word)
            }
        }
        return results
    }

    /// Likely next words given the previous one/two words (tri-gram then bi-gram),
    /// ranked by frequency and de-duplicated.
    func nextWords(prevOne: String, prevTwo: String, limit: Int) -> [String] {
        var results: [String] = []
        var seen = Set<String>()

        func collect(gram: Int32, contextPrefix: String) {
            guard results.count < limit,
                  !contextPrefix.isEmpty,
                  let upper = Self.upperBound(of: contextPrefix) else { return }
            let sql = """
                SELECT keyword FROM ngram
                WHERE gram = ? AND keyword >= ? AND keyword < ?
                ORDER BY count DESC LIMIT ?
                """
            query(sql) { stmt in
                sqlite3_bind_int(stmt, 1, gram)
                sqlite3_bind_text(stmt, 2, contextPrefix, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 3, upper, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(stmt, 4, Int32(limit * 3))
            } row: { stmt in
                guard results.count < limit, let keyword = column(stmt, 0) else { return }
                let word = String(keyword.dropFirst(contextPrefix.count))
                let key = word.lowercased()
                if !word.isEmpty, word != "<s>", seen.insert(key).inserted {
                    results.append(word)
                }
            }
        }

        if !prevOne.isEmpty && !prevTwo.isEmpty {
            collect(gram: 3, contextPrefix: "\(prevOne) \(prevTwo) ")
        }
        collect(gram: 2, contextPrefix: "\(prevTwo) ")
        return results
    }

    /// Khmer words whose romanisation (a comma-separated list in `other`) begins
    /// with `prefix`, ranked by frequency. A cheap roman→Khmer fallback used
    /// while the fuzzy-correction BK-trees are still building.
    func romanCompletions(prefix: String, limit: Int32) -> [String] {
        guard !prefix.isEmpty else { return [] }
        let sql = """
            SELECT keyword FROM ngram
            WHERE gram = 1 AND lang = 0 AND (other LIKE ? OR other LIKE ?)
            ORDER BY count DESC LIMIT ?
            """
        var results: [String] = []
        query(sql) { stmt in
            sqlite3_bind_text(stmt, 1, "\(prefix)%", -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, "%,\(prefix)%", -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 3, limit)
        } row: { stmt in
            if let word = column(stmt, 0) {
                results.append(word)
            }
        }
        return results
    }

    /// Iterate all unigrams for a language (word, other, count), most frequent
    /// first. Used to build the fuzzy-correction BK-trees and the segmenter.
    func forEachUnigram(lang: Int32, _ body: (String, String, Int) -> Void) {
        let sql = """
            SELECT keyword, other, count FROM ngram
            WHERE gram = 1 AND lang = ? AND keyword != '<s>'
            ORDER BY count DESC
            """
        query(sql) { stmt in
            sqlite3_bind_int(stmt, 1, lang)
        } row: { stmt in
            if let word = column(stmt, 0) {
                body(word, column(stmt, 1) ?? "", Int(sqlite3_column_int(stmt, 2)))
            }
        }
    }

    /// Frequency counts for a set of exact keywords (unigram/bigram/trigram),
    /// filtered by language. Used to context-rank correction candidates.
    func counts(for keys: [String], lang: Int32) -> [String: Int] {
        guard !keys.isEmpty else { return [:] }
        let placeholders = Array(repeating: "?", count: keys.count).joined(separator: ",")
        let sql = "SELECT keyword, count FROM ngram WHERE lang = ? AND keyword IN (\(placeholders))"
        var out: [String: Int] = [:]
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, lang)
        for (index, key) in keys.enumerated() {
            sqlite3_bind_text(stmt, Int32(index + 2), key, -1, SQLITE_TRANSIENT)
        }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let keyword = column(stmt, 0) {
                out[keyword] = Int(sqlite3_column_int(stmt, 1))
            }
        }
        return out
    }

    // MARK: - Helpers

    private func query(_ sql: String,
                       bind: (OpaquePointer?) -> Void,
                       row: (OpaquePointer?) -> Void) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        bind(stmt)
        while sqlite3_step(stmt) == SQLITE_ROW {
            row(stmt)
        }
    }

    /// Exclusive upper bound for a binary-collated prefix range scan: the input
    /// with its last Unicode scalar incremented by one.
    static func upperBound(of prefix: String) -> String? {
        var scalars = Array(prefix.unicodeScalars)
        while let last = scalars.last {
            if last.value < 0x10FFFF, let next = Unicode.Scalar(last.value + 1) {
                scalars[scalars.count - 1] = next
                return String(String.UnicodeScalarView(scalars))
            }
            scalars.removeLast()
        }
        return nil
    }
}

private func column(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
    guard let cString = sqlite3_column_text(stmt, index) else { return nil }
    return String(cString: cString)
}
