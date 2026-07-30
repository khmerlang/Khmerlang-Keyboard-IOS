"""Faithful Python port of the production roman->Khmer corrector, for a
head-to-head comparison against the new ML model on the exact same
held-out val.jsonl set.

Ported from (line-for-line where practical):
  Khmerlang/KhmerlangCorrector.swift  (correctBy: BK-tree search + n-gram
                                        context re-ranking)
  Khmerlang/BKTree.swift              (tree structure + tolerance search)
  Khmerlang/Levenshtein.swift         (keyboard-aware edit distance; the
                                        QWERTY table is shared via data/typo.py)
  Khmerlang/KhmerlangDictionary.swift (counts(for:lang:) -- replicated here
                                        as a direct, identical SQL query
                                        against the same khmerlang.sqlite)

Differences from the app, and why they don't bias the comparison:
  - No custom user mappings / personal lexicon (SharedStore) -- those are
    per-device state with no equivalent in the offline dataset.
  - Only one level of previous-word context is available in val.jsonl
    (matching the new model's single `prev` input), so `tokenOne` (the
    word two positions back) is fixed to "<s>" for every query. This is a
    genuine information handicap for the trigram-scoring tier of the old
    algorithm, but it's the same handicap the new model has -- neither
    system gets two-word context in this test, so the comparison stays
    apples-to-apples.
  - The BK-tree here is built from the FULL Khmer unigram vocabulary (all
    ~22.6k words with a romanization), matching production -- NOT the
    ML model's 6,782-word (count>=5) subset. That's intentional: it's a
    real structural advantage the old system has, and the point of this
    script is to measure it, not hide it.

Usage: python -m comparison.legacy_baseline   (run from ml/roman2khmer/)
"""

import sqlite3
import sys
import time
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config
from data.typo import QWERTY_NEIGHBORS

SAMPLE_SIZE = 3000
SAMPLE_SEED = 0

KHMER_LO, KHMER_HI = 0x1780, 0x17B3  # Levenshtein.swift's "first Khmer consonant/independent-vowel range"


def keyboard_distance(a, b):
    """Keyboard-aware Levenshtein distance, ported from Levenshtein.swift."""
    if a == b:
        return 0
    la, lb = len(a), len(b)
    if la == 0:
        return lb
    if lb == 0:
        return la
    cost = list(range(la + 1))
    new_cost = [0] * (la + 1)
    for i in range(1, lb + 1):
        new_cost[0] = i
        bi = b[i - 1]
        for j in range(1, la + 1):
            aj = a[j - 1]
            if aj == bi:
                sub = 0
            elif bi in QWERTY_NEIGHBORS.get(aj, ()):
                sub = 1
            else:
                sub = 2
            new_cost[j] = min(cost[j - 1] + sub, cost[j] + 1, new_cost[j - 1] + 1)
        cost, new_cost = new_cost, cost
    return cost[la]


class BKNode:
    __slots__ = ("word", "other", "children")

    def __init__(self, word, other):
        self.word = word
        self.other = other
        self.children = {}


class BKTree:
    """Direct port of BKTree.swift."""

    def __init__(self):
        self.root = None

    def add(self, word, other):
        if self.root is None:
            self.root = BKNode(word, other)
            return
        node = self.root
        while True:
            d = keyboard_distance(node.word, word)
            if d == 0:
                node.other = node.other + "_" + other
                return
            child = node.children.get(d)
            if child is None:
                node.children[d] = BKNode(word, other)
                return
            node = child

    def search(self, query, tolerance):
        if self.root is None:
            return []
        results = []
        stack = [self.root]
        while stack:
            node = stack.pop()
            d = keyboard_distance(node.word, query)
            if d <= tolerance:
                results.append((node.word, d, node.other))
            lo, hi = max(1, d - tolerance), d + tolerance
            for dist in range(lo, hi + 1):
                child = node.children.get(dist)
                if child is not None:
                    stack.append(child)
        return results


def tolerance_for(word):
    """Ported from KhmerlangCorrector.correct's length-scaled tolerance."""
    n = len(word)
    if n <= 2:
        return 1
    if n <= 4:
        return 2
    return 3


def tokenize(word, lang_khmer=True):
    """Ported from KhmerlangCorrector.tokenize (lang fixed to Khmer here,
    since every query in this comparison is the roman->Khmer path)."""
    if not word:
        return "<oth>"
    if word in ("<s>", "<s> <s>"):
        return word
    first = word[0]
    if first.isdigit() or ("០" <= first <= "៩"):
        return "<num>"
    if lang_khmer and KHMER_LO <= ord(first) <= KHMER_HI:
        return word
    return "<oth>"


class LegacyCorrector:
    def __init__(self, conn):
        self.conn = conn
        self.tree = BKTree()
        self._search_cache = {}
        self._build_tree()

    def _build_tree(self):
        rows = self.conn.execute(
            "SELECT keyword, other, count FROM ngram "
            "WHERE gram = 1 AND lang = 0 AND keyword != '<s>' ORDER BY count DESC"
        ).fetchall()
        n_variants = 0
        for word, other, _count in rows:
            if not other:
                continue
            for variant in other.split(","):
                romanized = variant.strip().lower()
                if romanized:
                    self.tree.add(romanized, word)
                    n_variants += 1
        print(f"legacy BK-tree: {len(rows)} words, {n_variants} romanized variants inserted")

    def _counts_for(self, keys, lang=0):
        keys = list(keys)
        if not keys:
            return {}
        placeholders = ",".join("?" * len(keys))
        sql = f"SELECT keyword, count FROM ngram WHERE lang = ? AND keyword IN ({placeholders})"
        out = {}
        for keyword, count in self.conn.execute(sql, [lang] + keys):
            out[keyword] = count  # last row wins on duplicate keyword across grams, matching the Swift dict-fill
        return out

    def correct(self, misspelling, token_one, token_two):
        """Direct port of KhmerlangCorrector.correctBy for the roman tree path."""
        tolerance = tolerance_for(misspelling)
        cache_key = (misspelling, tolerance)
        results = self._search_cache.get(cache_key)
        if results is None:
            results = self.tree.search(misspelling, tolerance)
            self._search_cache[cache_key] = results

        candidates = []
        keys = {"<s>", "<s> <s>", "<s> <s> <s>"}
        for _matched_roman, distance, other in results:
            for word in other.lower().split("_"):
                if not word:
                    continue
                candidates.append((word, distance))
                keys.add(word)
                keys.add(f"{token_two} {word}")
                keys.add(f"{token_one} {token_two} {word}")

        if not candidates:
            return []

        counts = self._counts_for(keys)
        tri_context = counts.get("<s> <s> <s>", 0)
        bi_context = counts.get("<s> <s>", 0)
        uni_context = counts.get("<s>", 0)

        scored = []
        for word, distance in candidates:
            weight = 1.0 if distance < 1 else (0.95 if distance <= 2 else (0.6 if distance <= 3 else 0.5))
            tri_key = f"{token_one} {token_two} {word}"
            bi_key = f"{token_two} {word}"
            if distance == 0:
                score = 1.0
            elif tri_key in counts and tri_context > 0:
                score = weight * counts[tri_key] / tri_context
            elif bi_key in counts and bi_context > 0:
                score = 0.4 * weight * counts[bi_key] / bi_context
            elif word in counts and uni_context > 0:
                score = 0.4 * 0.4 * weight * counts[word] / uni_context
            else:
                score = 0.0
            scored.append((word, score))

        scored.sort(key=lambda item: -item[1])

        seen = set()
        output = []
        for word, _score in scored:
            if word not in seen:
                seen.add(word)
                output.append(word)
                if len(output) >= 10:
                    break
        return output


def main():
    conn = sqlite3.connect(str(config.SQLITE_PATH))
    corrector = LegacyCorrector(conn)

    rows = []
    with open(config.VAL_PATH, encoding="utf-8") as f:
        import json
        for line in f:
            line = line.strip()
            if line:
                rows.append(json.loads(line))

    rng = np.random.default_rng(SAMPLE_SEED)
    sample_idx = rng.choice(len(rows), size=min(SAMPLE_SIZE, len(rows)), replace=False)
    sample = [rows[i] for i in sample_idx]

    t0 = time.time()
    hit1 = hit3 = hit5 = 0
    for i, row in enumerate(sample):
        token_one = "<s>"  # unavailable in val.jsonl -- see module docstring
        token_two = tokenize(row["prev"])
        ranked = corrector.correct(row["roman"], token_one, token_two)
        if ranked and ranked[0] == row["word"]:
            hit1 += 1
        if row["word"] in ranked[:3]:
            hit3 += 1
        if row["word"] in ranked[:5]:
            hit5 += 1
        if (i + 1) % 500 == 0:
            elapsed = time.time() - t0
            print(f"  {i + 1}/{len(sample)} ({elapsed:.1f}s, {elapsed / (i + 1) * 1000:.1f}ms/query)")

    n = len(sample)
    elapsed = time.time() - t0
    print(f"\nlegacy corrector (BK-tree + n-gram rerank), n={n}, {elapsed:.1f}s total")
    print(f"top-1: {hit1 / n:.4f}  top-3: {hit3 / n:.4f}  top-5: {hit5 / n:.4f}")

    sample_idx_path = config.MODEL_DIR / "legacy_baseline_sample_idx.npy"
    config.MODEL_DIR.mkdir(parents=True, exist_ok=True)
    np.save(sample_idx_path, sample_idx)
    print(f"saved sample indices to {sample_idx_path} (for the new-model side-by-side script)")


if __name__ == "__main__":
    main()
