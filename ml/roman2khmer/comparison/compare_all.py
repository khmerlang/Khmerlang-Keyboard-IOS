"""Head-to-head: v2 (log1p sample-weighting) vs v3 (frequency oversampling)
vs the exact-match shortcut layer (on top of either), broken out by whether
the word is one of the SHORTCUT_TOP_N highest-frequency words or not --
that split is the point, since the whole experiment is about whether
common words reliably surface.

Also compares the historical top-N-only shortcut against the extended
shortcut (every romanization that's unambiguous across the full sqlite
table, not just the top-N words -- see comparison/shortcut.py), and splits
results by "deterministic-reachable" (word has at least one unambiguous
romanization) vs "ML-only" (word depends entirely on ambiguous spellings) --
the latter is exactly the population any future oversampling/model work
should target, since the deterministic layer already solves the rest.

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
    """Returns (n, top1, top3, top5, wtop1, wtop3, wtop5) -- the `w`-prefixed
    values are frequency-weighted by each row's real sqlite word count, the
    number that predicts real-world auto-commit impact."""
    n = 0
    total_w = 0.0
    hit1 = hit3 = hit5 = 0
    whit1 = whit3 = whit5 = 0.0
    for i, (top5, row) in enumerate(zip(top5_lists, rows)):
        if mask is not None and not mask[i]:
            continue
        n += 1
        w = row["count"]
        total_w += w
        expected = row["word"]
        if top5 and top5[0] == expected:
            hit1 += 1
            whit1 += w
        if expected in top5[:3]:
            hit3 += 1
            whit3 += w
        if expected in top5[:5]:
            hit5 += 1
            whit5 += w
    if n == 0:
        return None
    return n, hit1 / n, hit3 / n, hit5 / n, whit1 / total_w, whit3 / total_w, whit5 / total_w


def print_row(label, result):
    if result is None:
        print(f"  {label:20s} (no examples)")
        return
    n, t1, t3, t5, wt1, wt3, wt5 = result
    print(
        f"  {label:20s} n={n:6d}  "
        f"top-1={t1:.4f} (fw={wt1:.4f})  top-3={t3:.4f} (fw={wt3:.4f})  top-5={t5:.4f} (fw={wt5:.4f})"
    )


def evaluate(name, model_path, X_val, rows, vocab, is_top_n, is_reachable, shortcut_map_top500, shortcut_map_full):
    model = keras.models.load_model(model_path, safe_mode=False)
    probs = model.predict(X_val, verbose=0)
    top5 = top5_words(probs, vocab)
    top5_sc500 = [apply_shortcut(row["roman"], t5, shortcut_map_top500, row["is_full"]) for row, t5 in zip(rows, top5)]
    top5_scfull = [apply_shortcut(row["roman"], t5, shortcut_map_full, row["is_full"]) for row, t5 in zip(rows, top5)]

    print(f"\n=== {name} ===")
    print_row("overall", score(top5, rows))
    print_row(f"top-{TOP_N} words", score(top5, rows, is_top_n))
    print_row("rest of vocab", score(top5, rows, ~np.array(is_top_n)))

    print(f"\n=== {name} + shortcut (top-{TOP_N}, historical) ===")
    print_row("overall", score(top5_sc500, rows))
    print_row(f"top-{TOP_N} words", score(top5_sc500, rows, is_top_n))
    print_row("rest of vocab", score(top5_sc500, rows, ~np.array(is_top_n)))

    print(f"\n=== {name} + extended shortcut (all unambiguous) ===")
    print_row("overall", score(top5_scfull, rows))
    print_row(f"top-{TOP_N} words", score(top5_scfull, rows, is_top_n))
    print_row("rest of vocab", score(top5_scfull, rows, ~np.array(is_top_n)))
    print_row("deterministic-reachable", score(top5_scfull, rows, is_reachable))
    print_row("ML-only (fully ambiguous)", score(top5_scfull, rows, ~is_reachable))


def main():
    char_vocab = load_char_vocab()
    context_vocab = load_context_vocab()
    vocab = load_vocab()

    X_val, y_val, _w_val, rows = load_split(config.VAL_PATH, char_vocab, context_vocab)
    is_top_n = y_val < TOP_N

    shortcut_map_full = build_shortcut_map()
    shortcut_map_top500 = build_shortcut_map(restrict_to=vocab[:TOP_N])
    print(f"extended shortcut map: {len(shortcut_map_full)} exact romanizations (all unambiguous)")
    print(f"historical shortcut map: {len(shortcut_map_top500)} exact romanizations covering top {TOP_N} words")

    words_with_unambig = set(shortcut_map_full.values())
    is_reachable = np.array([row["word"] in words_with_unambig for row in rows])
    reachable_in_vocab = words_with_unambig & set(vocab)
    print(f"model-vocab words with >=1 unambiguous romanization: {len(reachable_in_vocab)}/{len(vocab)}")

    evaluate(
        "v2 (log1p sample-weight)", config.KERAS_MODEL_PATH, X_val, rows, vocab,
        is_top_n, is_reachable, shortcut_map_top500, shortcut_map_full,
    )

    if config.KERAS_MODEL_V3_PATH.exists():
        evaluate(
            "v3 (frequency oversampling)", config.KERAS_MODEL_V3_PATH, X_val, rows, vocab,
            is_top_n, is_reachable, shortcut_map_top500, shortcut_map_full,
        )
    else:
        print(f"\n{config.KERAS_MODEL_V3_PATH} not found yet -- skipping v3")

    if config.KERAS_MODEL_V4_PATH.exists():
        evaluate(
            "v4 (ambiguous-focused oversampling)", config.KERAS_MODEL_V4_PATH, X_val, rows, vocab,
            is_top_n, is_reachable, shortcut_map_top500, shortcut_map_full,
        )
    else:
        print(f"\n{config.KERAS_MODEL_V4_PATH} not found yet -- skipping v4")


if __name__ == "__main__":
    main()
