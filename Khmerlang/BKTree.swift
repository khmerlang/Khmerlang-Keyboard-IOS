//
//  BKTree.swift
//  Khmerlang
//
//  Burkhard-Keller tree over the keyboard-aware edit distance, ported from the
//  Android Bktree. Enables retrieval of all dictionary words within a given edit
//  distance of a query word (used for fuzzy spelling correction and roman→Khmer).
//
//  Nodes store only the word string (Swift's small-string optimisation keeps
//  short words inline); characters are derived on demand to keep three trees
//  comfortably within the keyboard extension's memory budget.
//

import Foundation

final class BKTreeNode {
    let word: String
    var other: String
    var children: [Int: BKTreeNode] = [:]

    init(word: String, other: String) {
        self.word = word
        self.other = other
    }
}

struct BKResult {
    let word: String
    let distance: Int
    let other: String
}

final class BKTree {
    private(set) var root: BKTreeNode?

    func add(_ word: String, other: String) {
        guard let root else {
            self.root = BKTreeNode(word: word, other: other)
            return
        }
        add(node: root, chars: Array(word.unicodeScalars), word: word, other: other)
    }

    private func add(node: BKTreeNode, chars: [Unicode.Scalar], word: String, other: String) {
        let distance = Levenshtein.distance(Array(node.word.unicodeScalars), chars)
        if distance == 0 {
            // Same word already present: accumulate the alternate payload.
            node.other = node.other + "_" + other
            return
        }
        if let child = node.children[distance] {
            add(node: child, chars: chars, word: word, other: other)
        } else {
            node.children[distance] = BKTreeNode(word: word, other: other)
        }
    }

    /// All words within `tolerance` edit distance of `query`.
    func search(_ query: [Unicode.Scalar], tolerance: Int) -> [BKResult] {
        guard let root else { return [] }
        var results: [BKResult] = []
        search(node: root, query: query, tolerance: tolerance, into: &results)
        return results
    }

    private func search(node: BKTreeNode, query: [Unicode.Scalar], tolerance: Int, into results: inout [BKResult]) {
        // Same argument order as add(node:chars:) — the tree's pruning is only
        // valid when insertion and lookup measure distance identically.
        let distance = Levenshtein.distance(Array(node.word.unicodeScalars), query)
        if distance <= tolerance {
            results.append(BKResult(word: node.word, distance: distance, other: node.other))
        }
        let start = max(1, distance - tolerance)
        let end = distance + tolerance
        if start <= end {
            for dist in start...end {
                if let child = node.children[dist] {
                    search(node: child, query: query, tolerance: tolerance, into: &results)
                }
            }
        }
    }
}
