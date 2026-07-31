"""Produce the shippable roman2khmer bundle in dist/ (tracked in git, unlike
artifacts/) so it can be merged into the iOS project on another machine
without re-running training or conversion.

Ships the v3 (frequency-oversampled) model, since comparison/compare_all.py
showed it beats v2 across the board, plus the exact-match shortcut map for
every romanization that's unambiguous across the full sqlite unigram table
(see comparison/shortcut.py) -- the two combined gave the best numbers in
every slice of that comparison. Also ships a small confidence.json summary
(evaluation/calibrate_confidence.py) recommending an ML-fallback confidence
threshold for words the shortcut doesn't resolve -- consumed by
Roman2KhmerModel.swift's isSafeAutoCommit to gate silent auto-commit.

Usage: python -m conversion.export_dist   (run from ml/roman2khmer/)
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config
from conversion.convert_to_mobile import convert
from comparison.shortcut import build_shortcut_map
from evaluation.calibrate_confidence import compute_calibration
from training.dataset import load_vocab

DIST_DIR = config.ROOT / "dist"


def main():
    DIST_DIR.mkdir(parents=True, exist_ok=True)

    convert(
        config.KERAS_MODEL_V3_PATH,
        DIST_DIR / "Roman2Khmer.tflite",
        DIST_DIR / "Roman2Khmer.mlpackage",
        DIST_DIR,
    )

    vocab = load_vocab()
    shortcut_map = build_shortcut_map()
    reachable_in_vocab = set(shortcut_map.values()) & set(vocab)
    with open(DIST_DIR / "shortcut.json", "w", encoding="utf-8") as f:
        json.dump(shortcut_map, f, ensure_ascii=False, indent=2)
    print(f"saved {DIST_DIR / 'shortcut.json'} ({len(shortcut_map)} exact romanizations)")
    print(f"  covering {len(reachable_in_vocab)}/{len(vocab)} model-vocab words")

    calibration = compute_calibration()
    confidence_summary = {
        str(target): (
            None if entry is None else {
                "threshold": entry["threshold"],
                "coverage": entry["coverage"],
                "weighted_coverage": entry["weighted_coverage"],
            }
        )
        for target, entry in calibration["recommendations"].items()
    }
    with open(DIST_DIR / "confidence.json", "w", encoding="utf-8") as f:
        json.dump({
            "description": (
                "Recommended ML top-1 confidence thresholds for words NOT resolved by "
                "shortcut.json, measured on held-out val.jsonl (v3 model, is_full rows "
                "only). Consumed by Roman2KhmerModel.swift's isSafeAutoCommit to gate "
                "'Space -> Khmer': the '0.99' entry's threshold is the minimum top-1 "
                "softmax probability the model must clear before its own guess (as "
                "opposed to a shortcut/custom-mapping hit) is trusted enough to silently "
                "commit. 'threshold' is the softmax top-1 probability cutoff; "
                "'weighted_coverage' is the frequency-weighted fraction of the ML-fallback "
                "population that clears it."
            ),
            "fallback_population_size": calibration["fallback_population_size"],
            "recommendations": confidence_summary,
        }, f, ensure_ascii=False, indent=2)
    print(f"saved {DIST_DIR / 'confidence.json'}")


if __name__ == "__main__":
    main()
