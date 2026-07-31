"""v3 (full 6,782-word vocab) vs. v5 (count >= MIN_WORD_COUNT_V5 vocab) --
isolates "does shrinking the vocabulary itself (fewer classes) beat keeping
every word and reweighting it" as the one question.

The comparison population is exact, not approximate: val_v5.jsonl's rows
are, by construction (see data/export_dataset.py's export_vocab_and_splits
-- the count>=20 word list is a stable prefix of the count>=5 word list in
the same frequency-sorted order, so both runs draw identical rng sequences
for the shared words), the same held-out prefixes/variants as val.jsonl's
rows restricted to the same high-frequency words. So "v3 restricted to
words also in v5's vocab" and "v5 on its own val set" are evaluated on the
literal same set of examples.

Usage: python -m comparison.compare_vocab   (run from ml/roman2khmer/, after
       training.train_v3 and training.train_v5 have both produced models)
"""

import sys
from pathlib import Path

import numpy as np
from tensorflow import keras

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config
from evaluation.evaluate import topk_hit, weighted_accuracy
from training.dataset import load_char_vocab, load_context_vocab, load_split, load_vocab


def _report(label, hit1, hit3, hit5, counts):
    n = len(counts)
    print(
        f"{label:38s} n={n:5d}  "
        f"top-1={hit1.mean():.4f} (fw={weighted_accuracy(hit1, counts):.4f})  "
        f"top-3={hit3.mean():.4f} (fw={weighted_accuracy(hit3, counts):.4f})  "
        f"top-5={hit5.mean():.4f} (fw={weighted_accuracy(hit5, counts):.4f})"
    )


def main():
    char_vocab = load_char_vocab()

    v3_vocab = load_vocab(config.VOCAB_PATH)
    v5_vocab = load_vocab(config.VOCAB_V5_PATH)
    v5_words = set(v5_vocab)

    # v3: full vocab, restricted to rows whose target word also survives the
    # v5 (count >= MIN_WORD_COUNT_V5) cutoff.
    v3_context_vocab = load_context_vocab(config.CONTEXT_VOCAB_PATH)
    v3_model = keras.models.load_model(config.KERAS_MODEL_V3_PATH)
    X_val, y_val, _w, rows = load_split(config.VAL_PATH, char_vocab, v3_context_vocab)
    mask = np.array([r["word"] in v5_words for r in rows])

    probs = v3_model.predict(X_val, verbose=0)
    hit1 = topk_hit(probs, y_val, 1)
    hit3 = topk_hit(probs, y_val, 3)
    hit5 = topk_hit(probs, y_val, 5)
    counts = np.array([r["count"] for r in rows], dtype=np.float64)
    _report(f"v3 (vocab={len(v3_vocab)}), high-freq subset", hit1[mask], hit3[mask], hit5[mask], counts[mask])

    # v5: smaller vocab, its own val set -- the same held-out rows as the
    # subset above (see module docstring).
    v5_context_vocab = load_context_vocab(config.CONTEXT_VOCAB_V5_PATH)
    v5_model = keras.models.load_model(config.KERAS_MODEL_V5_PATH)
    X_val5, y_val5, _w5, rows5 = load_split(config.VAL_V5_PATH, char_vocab, v5_context_vocab)

    probs5 = v5_model.predict(X_val5, verbose=0)
    hit1_5 = topk_hit(probs5, y_val5, 1)
    hit3_5 = topk_hit(probs5, y_val5, 3)
    hit5_5 = topk_hit(probs5, y_val5, 5)
    counts5 = np.array([r["count"] for r in rows5], dtype=np.float64)
    _report(f"v5 (vocab={len(v5_vocab)})", hit1_5, hit3_5, hit5_5, counts5)

    if int(mask.sum()) != len(rows5):
        print(
            f"\nNOTE: population sizes differ (v3 subset n={int(mask.sum())}, v5 n={len(rows5)}) "
            "-- the exact row-alignment this comparison assumes doesn't hold here "
            "(e.g. khmerlang.sqlite changed between exports); treat the numbers above "
            "as approximate, not exact, apples-to-apples."
        )


if __name__ == "__main__":
    main()
