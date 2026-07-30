"""v4 experiment: like v3 (frequency-oversampled), but applies an extra
oversampling bonus to words that have no unambiguous romanization -- i.e.
words the exact-match shortcut (comparison/shortcut.py) can never resolve,
so they depend entirely on the model. See data/export_dataset.py's
build_oversampled_train_v4 / oversample_factor_v4 for how train_v4.jsonl is
built. Same architecture, same val set, so v3 vs v4 isolates "give the
harder, shortcut-unreachable words extra training exposure" as the one
changed variable.

Usage: python -m training.train_v4   (run from ml/roman2khmer/, after
       data.export_dataset has produced train_v4.jsonl)
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config
from training.train import train


def main():
    train(config.TRAIN_V4_PATH, config.KERAS_MODEL_V4_PATH, config.HISTORY_V4_PATH, use_sample_weight=False)


if __name__ == "__main__":
    main()
