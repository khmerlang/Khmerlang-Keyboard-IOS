"""Produce the shippable roman2khmer bundle in dist/ (tracked in git, unlike
artifacts/) so it can be merged into the iOS project on another machine
without re-running training or conversion.

Ships the v3 (frequency-oversampled) model, since comparison/compare_all.py
showed it beats v2 across the board, plus the exact-match shortcut map for
the SHORTCUT_TOP_N highest-frequency words (see comparison/shortcut.py) --
the two combined gave the best numbers in every slice of that comparison.

Usage: python -m conversion.export_dist   (run from ml/roman2khmer/)
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config
from conversion.convert_to_mobile import convert
from comparison.shortcut import build_shortcut_map
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
    shortcut_map = build_shortcut_map(vocab, config.SHORTCUT_TOP_N)
    with open(DIST_DIR / "shortcut.json", "w", encoding="utf-8") as f:
        json.dump(shortcut_map, f, ensure_ascii=False, indent=2)
    print(f"saved {DIST_DIR / 'shortcut.json'} ({len(shortcut_map)} exact romanizations)")


if __name__ == "__main__":
    main()
