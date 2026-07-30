"""Head-to-head: v2 (log1p sample-weighting) vs v3 (frequency oversampling)
vs the exact-match shortcut layer (on top of either), broken out by whether
the word is one of the SHORTCUT_TOP_N highest-frequency words or not --
that split is the point, since the whole experiment is about whether
common words reliably surface.

Usage: python -m comparison.compare_all   (run from ml/roman2khmer/, after
       training.train_v3 has produced roman2khmer_v3.keras)
"""

import sys
from pathlib import Path

import numpy as np
from tensorflow import keras

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config
from training.dataset import load_char_vocab, load_context_vocab, load_split, load_vocab
from comparison.shortcut import apply_shortcut, build_shortcut_map

TOP_N = config.SHORTCUT_TOP_N


def top5_words(probs, vocab, k=5):
    idx = np.argpartition(-probs, kth=k - 1, axis=1)[:, :k]
    row_scores = np.take_along_axis(probs, idx, axis=1)
    order = np.argsort(-row_scores, axis=1)
    idx_sorted = np.take_along_axis(idx, order, axis=1)
    return [[vocab[i] for i in row] for row in idx_sorted]


def score(top5_lists, rows, mask=None):
    n = 0
    hit1 = hit3 = hit5 = 0
    for i, (top5, row) in enumerate(zip(top5_lists, rows)):
        if mask is not None and not mask[i]:
            continue
        n += 1
        expected = row["word"]
        if top5 and top5[0] == expected:
            hit1 += 1
        if expected in top5[:3]:
            hit3 += 1
        if expected in top5[:5]:
            hit5 += 1
    if n == 0:
        return None
    return n, hit1 / n, hit3 / n, hit5 / n


def print_row(label, result):
    if result is None:
        print(f"  {label:20s} (no examples)")
        return
    n, t1, t3, t5 = result
    print(f"  {label:20s} n={n:6d}  top-1={t1:.4f}  top-3={t3:.4f}  top-5={t5:.4f}")


def evaluate(name, model_path, X_val, rows, vocab, is_top_n, shortcut_map):
    model = keras.models.load_model(model_path, safe_mode=False)
    probs = model.predict(X_val, verbose=0)
    top5 = top5_words(probs, vocab)
    top5_sc = [apply_shortcut(row["roman"], t5, shortcut_map, row["is_full"]) for row, t5 in zip(rows, top5)]

    print(f"\n=== {name} ===")
    print_row("overall", score(top5, rows))
    print_row(f"top-{TOP_N} words", score(top5, rows, is_top_n))
    print_row("rest of vocab", score(top5, rows, ~np.array(is_top_n)))

    print(f"\n=== {name} + shortcut ===")
    print_row("overall", score(top5_sc, rows))
    print_row(f"top-{TOP_N} words", score(top5_sc, rows, is_top_n))
    print_row("rest of vocab", score(top5_sc, rows, ~np.array(is_top_n)))


def main():
    char_vocab = load_char_vocab()
    context_vocab = load_context_vocab()
    vocab = load_vocab()

    X_val, y_val, _w_val, rows = load_split(config.VAL_PATH, char_vocab, context_vocab)
    is_top_n = y_val < TOP_N

    shortcut_map = build_shortcut_map(vocab, TOP_N)
    print(f"shortcut map: {len(shortcut_map)} exact romanizations covering top {TOP_N} words")

    evaluate("v2 (log1p sample-weight)", config.KERAS_MODEL_V2_PATH, X_val, rows, vocab, is_top_n, shortcut_map)

    if config.KERAS_MODEL_V3_PATH.exists():
        evaluate("v3 (frequency oversampling)", config.KERAS_MODEL_V3_PATH, X_val, rows, vocab, is_top_n, shortcut_map)
    else:
        print(f"\n{config.KERAS_MODEL_V3_PATH} not found yet -- skipping v3")


if __name__ == "__main__":
    main()
