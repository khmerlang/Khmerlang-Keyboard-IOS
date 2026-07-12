//
//  MLWordSegmenter.swift
//  Khmerlang
//
//  Core ML port of the Android TFLite Khmer word-segmentation model
//  (WordSegModel: Embedding(114×256) → BiLSTM(64) → BiLSTM(32) →
//  Dense(64, relu) → Dense(1) logits; sigmoid ≥ 0.55 marks a word start).
//  Converted offline with tools/convert_wordseg_to_coreml.py and validated
//  against the original .tflite to a max output difference of 4e-4.
//
//  Ships precompiled as WordSegModel.mlmodelc; loads CPU-only (extensions
//  have no GPU access) at ~13ms per inference, cached per run.
//

import CoreML
import Foundation

final class MLWordSegmenter {

    static let maxScalars = 328
    private static let threshold = 0.55
    private static let vocabularySize = 114

    /// Character table copied from the Android WordTokenizer (index 0 = pad,
    /// 1 = unknown). Iterated as Unicode scalars — several entries are
    /// combining marks that would merge in a Character view. Entries beyond
    /// the embedding's 114-entry vocabulary map to unknown.
    private static let scalarIndex: [Unicode.Scalar: Int] = {
        let table = "P" + "U"
            + "កខគឃងចឆជឈញដឋឌឍណតថទធនបផពភមយរលវឝឞសហឡអឣឤឥឦឧឨឩឪឫឬឭឮឯឰឱឲឳ"
            + "឴឵ាិីឹឺុូួើឿៀេែៃោៅំះៈ"
            + "្"
            + "៉៊់៌៍៎៏័"
            + "៕។៛ៗ៚៙៘,.? "
            + "០១២៣៤៥៦៧៨៩0123456789"
        var map: [Unicode.Scalar: Int] = [:]
        for (index, scalar) in table.unicodeScalars.enumerated() where index < vocabularySize {
            map[scalar] = index
        }
        return map
    }()

    private let model: MLModel
    /// Last run → segments, so the several context queries per keystroke run
    /// inference once (the Android prevInput/prevSeg cache).
    private var cache: (input: String, output: [String])?

    convenience init?(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "WordSegModel", withExtension: "mlmodelc") else {
            return nil
        }
        self.init(modelURL: url)
    }

    init?(modelURL: URL) {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuOnly   // no GPU in keyboard extensions
        guard let model = try? MLModel(contentsOf: modelURL, configuration: configuration) else {
            return nil
        }
        self.model = model
    }

    /// Word segments of a spaceless Khmer run, or nil when the model cannot
    /// process it (run too long, inference failure) and the caller should
    /// fall back to the dictionary DP.
    func segment(_ run: String) -> [String]? {
        let scalars = Array(run.unicodeScalars)
        guard !scalars.isEmpty, scalars.count <= Self.maxScalars else { return nil }
        if let cache, cache.input == run { return cache.output }

        guard let input = try? MLMultiArray(shape: [1, NSNumber(value: Self.maxScalars)], dataType: .int32) else {
            return nil
        }
        for (i, scalar) in scalars.enumerated() {
            input[i] = NSNumber(value: Self.scalarIndex[scalar] ?? 1)
        }
        guard let provider = try? MLDictionaryFeatureProvider(dictionary: ["chars": MLFeatureValue(multiArray: input)]),
              let output = try? model.prediction(from: provider),
              let logits = output.featureValue(for: "Identity")?.multiArrayValue else {
            return nil
        }

        var words: [String] = []
        var current = ""
        for (i, scalar) in scalars.enumerated() {
            let probability = 1.0 / (1.0 + exp(-logits[i].doubleValue))
            if probability >= Self.threshold && !current.isEmpty {
                words.append(current)
                current = String(scalar)
            } else {
                current.unicodeScalars.append(scalar)
            }
        }
        if !current.isEmpty {
            words.append(current)
        }
        cache = (run, words)
        return words
    }
}
