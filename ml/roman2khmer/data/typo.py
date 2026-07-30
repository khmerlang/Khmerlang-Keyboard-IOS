"""Keyboard-aware typo noise for training-data augmentation.

QWERTY_NEIGHBORS is ported from the roman half of the adjacency table in
Khmerlang/Levenshtein.swift, so the noise this generates matches the same
"physically adjacent key" model the app's own fuzzy matcher already uses.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config

_PAIRS = [
    ("q", "wa"), ("w", "esaq"), ("e", "rdsw"), ("r", "tfde"), ("t", "ygfr"),
    ("y", "uhgti"), ("u", "ijhy"), ("i", "okjuy"), ("o", "plki"), ("p", "lo"),
    ("a", "qwsz"), ("s", "wedxza"), ("d", "erfcxs"), ("f", "rtgvcd"), ("g", "tyhbvf"),
    ("h", "yujnbg"), ("j", "uikmnh"), ("k", "iolmj"), ("l", "opk"),
    ("z", "asx"), ("x", "sdcz"), ("c", "dfvx"), ("v", "fgbc"), ("b", "ghnv"),
    ("n", "hjmb"), ("m", "jkn"),
]


def _build_neighbors():
    neighbors = {}
    for key, chars in _PAIRS:
        neighbors.setdefault(key, set()).update(chars)
    for key, chars in list(neighbors.items()):
        for other in chars:
            neighbors.setdefault(other, set()).add(key)
    return neighbors


QWERTY_NEIGHBORS = _build_neighbors()


def apply_typo(text, rng):
    """Returns a single-edit noisy copy of text, or text unchanged if too short."""
    if len(text) < config.MIN_LEN_FOR_TYPO:
        return text

    op = rng.choice(("sub", "del", "ins", "transpose"))
    i = rng.randrange(len(text))

    if op == "sub":
        neighbors = QWERTY_NEIGHBORS.get(text[i])
        if not neighbors:
            return text
        c = rng.choice(sorted(neighbors))
        return text[:i] + c + text[i + 1:]
    if op == "del":
        return text[:i] + text[i + 1:]
    if op == "ins":
        c = rng.choice(config.CHARS)
        return text[:i] + c + text[i:]
    # transpose adjacent characters
    if i == len(text) - 1:
        i -= 1
    return text[:i] + text[i + 1] + text[i] + text[i + 2:]
