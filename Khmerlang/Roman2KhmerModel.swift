//
//  Roman2KhmerModel.swift
//  Khmerlang
//
//  Roman→Khmer transliteration for the suggestion bar, replacing the fuzzy
//  roman BK-tree lookup. Two layers, per ml/roman2khmer/dist/README.md:
//    1. Exact-match shortcut (Roman2KhmerShortcut.json): romanizations that
//       map unambiguously to exactly one Khmer word — top-1 when hit.
//    2. The v3 CoreML model (Roman2Khmer.mlmodelc): chars typed so far plus
//       the previous Khmer word as context, softmax over the 6,782-word
//       vocabulary — fills the ranked list, including the ambiguous
//       romanizations the shortcut intentionally leaves out.
//
//  Ships precompiled as Roman2Khmer.mlmodelc; loads CPU-only (extensions
//  have no GPU access), inference is well under 1ms per keystroke.
//

import CoreML
import Foundation

final class Roman2KhmerModel {

    private struct CharVocab: Decodable {
        let padIndex: Int
        let unkIndex: Int
        let chars: [String: Int]
        let maxLen: Int

        enum CodingKeys: String, CodingKey {
            case padIndex = "pad_index"
            case unkIndex = "unk_index"
            case chars
            case maxLen = "max_len"
        }
    }

    private let model: MLModel
    private let charVocab: CharVocab
    /// Output index → Khmer word.
    private let vocab: [String]
    /// Previous Khmer word → `prev` input index. Index 0 = <unk> (no reliable
    /// context), index 1 = <s> (sentence start).
    private let contextIndex: [String: Int]
    /// Romanization → its single unambiguous Khmer word.
    private let shortcut: [String: String]

    init?(bundle: Bundle = .main) {
        guard let modelURL = bundle.url(forResource: "Roman2Khmer", withExtension: "mlmodelc"),
              let charVocabURL = bundle.url(forResource: "Roman2KhmerCharVocab", withExtension: "json"),
              let vocabURL = bundle.url(forResource: "Roman2KhmerVocab", withExtension: "json"),
              let contextURL = bundle.url(forResource: "Roman2KhmerContextVocab", withExtension: "json"),
              let shortcutURL = bundle.url(forResource: "Roman2KhmerShortcut", withExtension: "json") else {
            return nil
        }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuOnly   // no GPU in keyboard extensions
        let decoder = JSONDecoder()
        guard let model = try? MLModel(contentsOf: modelURL, configuration: configuration),
              let charVocab = try? decoder.decode(CharVocab.self, from: Data(contentsOf: charVocabURL)),
              let vocab = try? decoder.decode([String].self, from: Data(contentsOf: vocabURL)),
              let contextVocab = try? decoder.decode([String].self, from: Data(contentsOf: contextURL)),
              let shortcut = try? decoder.decode([String: String].self, from: Data(contentsOf: shortcutURL)) else {
            return nil
        }
        self.model = model
        self.charVocab = charVocab
        self.vocab = vocab
        var contextIndex: [String: Int] = [:]
        contextIndex.reserveCapacity(contextVocab.count)
        for (index, word) in contextVocab.enumerated() { contextIndex[word] = index }
        self.contextIndex = contextIndex
        self.shortcut = shortcut
    }

    /// Ranked Khmer candidates for the romanized `word` typed so far: the
    /// shortcut's exact match first (when it hits), then the model's top
    /// predictions. `prevWord` is the immediately preceding Khmer word
    /// ("<s>" or `isStartSentence` marks a sentence start).
    func suggestions(for word: String, prevWord: String, isStartSentence: Bool,
                     limit: Int) -> [String] {
        let lower = word.lowercased()
        var output: [String] = []
        if let exact = shortcut[lower] {
            output.append(exact)
        }
        for candidate in predict(lower, prevWord: prevWord, isStartSentence: isStartSentence,
                                 limit: limit) where !output.contains(candidate) {
            output.append(candidate)
            if output.count >= limit { break }
        }
        return output
    }

    private func predict(_ lower: String, prevWord: String, isStartSentence: Bool,
                         limit: Int) -> [String] {
        guard let chars = try? MLMultiArray(shape: [1, NSNumber(value: charVocab.maxLen)],
                                            dataType: .int32),
              let prev = try? MLMultiArray(shape: [1], dataType: .int32) else { return [] }
        for i in 0..<charVocab.maxLen { chars[i] = NSNumber(value: charVocab.padIndex) }
        for (i, character) in lower.prefix(charVocab.maxLen).enumerated() {
            chars[i] = NSNumber(value: charVocab.chars[String(character)] ?? charVocab.unkIndex)
        }
        let prevIndex = (isStartSentence || prevWord == "<s>")
            ? (contextIndex["<s>"] ?? 0)
            : (contextIndex[prevWord] ?? 0)
        prev[0] = NSNumber(value: prevIndex)

        guard let provider = try? MLDictionaryFeatureProvider(dictionary: [
                  "chars": MLFeatureValue(multiArray: chars),
                  "prev": MLFeatureValue(multiArray: prev)
              ]),
              let outputs = try? model.prediction(from: provider),
              let probabilities = outputs.featureValue(for: "Identity")?.multiArrayValue,
              probabilities.count == vocab.count else {
            return []
        }

        // Partial selection of the top `limit` indices: keep a small sorted
        // slate instead of sorting all 6,782 scores every keystroke.
        var top: [(index: Int, probability: Double)] = []
        top.reserveCapacity(limit + 1)
        for index in 0..<vocab.count {
            let probability = probabilities[index].doubleValue
            if top.count < limit || probability > top[top.count - 1].probability {
                let position = top.firstIndex { probability > $0.probability } ?? top.count
                top.insert((index, probability), at: position)
                if top.count > limit { top.removeLast() }
            }
        }
        return top.map { vocab[$0.index] }
    }
}
