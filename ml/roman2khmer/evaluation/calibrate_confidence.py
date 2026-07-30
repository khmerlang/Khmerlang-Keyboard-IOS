"""Calibrate a confidence threshold for the ML-fallback population -- the
words a future auto-commit gate would actually have to decide about after
the deterministic exact-match shortcut (comparison/shortcut.py) has already
resolved every unambiguous romanization.

Restricts to `is_full` rows (a real space-press only ever considers a fully
typed word) that the shortcut does NOT resolve (`roman` not a shortcut key),
sweeps the model's top-1 softmax confidence, and reports, for each
confidence threshold: what fraction of that fallback population it would
accept (coverage) and what fraction of accepted predictions are actually
correct (precision) -- both plain and frequency-weighted by each row's real
sqlite word count, since real-world auto-commit safety is dominated by how
often a word is actually typed.

For each target in config.CONFIDENCE_TARGET_PRECISIONS, reports the lowest
threshold whose frequency-weighted precision clears that bar, and the
coverage it buys -- a trade-off menu, not one opinionated cutoff. The full
sweep + recommendations are written to config.CONFIDENCE_CALIBRATION_PATH
for reference; conversion/export_dist.py reuses compute_calibration() to
ship a small summary in dist/confidence.json.

Usage: python -m evaluation.calibrate_confidence   (run from ml/roman2khmer/,
       after training.train_v3 has produced roman2khmer_v3.keras)
"""

import json
import sys
from pathlib import Path

import numpy as np
from tensorflow import keras

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config
from training.dataset import load_char_vocab, load_context_vocab, load_split, load_vocab
from comparison.shortcut import build_shortcut_map

THRESHOLDS = np.round(np.arange(0.0, 1.001, 0.01), 2)


def compute_calibration(model_path=config.KERAS_MODEL_V3_PATH, target_precisions=config.CONFIDENCE_TARGET_PRECISIONS):
    """Returns a dict with the full threshold sweep and, for each target
    precision, the recommended threshold + coverage -- computed only over
    the ML-fallback population (is_full rows the exact-match shortcut
    doesn't resolve)."""
    char_vocab = load_char_vocab()
    vocab = load_vocab()
    context_vocab = load_context_vocab()
    model = keras.models.load_model(model_path)

    X_val, y_val, _w_val, rows = load_split(config.VAL_PATH, char_vocab, context_vocab)
    probs = model.predict(X_val, verbose=0)

    shortcut_map = build_shortcut_map()
    is_full = np.array([r["is_full"] for r in rows])
    shortcut_hit = np.array([r["is_full"] and r["roman"] in shortcut_map for r in rows])
    fallback_mask = is_full & ~shortcut_hit

    top1_idx = probs.argmax(axis=1)
    top1_conf = probs.max(axis=1)
    correct = top1_idx == y_val
    counts = np.array([r["count"] for r in rows], dtype=np.float64)

    conf = top1_conf[fallback_mask]
    ok = correct[fallback_mask]
    w = counts[fallback_mask]
    n = len(conf)

    sweep = []
    for t in THRESHOLDS:
        accept = conf >= t
        coverage = float(accept.mean()) if n else 0.0
        precision = float(ok[accept].mean()) if accept.any() else None
        w_coverage = float(w[accept].sum() / w.sum()) if n and w.sum() > 0 else 0.0
        w_precision = float(np.average(ok[accept], weights=w[accept])) if accept.any() else None
        sweep.append({
            "threshold": float(t),
            "coverage": coverage,
            "precision": precision,
            "weighted_coverage": w_coverage,
            "weighted_precision": w_precision,
        })

    recommendations = {}
    for target in target_precisions:
        best = None
        for entry in sweep:
            if entry["weighted_precision"] is not None and entry["weighted_precision"] >= target:
                best = entry
                break
        recommendations[target] = best

    return {
        "fallback_population_size": int(n),
        "sweep": sweep,
        "recommendations": recommendations,
        "vocab": vocab,
        "rows": rows,
        "fallback_mask": fallback_mask,
        "top1_idx": top1_idx,
        "top1_conf": top1_conf,
        "correct": correct,
    }


def main():
    result = compute_calibration()
    n = result["fallback_population_size"]
    print(f"ML-fallback population (is_full, not shortcut-covered): {n}")

    print(f"\n{'threshold':>9s}  {'coverage':>8s}  {'precision':>9s}  {'w-coverage':>10s}  {'w-precision':>11s}")
    for entry in result["sweep"][::10]:  # print every 10th row (0.00, 0.10, ..., 1.00)
        prec = f"{entry['precision']:.4f}" if entry["precision"] is not None else "  n/a "
        wprec = f"{entry['weighted_precision']:.4f}" if entry["weighted_precision"] is not None else "  n/a "
        print(
            f"{entry['threshold']:9.2f}  {entry['coverage']:8.4f}  {prec:>9s}  "
            f"{entry['weighted_coverage']:10.4f}  {wprec:>11s}"
        )

    print("\nrecommended thresholds (lowest threshold clearing each frequency-weighted precision bar):")
    for target, entry in result["recommendations"].items():
        if entry is None:
            print(f"  target fw-precision >= {target:.2f}: not achievable at any threshold in [0, 1]")
        else:
            print(
                f"  target fw-precision >= {target:.2f}: threshold={entry['threshold']:.2f}  "
                f"coverage={entry['coverage']:.4f}  fw-coverage={entry['weighted_coverage']:.4f}"
            )

    best_entry = next((e for e in result["recommendations"].values() if e is not None), None)
    if best_entry is not None:
        threshold = best_entry["threshold"]
        vocab, rows = result["vocab"], result["rows"]
        fallback_mask, top1_idx = result["fallback_mask"], result["top1_idx"]
        top1_conf, correct = result["top1_conf"], result["correct"]
        wrong_high_conf = np.where(fallback_mask & (top1_conf >= threshold) & ~correct)[0]
        print(f"\nhigh-confidence misses at threshold={threshold:.2f} (dangerous for auto-commit), sample:")
        rng = np.random.default_rng(0)
        sample = rng.choice(wrong_high_conf, size=min(20, len(wrong_high_conf)), replace=False)
        for i in sample:
            row = rows[i]
            predicted_word = vocab[top1_idx[i]]
            print(
                f"  input={row['roman']!r:15s} expected={row['word']:8s} "
                f"predicted={predicted_word:8s} conf={top1_conf[i]:.4f}"
            )

    config.MODEL_DIR.mkdir(parents=True, exist_ok=True)
    with open(config.CONFIDENCE_CALIBRATION_PATH, "w", encoding="utf-8") as f:
        json.dump({
            "fallback_population_size": result["fallback_population_size"],
            "sweep": result["sweep"],
            "recommendations": {str(k): v for k, v in result["recommendations"].items()},
        }, f, ensure_ascii=False, indent=2)
    print(f"\nsaved {config.CONFIDENCE_CALIBRATION_PATH}")


if __name__ == "__main__":
    main()
