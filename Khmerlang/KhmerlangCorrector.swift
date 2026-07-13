//
//  KhmerlangCorrector.swift
//  Khmerlang
//
//  Fuzzy spelling correction, ported from the Android SpellCorrector. Builds
//  per-language BK-trees from the bundled unigram list (once, in the background)
//  and, for a possibly-misspelled word, returns dictionary words within a
//  length-based edit-distance tolerance, re-ranked by bi-/tri-gram context.
//
//  Also builds the roman→Khmer tree (Android's bkRM) from the romanisations in
//  the unigram `other` column. Until the trees are ready, `correct` falls back
//  to an exact roman-prefix lookup so the bar is never silently empty.
//

import Foundation

final class KhmerlangCorrector {

    /// Shared instance so the BK-trees are built once per extension process,
    /// not once per keyboard presentation.
    static let shared = KhmerlangCorrector()

    let dictionary = KhmerlangDictionary()

    /// Everything a correction pass reads, bundled so it can be swapped in
    /// atomically. Immutable once built.
    private struct TreeSet {
        let khmer: BKTree
        let english: BKTree
        let roman: BKTree
        let segmenter: KhmerSegmenter
        let specialCases: [String: String]
    }

    /// Guards `treeSet`: `correct`/`segmenter` run on the keyboard's suggestion
    /// queue while finished builds are swapped in from the main thread.
    private let stateLock = NSLock()
    private var treeSet: TreeSet?

    /// Splits spaceless Khmer runs into words; built with the trees, nil until then.
    var segmenter: KhmerSegmenter? {
        stateLock.lock(); defer { stateLock.unlock() }
        return treeSet?.segmenter
    }

    private var ready = false
    private var building = false
    /// SharedStore.customMappingsVersion the current trees were built with.
    private var builtMappingsVersion = -1
    private var readyObservers: [() -> Void] = []

    var isReady: Bool { ready }

    /// Rebuild the trees when the user edited the custom dictionary in the
    /// container app since they were built. The old trees keep serving until
    /// the replacements are swapped in. Called whenever the keyboard appears.
    func refreshCustomMappingsIfNeeded() {
        guard ready, !building,
              builtMappingsVersion != SharedStore.customMappingsVersion else { return }
        buildTreesInBackground()
    }

    /// Invoke `observer` on the main thread once the BK-trees finish building
    /// (immediately if they already have). Lets the keyboard refresh the
    /// suggestion bar the moment fuzzy correction becomes available.
    func notifyWhenReady(_ observer: @escaping () -> Void) {
        if ready {
            observer()
        } else {
            readyObservers.append(observer)
        }
    }

    private init() {
        buildTreesInBackground()
    }

    private func buildTreesInBackground() {
        guard let dictionary, !building else { return }
        building = true
        let mappingsVersion = SharedStore.customMappingsVersion
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            // Khmer words feed the Khmer tree; their romanisations (the `other`
            // column) feed the roman→Khmer tree, mapping each romanisation back
            // to its Khmer word.
            let khmer = BKTree()
            let roman = BKTree()
            var khmerCounts: [String: Int] = [:]
            var maxWordScalars = 1
            dictionary.forEachUnigram(lang: KhmerlangDictionary.langKhmer) { word, other, count in
                khmer.add(word, other: "")
                khmerCounts[word] = count
                maxWordScalars = max(maxWordScalars, word.unicodeScalars.count)
                if !other.isEmpty {
                    for variant in other.split(separator: ",") {
                        let romanized = variant.trimmingCharacters(in: .whitespaces).lowercased()
                        if !romanized.isEmpty { roman.add(romanized, other: word) }
                    }
                }
            }
            // User-defined mappings from the container app (Android's
            // SpellCorrector.addKhmerWord): joins both trees and the segmenter.
            for mapping in SharedStore.customMappings {
                khmer.add(mapping.khmer, other: "")
                khmerCounts[mapping.khmer] = max(khmerCounts[mapping.khmer] ?? 0, 500)
                maxWordScalars = max(maxWordScalars, mapping.khmer.unicodeScalars.count)
                let romanized = mapping.roman.trimmingCharacters(in: .whitespaces).lowercased()
                if !romanized.isEmpty { roman.add(romanized, other: mapping.khmer) }
            }
            let english = BKTree()
            var special: [String: String] = [:]
            dictionary.forEachUnigram(lang: KhmerlangDictionary.langEnglish) { word, other, _ in
                english.add(word, other: "")
                if !other.isEmpty { special[word] = other }
            }
            let segmenter = KhmerSegmenter(counts: khmerCounts,
                                           maxWordScalars: maxWordScalars,
                                           ml: MLWordSegmenter())
            DispatchQueue.main.async {
                let set = TreeSet(khmer: khmer, english: english, roman: roman,
                                  segmenter: segmenter, specialCases: special)
                self.stateLock.lock()
                self.treeSet = set
                self.stateLock.unlock()
                self.builtMappingsVersion = mappingsVersion
                self.building = false
                self.ready = true
                let observers = self.readyObservers
                self.readyObservers = []
                observers.forEach { $0() }
            }
        }
    }

    // MARK: - Correction

    /// Ranked correction candidates for `word`. While the trees are still
    /// building (the first seconds after each extension launch), Latin input
    /// falls back to an exact roman-prefix lookup; Khmer input is covered by
    /// the prefix completions the suggestion provider adds separately.
    /// `isCancelled` lets a superseded request abandon between tree searches.
    func correct(word: String, language: KeyboardLanguage,
                 prevOne: String, prevTwo: String, isStartSentence: Bool,
                 isCancelled: () -> Bool = { false }) -> [String] {
        guard !word.isEmpty, let dictionary else { return [] }
        stateLock.lock()
        let trees = treeSet
        stateLock.unlock()
        guard let trees else {
            if let first = word.first, !isKhmer(first), SharedStore.romanCorrectionEnabled {
                return dictionary.romanCompletions(prefix: word.lowercased(), limit: 6)
            }
            return []
        }

        // Scalar count, not Character count: Khmer graphemes cluster several
        // scalars, which would understate length (and thus tolerance) badly.
        // Capped at 3: tolerance 4 visits most of the tree (~2× the search
        // cost) while returning almost nothing that survives ranking.
        let tolerance: Int
        switch word.unicodeScalars.count {
        case ...2: tolerance = 1
        case ...4: tolerance = 2
        default:   tolerance = 3
        }

        if isKhmer(word.first!) {
            return correctBy(dictionary: dictionary, tree: trees.khmer, isOther: false,
                             misspelling: normalizeKhmer(word), lang: KhmerlangDictionary.langKhmer,
                             tolerance: tolerance, prevOne: prevOne, prevTwo: prevTwo,
                             isStartSentence: isStartSentence, specialCases: trees.specialCases)
        } else {
            // Latin input: interleave roman→Khmer transliterations (from the
            // roman tree, scored with Khmer context) with English corrections,
            // 2 roman then 2 English — matching the Android SpellCorrector.
            // Each source is gated by its user toggle (Android's
            // KEY_RM_CORRECTION_MODE / KEY_EN_CORRECTION_MODE).
            let lower = word.lowercased()
            let romanOut = SharedStore.romanCorrectionEnabled
                ? correctBy(dictionary: dictionary, tree: trees.roman, isOther: true,
                            misspelling: lower, lang: KhmerlangDictionary.langKhmer,
                            tolerance: tolerance, prevOne: prevOne, prevTwo: prevTwo,
                            isStartSentence: isStartSentence, specialCases: trees.specialCases)
                : []
            if isCancelled() { return [] }
            let englishOut = SharedStore.englishCorrectionEnabled
                ? correctBy(dictionary: dictionary, tree: trees.english, isOther: false,
                            misspelling: lower, lang: KhmerlangDictionary.langEnglish,
                            tolerance: tolerance, prevOne: prevOne, prevTwo: prevTwo,
                            isStartSentence: isStartSentence, specialCases: trees.specialCases)
                : []
            return interleave(romanOut, englishOut)
        }
    }

    /// Interleave two candidate lists as 2-from-a, 2-from-b, repeating.
    private func interleave(_ a: [String], _ b: [String]) -> [String] {
        var output: [String] = []
        var i = 0, j = 0
        while i < a.count || j < b.count {
            if i < a.count { output.append(a[i]); i += 1 }
            if i < a.count { output.append(a[i]); i += 1 }
            if j < b.count { output.append(b[j]); j += 1 }
            if j < b.count { output.append(b[j]); j += 1 }
        }
        return output
    }

    private func correctBy(dictionary: KhmerlangDictionary, tree: BKTree, isOther: Bool,
                           misspelling: String, lang: Int32, tolerance: Int,
                           prevOne: String, prevTwo: String, isStartSentence: Bool,
                           specialCases: [String: String]) -> [String] {
        let tokenOne = tokenize(prevOne, lang: lang)
        let tokenTwo = tokenize(prevTwo, lang: lang)

        // Gather fuzzy candidates and every context key we need counts for.
        var candidates: [(word: String, distance: Int)] = []
        var keys: Set<String> = ["<s>", "<s> <s>", "<s> <s> <s>"]
        for result in tree.search(Array(misspelling.unicodeScalars), tolerance: tolerance) {
            // For the roman tree the match is a romanisation; the Khmer word(s)
            // it maps to live in `other` (joined by "_"). Otherwise the match
            // itself is the candidate.
            let words: [String] = isOther
                ? result.other.lowercased().split(separator: "_").map(String.init)
                : [result.word.lowercased()]
            for word in words where !word.isEmpty {
                candidates.append((word, result.distance))
                keys.insert(word)
                keys.insert("\(tokenTwo) \(word)")
                keys.insert("\(tokenOne) \(tokenTwo) \(word)")
            }
        }
        guard !candidates.isEmpty else { return [] }

        let counts = dictionary.counts(for: Array(keys), lang: lang)
        let triContext = counts["<s> <s> <s>"] ?? 0
        let biContext = counts["<s> <s>"] ?? 0
        let uniContext = counts["<s>"] ?? 0

        var scored: [(keyword: String, score: Double)] = []
        for candidate in candidates {
            let word = candidate.word
            let distance = candidate.distance
            let weight: Double = distance < 1 ? 1.0 : (distance <= 2 ? 0.95 : (distance <= 3 ? 0.6 : 0.5))

            var score = 0.0
            if distance == 0 {
                score = 1.0
            } else if let c = counts["\(tokenOne) \(tokenTwo) \(word)"], triContext > 0 {
                score = weight * Double(c) / Double(triContext)
            } else if let c = counts["\(tokenTwo) \(word)"], biContext > 0 {
                score = 0.4 * weight * Double(c) / Double(biContext)
            } else if let c = counts[word], uniContext > 0 {
                score = 0.4 * 0.4 * weight * Double(c) / Double(uniContext)
            }

            var keyword = word
            if let special = specialCases[word], !special.isEmpty {
                keyword = special
            } else if lang == KhmerlangDictionary.langEnglish && isStartSentence {
                keyword = word.prefix(1).uppercased() + word.dropFirst()
            }
            scored.append((keyword, score))
        }

        scored.sort { $0.score > $1.score }

        var seen = Set<String>()
        var output: [String] = []
        for item in scored where seen.insert(item.keyword.lowercased()).inserted {
            output.append(item.keyword)
            if output.count >= 10 { break }
        }
        return output
    }

    // MARK: - Helpers

    /// Matches the Android sentence-context tokens used to build n-gram keys.
    private func tokenize(_ word: String, lang: Int32) -> String {
        if word.isEmpty { return "<oth>" }
        if word == "<s>" || word == "<s> <s>" { return word }
        guard let first = word.first else { return "<oth>" }
        if first.isNumber || ("០"..."៩").contains(first) { return "<num>" }
        if isKhmer(first) && lang == KhmerlangDictionary.langKhmer { return word }
        if ("a"..."z").contains(first) || ("A"..."Z").contains(first),
           lang == KhmerlangDictionary.langEnglish { return word }
        return "<oth>"
    }

    /// First Khmer consonant/independent-vowel range (ក…ឳ), as in the Android check.
    private func isKhmer(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        return (0x1780...0x17B3).contains(scalar.value)
    }

    /// Normalise common Khmer vowel-ordering typos before matching.
    private func normalizeKhmer(_ text: String) -> String {
        text.replacingOccurrences(of: "េី", with: "ើ")
            .replacingOccurrences(of: "េា", with: "ោ")
    }
}
