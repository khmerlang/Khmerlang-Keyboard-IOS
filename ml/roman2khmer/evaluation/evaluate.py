"""Evaluate the trained roman2khmer model on the held-out val split.

Reports top-1/3/5 accuracy overall, broken out by full-spelling vs. prefix
examples, and bucketed by how much of the word was typed -- the accuracy
curve that actually predicts suggestion-bar UX quality. Also dumps the
worst misses for manual review.

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

    print(f"val examples: {len(rows)}")
    print(f"top-1: {hit1.mean():.4f}  top-3: {hit3.mean():.4f}  top-5: {hit5.mean():.4f}")

    is_full = np.array([r["is_full"] for r in rows])
    for label, mask in [("full spelling", is_full), ("prefix", ~is_full)]:
        if mask.sum() == 0:
            continue
        print(
            f"  {label:14s} n={mask.sum():5d}  "
            f"top-1={hit1[mask].mean():.4f}  top-3={hit3[mask].mean():.4f}  top-5={hit5[mask].mean():.4f}"
        )

    is_typo = np.array([r["is_typo"] for r in rows])
    for label, mask in [("clean", ~is_typo), ("typo'd", is_typo)]:
        if mask.sum() == 0:
            continue
        print(
            f"  {label:14s} n={mask.sum():5d}  "
            f"top-1={hit1[mask].mean():.4f}  top-3={hit3[mask].mean():.4f}  top-5={hit5[mask].mean():.4f}"
        )

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
        print(
            f"    {kind:14s} n={mask.sum():5d}  "
            f"top-1={hit1[mask].mean():.4f}  top-3={hit3[mask].mean():.4f}  top-5={hit5[mask].mean():.4f}"
        )

    # Bucket prefix examples by how much of the word was typed.
    prefix_idx = np.where(~is_full)[0]
    if len(prefix_idx) > 0:
        typed_fraction = np.array(
            [len(rows[i]["roman"]) / max(len(rows[i]["word"]), 1) for i in prefix_idx]
        )
        quartiles = np.quantile(typed_fraction, [0.25, 0.5, 0.75])
        bucket_edges = [0.0] + list(quartiles) + [1.0]
        print("  by typed fraction (prefix examples only):")
        for lo, hi in zip(bucket_edges[:-1], bucket_edges[1:]):
            sel = prefix_idx[(typed_fraction >= lo) & (typed_fraction <= hi)]
            if len(sel) == 0:
                continue
            print(
                f"    [{lo:.2f},{hi:.2f}] n={len(sel):5d}  "
                f"top-1={hit1[sel].mean():.4f}  top-3={hit3[sel].mean():.4f}  top-5={hit5[sel].mean():.4f}"
            )

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
