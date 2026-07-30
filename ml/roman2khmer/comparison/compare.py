"""Evaluate the new model on the exact same val.jsonl sample that
legacy_baseline.py used, for a true apples-to-apples top-1/3/5 comparison.

Usage: python -m comparison.legacy_baseline   (first, to pick+save the sample)
       python -m comparison.compare           (run from ml/roman2khmer/)
"""

import sys
from pathlib import Path

import numpy as np
from tensorflow import keras

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config
from training.dataset import load_char_vocab, load_context_vocab, load_rows, load_split, load_vocab


def topk_hit(probs, labels, k):
    topk = np.argpartition(-probs, kth=k - 1, axis=1)[:, :k]
    return np.array([label in row for label, row in zip(labels, topk)])


def main():
    sample_idx_path = config.MODEL_DIR / "legacy_baseline_sample_idx.npy"
    sample_idx = np.load(sample_idx_path)

    char_vocab = load_char_vocab()
    context_vocab = load_context_vocab()
    model = keras.models.load_model(config.KERAS_MODEL_PATH, safe_mode=False)

    X_val, y_val, _w_val, rows = load_split(config.VAL_PATH, char_vocab, context_vocab)
    X_sample = {k: v[sample_idx] for k, v in X_val.items()}
    y_sample = y_val[sample_idx]

    probs = model.predict(X_sample, verbose=0)
    hit1 = topk_hit(probs, y_sample, 1)
    hit3 = topk_hit(probs, y_sample, 3)
    hit5 = topk_hit(probs, y_sample, 5)

    n = len(sample_idx)
    print(f"new model, n={n}")
    print(f"top-1: {hit1.mean():.4f}  top-3: {hit3.mean():.4f}  top-5: {hit5.mean():.4f}")


if __name__ == "__main__":
    main()
