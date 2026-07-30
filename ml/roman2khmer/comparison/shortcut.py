"""Exact-match shortcut layer: for every romanization that maps unambiguously
to exactly one Khmer word across the full khmerlang.sqlite unigram table, if
the typed input exactly matches it, force that word to rank 1 (ahead of
whatever the model predicted), keeping the model's own ranking to fill out
the rest of the top-5.

This is a hard, guaranteed-correct dictionary lookup, decoupled from the
model's shared softmax -- ambiguity is checked against the *entire* table
(not just a frequency-ranked subset), so a romanization is only ever
force-guessed when it truly has one possible Khmer word. Romanizations
shared by multiple words (homographs in romanized spelling) are left out on
purpose and fall through to the model, whose `prev` context input exists
specifically to disambiguate those using the previous word.

See comparison/compare_all.py for the head-to-head against the model alone.
"""

import sqlite3
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config


def build_shortcut_map(restrict_to=None):
    """Returns {romanization: khmer_word} for every romanization in
    khmerlang.sqlite's Khmer-unigram table that maps to exactly one word.

    `restrict_to`, if given, is an iterable of words; the already-resolved
    map is filtered down to entries whose word is in that set. This does
    NOT change what counts as ambiguous (ambiguity is always checked against
    the full table) -- it only limits which resolved entries are returned,
    e.g. to reproduce a frequency-ranked subset for comparison.
    """
    conn = sqlite3.connect(str(config.SQLITE_PATH))
    rows = conn.execute(
        "SELECT keyword, other FROM ngram WHERE gram = 1 AND lang = 0 AND other != '' AND keyword != '<s>'"
    ).fetchall()
    conn.close()

    variant_to_words = defaultdict(set)
    for word, other in rows:
        for variant in other.split(","):
            v = variant.strip().lower()
            if v and config.ROMAN_RE.match(v):
                variant_to_words[v].add(word)

    shortcut = {v: next(iter(ws)) for v, ws in variant_to_words.items() if len(ws) == 1}

    if restrict_to is not None:
        allowed = set(restrict_to)
        shortcut = {v: w for v, w in shortcut.items() if w in allowed}

    return shortcut


def apply_shortcut(roman, model_top5, shortcut_map, is_full):
    """`is_full` gates the shortcut to only fire once the user has actually
    finished typing a recognized word. Without it, a mid-word prefix that
    happens to coincide character-for-character with a known word's full
    spelling (e.g. "kar" is the complete romanization of a common word but
    could also be 3 characters into an unrelated longer word) would wrongly
    hijack the prediction -- confirmed empirically: ~13.5% of val's prefix
    (non-full) rows collide with an exact shortcut spelling this way (up
    from ~10% measured against the old, much smaller top-500-only map --
    a bigger map covers more prefixes too). Re-measure this rate whenever
    the map's size changes meaningfully (see evaluation.evaluate or a
    one-off check against val.jsonl); `is_full` already fully prevents it
    from ever affecting a real prediction regardless of the rate."""
    if not is_full:
        return model_top5
    hit = shortcut_map.get(roman)
    if hit is None:
        return model_top5
    rest = [w for w in model_top5 if w != hit]
    return [hit] + rest[:4]
