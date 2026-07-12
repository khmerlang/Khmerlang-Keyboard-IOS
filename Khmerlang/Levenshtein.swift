//
//  Levenshtein.swift
//  Khmerlang
//
//  Keyboard-aware edit distance, ported from the Android Levenshtein class.
//  Substituting a character for a physically adjacent key costs 1; any other
//  substitution costs 2; insertions/deletions cost 1. This biases corrections
//  toward likely fat-finger mistakes.
//
//  Operates on Unicode scalars, not Characters: Swift graphemes cluster Khmer
//  base + combining marks (e.g. "ស្តី" is 2 Characters but 4 scalars), which
//  would both shrink edit distances and defeat the per-key neighbor table.
//  Scalars match the Android implementation's UTF-16 units for this data.
//

import Foundation

enum Levenshtein {

    /// Neighbouring keys per character (QWERTY + the Khmer layout), used to make
    /// adjacent-key substitutions cheap.
    private static let neighbors: [Unicode.Scalar: Set<Unicode.Scalar>] = build([
        // QWERTY
        ("q", "wa"), ("w", "esaq"), ("e", "rdsw"), ("r", "tfde"), ("t", "ygfr"),
        ("y", "uhgt"), ("u", "ijhy"), ("i", "okju"), ("o", "plki"), ("p", "lo"),
        ("a", "qwsz"), ("s", "wedxza"), ("d", "erfcxs"), ("f", "rtgvcd"), ("g", "tyhbvf"),
        ("h", "yujnbg"), ("j", "uikmnh"), ("k", "iolmj"), ("l", "opk"),
        ("z", "asx"), ("x", "sdcz"), ("c", "dfvx"), ("v", "fgbc"), ("b", "ghnv"),
        ("n", "hjmb"), ("m", "jkn"),
        // Khmer — main layer
        ("ំ", "េាៃ"), ("េ", "ំាៃែស"), ("ែ", "េៃសដរ"), ("រ", "ែសដងត"), ("ត", "រដងយទ"),
        ("យ", "តងទុ្"), ("ុ", "យទ្ញិ"), ("ិ", "ុ្ញីក"), ("ី", "ិញកល់"), ("់", "ីកល"),
        ("ា", "ំេៃ"), ("ៃ", "ាំេែសើ"), ("ស", "ៃេែើដរច"), ("ដ", "សែរចងតជ"), ("ង", "ដរតជយទព"),
        ("ទ", "ងតយពុ្ប"), ("្", "ទយុបញិន"), ("ញ", "្ុិនីកម"), ("ក", "ញិីមល់"), ("ល", "កី់"),
        ("ើ", "ៃសច"), ("ច", "ើសដជ"), ("ជ", "ចដងព"), ("ព", "ជងទប"), ("ប", "ពទ្ន"),
        ("ន", "ប្ញម"), ("ម", "នញក"),
        // Khmer — shift layer
        ("ឈ", "ឆៀឿ"), ("ឆ", "ឈៀឿឹឌ"), ("ឹ", "ឆឿឌឺធ"), ("ឺ", "ឹឌធួថ"), ("ួ", "ឺធថូអ"),
        ("ូ", "ួថដោះ"), ("ោ", "ូដះៅហ"), ("ៅ", "ោះហភគ"), ("ភ", "ៅហគផឡ"), ("ផ", "ភគឡ"),
        ("ៀ", "ឈឆឿ"), ("ឿ", "ៀឈឆឹឌឋ"), ("ឌ", "ឿឆឹឋឺធឍ"), ("ធ", "ឌឹឺឍួថខ"), ("ថ", "ធឺួខូអឃ"),
        ("អ", "ថួូឃោះវ"), ("ះ", "អូោវៅហណ"), ("ហ", "ះោៅណភគឲ"), ("គ", "ហៅភឲផឡ"), ("ឡ", "គភផ"),
        ("ឋ", "ឿឌឍ"), ("ឍ", "ឋឌធខ"), ("ខ", "ឍធថឃ"), ("ឃ", "ខថអវ"), ("វ", "ឃអះណ"),
        ("ណ", "វះហឲ"), ("ឲ", "ណហគ"),
    ])

    private static func build(_ pairs: [(Character, String)]) -> [Unicode.Scalar: Set<Unicode.Scalar>] {
        var map: [Unicode.Scalar: Set<Unicode.Scalar>] = [:]
        for (key, chars) in pairs {
            map[key.unicodeScalars.first!] = Set(chars.unicodeScalars)
        }
        // Symmetrise: the hand-written Khmer layers list many pairs in only one
        // direction, which made the distance asymmetric. BK-tree pruning relies
        // on a true metric, so ensure a↔b for every listed pair. (This diverges
        // from the Android table on purpose — the asymmetry there is a bug that
        // silently drops valid correction candidates.)
        for (key, chars) in map {
            for other in chars {
                map[other, default: []].insert(key)
            }
        }
        return map
    }

    private static func costOfSubstitution(_ a: Unicode.Scalar, _ b: Unicode.Scalar) -> Int {
        if a == b { return 0 }
        if neighbors[a]?.contains(b) == true { return 1 }
        return 2
    }

    /// Edit distance between two words using the keyboard-aware substitution cost.
    static func distance(_ lhs: [Unicode.Scalar], _ rhs: [Unicode.Scalar]) -> Int {
        if lhs == rhs { return 0 }
        if lhs.isEmpty { return rhs.count }
        if rhs.isEmpty { return lhs.count }

        let lhsLength = lhs.count + 1
        var cost = Array(0..<lhsLength)
        var newCost = Array(repeating: 0, count: lhsLength)

        for i in 1..<(rhs.count + 1) {
            newCost[0] = i
            for j in 1..<lhsLength {
                let replace = cost[j - 1] + costOfSubstitution(lhs[j - 1], rhs[i - 1])
                let insert = cost[j] + 1
                let delete = newCost[j - 1] + 1
                newCost[j] = min(insert, delete, replace)
            }
            swap(&cost, &newCost)
        }
        return cost[lhsLength - 1]
    }
}
