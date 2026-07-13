//
//  KhmerSegmenter.swift
//  Khmerlang
//
//  Dictionary-based Khmer word segmentation. Khmer is written without spaces,
//  so the text before the cursor is a run of glued-together words; suggestions
//  only work if we can find the word actually being composed. This splits a
//  run with a small dynamic programme over the bundled unigram lexicon:
//  maximise the scalars covered by dictionary words, then prefer frequent
//  words, then fewer segments. The trailing segment may be an incomplete
//  prefix of a dictionary word (the word still being typed), and scalars the
//  lexicon doesn't know are merged into "unknown" chunks (new words).
//
//  A lightweight stand-in for the Android app's TFlite deep-learning segmenter.
//

import Foundation

final class KhmerSegmenter {

    /// Khmer word → unigram frequency, built alongside the corrector's BK-trees.
    private let counts: [String: Int]
    private let maxWordScalars: Int
    /// All dictionary words in scalar-lexicographic order, for prefix-existence
    /// checks by binary search. Replaces per-keystroke SQLite probes in the DP
    /// tail and the ML merge loop (up to ~24 queries per segmentation).
    private let sortedWords: [String]
    /// log of the summed unigram counts; segment scores are log-probabilities
    /// (log count − logTotal), so each extra segment costs ~logTotal and the
    /// programme prefers one frequent word over several short fragments.
    private let logTotal: Double

    /// Only the tail of long spaceless runs is segmented (applies to both the
    /// ML model and the DP); suggestions need just the composing word plus two
    /// context words, and this bounds the per-keystroke work.
    private static let windowScalars = 48

    /// The Core ML BiLSTM segmenter (the Android TFLite model). Preferred
    /// over the dictionary DP when available; nil when the model failed to load.
    private let ml: MLWordSegmenter?

    init(counts: [String: Int], maxWordScalars: Int, ml: MLWordSegmenter?) {
        self.counts = counts
        self.maxWordScalars = min(max(maxWordScalars, 1), 24)
        self.sortedWords = counts.keys.sorted(by: Self.scalarLess)
        self.ml = ml
        self.logTotal = log(Double(max(counts.values.reduce(0, +), 1)))
    }

    /// Scalar-lexicographic order, so that all words sharing a prefix are
    /// contiguous and start at the prefix's lower bound.
    private static func scalarLess(_ a: String, _ b: String) -> Bool {
        a.unicodeScalars.lexicographicallyPrecedes(b.unicodeScalars) { $0.value < $1.value }
    }

    /// Whether any dictionary word starts with `prefix` (in-memory; no SQLite).
    private func hasWord(prefix: String) -> Bool {
        var low = 0, high = sortedWords.count
        while low < high {
            let mid = (low + high) / 2
            if Self.scalarLess(sortedWords[mid], prefix) { low = mid + 1 } else { high = mid }
        }
        guard low < sortedWords.count else { return false }
        return sortedWords[low].unicodeScalars.starts(with: prefix.unicodeScalars)
    }

    /// The trailing `windowScalars` of a run (the only part suggestions need).
    /// `truncated` marks that the window may start mid-word.
    private static func window(_ run: String) -> (text: String, truncated: Bool) {
        let scalars = Array(run.unicodeScalars)
        guard scalars.count > windowScalars else { return (run, false) }
        return (String(String.UnicodeScalarView(scalars.suffix(windowScalars))), true)
    }

    struct Split {
        /// Completed words preceding the composing word, oldest first.
        let context: [String]
        /// The (possibly incomplete or unknown) word being typed.
        let composing: String
    }

    /// Split `run` into completed context words plus the trailing composing word.
    func composingSplit(of run: String) -> Split {
        let (windowed, truncated) = Self.window(run)
        if var segments = ml?.segment(windowed), !segments.isEmpty {
            // A truncated window may start mid-word; drop the unreliable first
            // segment (it would only ever be used as distant context).
            if truncated && segments.count > 1 { segments.removeFirst() }
            var composing = segments.removeLast()
            // The model segments complete words; a word still being typed can
            // come out split (សួ + ស្ដ). While the tail is not itself a word
            // but merging with the previous segment stays on the path to a
            // dictionary word (សួស្ដ → សួស្ដី…), merge them.
            while let previous = segments.last, counts[composing] == nil {
                let merged = previous + composing
                guard merged.unicodeScalars.count <= maxWordScalars,
                      counts[merged] != nil || hasWord(prefix: merged) else { break }
                composing = merged
                segments.removeLast()
            }
            return Split(context: segments, composing: composing)
        }
        var segments = segment(windowed, allowTrailingPrefix: true)
        let composing = segments.popLast() ?? ""
        return Split(context: segments, composing: composing)
    }

    /// Segment a completed run (used for next-word prediction context).
    func words(in run: String) -> [String] {
        let (windowed, truncated) = Self.window(run)
        if var segments = ml?.segment(windowed) {
            if truncated && segments.count > 1 { segments.removeFirst() }
            return segments
        }
        return segment(windowed, allowTrailingPrefix: false)
    }

    // MARK: - Dynamic programme

    private struct Best {
        var covered = -1        // scalars matched by dictionary words (-1 = unreached)
        var logSum = 0.0        // sum of segment log-probabilities (tie-break)
        var segments = 0
        var backIndex = 0
        var isUnknown = false
    }

    private func segment(_ run: String, allowTrailingPrefix: Bool) -> [String] {
        let all = Array(run.unicodeScalars)
        guard !all.isEmpty else { return [] }
        let scalars = Array(all.suffix(Self.windowScalars))
        let truncated = all.count > scalars.count
        let n = scalars.count

        var dp = Array(repeating: Best(), count: n + 1)
        dp[0].covered = 0
        for i in 0..<n where dp[i].covered >= 0 {
            // Unknown fallback: advance one scalar (adjacent ones merge below).
            relax(&dp, from: i, to: i + 1, coverage: 0, logProb: -2 * logTotal, unknown: true)
            for len in 1...min(maxWordScalars, n - i) {
                let candidate = String(String.UnicodeScalarView(scalars[i..<(i + len)]))
                if let count = counts[candidate] {
                    relax(&dp, from: i, to: i + len, coverage: len,
                          logProb: log(Double(count) + 1) - logTotal, unknown: false)
                } else if allowTrailingPrefix, i + len == n, hasWord(prefix: candidate) {
                    // The tail starts a longer dictionary word: treat it as the
                    // incomplete composing word (scored like a rare word, so a
                    // complete word covering the same scalars is preferred).
                    relax(&dp, from: i, to: n, coverage: len, logProb: -logTotal, unknown: false)
                }
            }
        }

        // Reconstruct, merging adjacent unknown chunks into single segments.
        var pieces: [(text: String, unknown: Bool)] = []
        var index = n
        while index > 0 {
            let best = dp[index]
            pieces.append((String(String.UnicodeScalarView(scalars[best.backIndex..<index])), best.isUnknown))
            index = best.backIndex
        }
        pieces.reverse()

        var segments: [String] = []
        var lastWasUnknown = false
        for piece in pieces {
            if piece.unknown && lastWasUnknown {
                segments[segments.count - 1] += piece.text
            } else {
                segments.append(piece.text)
            }
            lastWasUnknown = piece.unknown
        }
        // A truncated window may start mid-word; drop the unreliable first
        // segment (it would only ever be used as distant context).
        if truncated && segments.count > 1 {
            segments.removeFirst()
        }
        return segments
    }

    private func relax(_ dp: inout [Best], from i: Int, to j: Int,
                       coverage: Int, logProb: Double, unknown: Bool) {
        let candidate = Best(covered: dp[i].covered + coverage,
                             logSum: dp[i].logSum + logProb,
                             segments: dp[i].segments + 1,
                             backIndex: i,
                             isUnknown: unknown)
        let current = dp[j]
        if candidate.covered > current.covered
            || (candidate.covered == current.covered && candidate.logSum > current.logSum)
            || (candidate.covered == current.covered && candidate.logSum == current.logSum
                && candidate.segments < current.segments) {
            dp[j] = candidate
        }
    }
}
