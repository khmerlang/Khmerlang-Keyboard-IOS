"""Evaluate the trained roman2khmer model on the held-out val split.

Reports top-1/3/5 accuracy overall, broken out by full-spelling vs. prefix
examples, and bucketed by how much of the word was typed -- the accuracy
curve that actually predicts suggestion-bar UX quality. Also dumps the
worst misses for manual review.

Every accuracy number is also reported frequency-weighted (each row
weighted by its word's real sqlite `count`), alongside the plain uniform
number -- since real-world impact is dominated by how often a word is
actually typed, not by giving every held-out example equal say.

Usage: python -m evaluation.evaluate   (run from ml/roman2khmer/)
"""

import sys
from pathlib import Path

import numpy as np
from tensorflow import keras

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config
from training.dataset import load_char_vocab, load_context_vocab, load_split, load_vocab


def topk_hit(probs, labels, k):
    topk = np.argpartition(-probs, kth=k - 1, axis=1)[:, :k]
    return np.array([label in row for label, row in zip(labels, topk)])


def weighted_accuracy(hit_mask, weights):
    return float(np.average(hit_mask, weights=weights))


def fmt(hit1, hit3, hit5, mask, counts):
    # len(...[mask]), not mask.sum(): mask may be a boolean mask or an
    # integer index array (e.g. the typed-fraction buckets below), and
    # summing an index array's values is not the same as counting them.
    w = counts[mask]
    n = len(w)
    return (
        f"n={n:5d}  "
        f"top-1={hit1[mask].mean():.4f} (fw={weighted_accuracy(hit1[mask], w):.4f})  "
        f"top-3={hit3[mask].mean():.4f} (fw={weighted_accuracy(hit3[mask], w):.4f})  "
        f"top-5={hit5[mask].mean():.4f} (fw={weighted_accuracy(hit5[mask], w):.4f})"
    )


def main():
    char_vocab = load_char_vocab()
    vocab = load_vocab()
    context_vocab = load_context_vocab()
    model = keras.models.load_model(config.KERAS_MODEL_PATH)

    X_val, y_val, _w_val, rows = load_split(config.VAL_PATH, char_vocab, context_vocab)
    probs = model.predict(X_val, verbose=0)

    hit1 = topk_hit(probs, y_val, 1)
    hit3 = topk_hit(probs, y_val, 3)
    hit5 = topk_hit(probs, y_val, 5)
    counts = np.array([r["count"] for r in rows], dtype=np.float64)

    print(f"val examples: {len(rows)}")
    all_mask = np.ones(len(rows), dtype=bool)
    print(f"top-1/3/5:  {fmt(hit1, hit3, hit5, all_mask, counts)}")
    print("(fw = frequency-weighted -- weighted by each row's real sqlite word count; "
          "this is the number that predicts real-world auto-commit impact)")

    is_full = np.array([r["is_full"] for r in rows])
    for label, mask in [("full spelling", is_full), ("prefix", ~is_full)]:
        if mask.sum() == 0:
            continue
        print(f"  {label:14s} {fmt(hit1, hit3, hit5, mask, counts)}")

    is_typo = np.array([r["is_typo"] for r in rows])
    for label, mask in [("clean", ~is_typo), ("typo'd", is_typo)]:
        if mask.sum() == 0:
            continue
        print(f"  {label:14s} {fmt(hit1, hit3, hit5, mask, counts)}")

    context_kind = np.array([
        "none" if r["prev"] == config.CONTEXT_UNK else
        "sentence-start" if r["prev"] == config.CONTEXT_S else
        "known word"
        for r in rows
    ])
    print("  by previous-word context:")
    for kind in ("known word", "sentence-start", "none"):
        mask = context_kind == kind
        if mask.sum() == 0:
            continue
        print(f"    {kind:14s} {fmt(hit1, hit3, hit5, mask, counts)}")

    # Bucket prefix examples by how much of the word was typed. Both sides
    # must be in the same unit (romanized characters): row["word"] is the
    # Khmer target word, a different alphabet with a different character
    # count, so it can't be the denominator here -- row["full_len"] (added
    # by data/export_dataset.py) is the length of the full romanized variant
    # this prefix was truncated from.
    prefix_idx = np.where(~is_full)[0]
    if len(prefix_idx) > 0:
        typed_fraction = np.array(
            [len(rows[i]["roman"]) / max(rows[i]["full_len"], 1) for i in prefix_idx]
        )
        quartiles = np.quantile(typed_fraction, [0.25, 0.5, 0.75])
        bucket_edges = [0.0] + list(quartiles) + [1.0]
        print("  by typed fraction (prefix examples only):")
        for lo, hi in zip(bucket_edges[:-1], bucket_edges[1:]):
            sel = prefix_idx[(typed_fraction >= lo) & (typed_fraction <= hi)]
            if len(sel) == 0:
                continue
            print(f"    [{lo:.2f},{hi:.2f}] {fmt(hit1, hit3, hit5, sel, counts)}")

    # Worst misses.
    print("\nworst misses (top-1 wrong), sample:")
    pred1 = probs.argmax(axis=1)
    misses = np.where(~hit1)[0]
    rng = np.random.default_rng(0)
    sample = rng.choice(misses, size=min(20, len(misses)), replace=False)
    for i in sample:
        row = rows[i]
        predicted_word = vocab[pred1[i]]
        in_top3 = "top3-ok" if hit3[i] else "top3-miss"
        print(f"  input={row['roman']!r:15s} expected={row['word']:8s} predicted={predicted_word:8s} [{in_top3}]")


if __name__ == "__main__":
    main()
