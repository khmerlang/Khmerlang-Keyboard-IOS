"""Exact-match shortcut layer: for the SHORTCUT_TOP_N highest-frequency
words, if the typed input exactly matches one of their known romanizations,
force that word to rank 1 (ahead of whatever the model predicted), keeping
the model's own ranking to fill out the rest of the top-5.

This is a hard guarantee for the common case, decoupled from the model's
shared softmax -- an alternative (or complement) to oversampling common
words during training. See comparison/compare_all.py for the head-to-head.
"""

import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config
from data.export_dataset import ROMAN_RE


def build_shortcut_map(vocab, top_n=config.SHORTCUT_TOP_N):
    """vocab is assumed sorted by frequency descending (as vocab.json is)."""
    top_words = set(vocab[:top_n])
    conn = sqlite3.connect(str(config.SQLITE_PATH))
    rows = conn.execute(
        "SELECT keyword, other FROM ngram WHERE gram = 1 AND lang = 0 AND other != ''"
    ).fetchall()
    conn.close()

    shortcut = {}
    # vocab is frequency-descending, so processing words in that order and
    # only ever inserting (never overwriting) resolves any exact-variant
    # collision between two top-N words in favor of the more frequent one.
    by_word = {word: other for word, other in rows}
    for word in vocab[:top_n]:
        other = by_word.get(word, "")
        for variant in other.split(","):
            v = variant.strip().lower()
            if v and ROMAN_RE.match(v) and v not in shortcut:
                shortcut[v] = word
    return shortcut


def apply_shortcut(roman, model_top5, shortcut_map, is_full):
    """`is_full` gates the shortcut to only fire once the user has actually
    finished typing a recognized word. Without it, a mid-word prefix that
    happens to coincide character-for-character with a common word's full
    spelling (e.g. "kar" is the complete romanization of a top-500 word but
    could also be 3 characters into an unrelated longer word) would wrongly
    hijack the prediction -- confirmed empirically: ~10% of val's prefix
    (non-full) rows collide with a top-500 exact spelling this way."""
    if not is_full:
        return model_top5
    hit = shortcut_map.get(roman)
    if hit is None:
        return model_top5
    rest = [w for w in model_top5 if w != hit]
    return [hit] + rest[:4]
