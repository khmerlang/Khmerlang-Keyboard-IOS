"""v5 experiment: like v3 (frequency-oversampled training), but shrinks the
vocabulary itself to higher-frequency words (count >= config.MIN_WORD_COUNT_V5,
vs. the shipped MIN_WORD_COUNT=5) instead of keeping the full vocab and just
reweighting it -- fewer classes to discriminate between should be easier to
learn per class, at the cost of the lowest-frequency words becoming fully
unreachable. Same architecture and oversampling recipe as v3, so this
isolates "shrink the vocabulary" as the one changed variable. Own vocab/
context_vocab/val files (see data/export_dataset.py), so v5's numbers aren't
directly comparable to v2/v3/v4's -- see comparison/compare_vocab.py for the
apples-to-apples comparison against v3 restricted to the same surviving
high-frequency words.

Usage: python -m training.train_v5   (run from ml/roman2khmer/, after
       data.export_dataset has produced the v5 vocab/dataset files)
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config
from training.train import train


def main():
    train(
        config.TRAIN_V5_OVERSAMPLED_PATH, config.KERAS_MODEL_V5_PATH, config.HISTORY_V5_PATH,
        use_sample_weight=False,
        val_path=config.VAL_V5_PATH,
        vocab_path=config.VOCAB_V5_PATH,
        context_vocab_path=config.CONTEXT_VOCAB_V5_PATH,
    )


if __name__ == "__main__":
    main()
