"""v3 experiment: train on the frequency-oversampled dataset (train_v3.jsonl,
see data/export_dataset.py's build_oversampled_train) instead of the plain
per-example log1p(count) loss weighting v2 uses. Same architecture, same
val set, so v2 vs v3 isolates "oversample high-frequency words' training
rows" as the one changed variable.

Usage: python -m training.train_v3   (run from ml/roman2khmer/)
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config
from training.train import train


def main():
    train(config.TRAIN_V3_PATH, config.KERAS_MODEL_V3_PATH, config.HISTORY_V3_PATH, use_sample_weight=False)


if __name__ == "__main__":
    main()
