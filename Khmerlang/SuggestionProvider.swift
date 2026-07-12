//
//  SuggestionProvider.swift
//  Khmerlang
//
//  Coordinates candidate sources for the suggestion bar, all on-device:
//    - KhmerlangCorrector: fuzzy spelling correction (BK-tree + context ranking)
//    - KhmerlangDictionary: prefix completion and next-word prediction
//    - UITextChecker / UILexicon: English augmentation and personal shortcuts
//

import UIKit

final class SuggestionProvider {

    private let checker = UITextChecker()
    private let corrector = KhmerlangCorrector.shared
    private var dictionary: KhmerlangDictionary? { corrector.dictionary }

    /// The personal lexicon (shortcuts, contact names) provided by the host.
    var lexicon: UILexicon?

    private static let khmerCheckerSupported: Bool =
        UITextChecker.availableLanguages.contains { $0.hasPrefix("km") }

    /// Candidates for the word currently being composed: fuzzy corrections of the
    /// (possibly misspelled) word first, then prefix completions to fill in.
    func completions(for word: String, language: KeyboardLanguage,
                     prevOne: String, prevTwo: String, isStartSentence: Bool) -> [String] {
        guard !word.isEmpty else { return [] }
        var results: [String] = []

        // 1. Personal lexicon matches (user shortcuts / names).
        if let lexicon {
            let lower = word.lowercased()
            for entry in lexicon.entries
            where entry.userInput.lowercased().hasPrefix(lower) && !entry.documentText.isEmpty {
                results.append(entry.documentText)
            }
        }

        // 2. Fuzzy spelling correction from the Khmerlang model.
        results.append(contentsOf: corrector.correct(word: word, language: language,
                                                      prevOne: prevOne, prevTwo: prevTwo,
                                                      isStartSentence: isStartSentence))

        // 3. Frequency-ranked prefix completions (English ones honour the toggle).
        let langCode = (language == .khmer) ? KhmerlangDictionary.langKhmer : KhmerlangDictionary.langEnglish
        if langCode == KhmerlangDictionary.langKhmer || SharedStore.englishCorrectionEnabled {
            results.append(contentsOf: dictionary?.completions(prefix: word, lang: langCode, limit: 8) ?? [])
        }

        // 4. For English, augment with system dictionary completions + guesses.
        let checkerEnabled = (language == .english)
            ? SharedStore.englishCorrectionEnabled
            : Self.khmerCheckerSupported
        if checkerEnabled {
            let langId = (language == .english) ? "en_US" : "km"
            let ns = word as NSString
            let fullRange = NSRange(location: 0, length: ns.length)
            if let completions = checker.completions(forPartialWordRange: fullRange, in: word, language: langId) {
                results.append(contentsOf: completions)
            }
            let misspelled = checker.rangeOfMisspelledWord(in: word, range: fullRange,
                                                           startingAt: 0, wrap: false, language: langId)
            if misspelled.location != NSNotFound,
               let guesses = checker.guesses(forWordRange: misspelled, in: word, language: langId) {
                results.append(contentsOf: guesses)
            }
        }

        return dedupe(results, excluding: word, limit: 6)
    }

    /// Next-word predictions given the preceding context (used when no word is
    /// currently being typed, e.g. right after a space).
    func nextWords(prevOne: String, prevTwo: String) -> [String] {
        let words = dictionary?.nextWords(prevOne: prevOne, prevTwo: prevTwo, limit: 6) ?? []
        return dedupe(words, excluding: nil, limit: 6)
    }

    // MARK: - Helpers

    private func dedupe(_ candidates: [String], excluding word: String?, limit: Int) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        for candidate in candidates where !candidate.isEmpty && candidate != word {
            if seen.insert(candidate).inserted {
                output.append(candidate)
            }
            if output.count >= limit { break }
        }
        return output
    }
}
