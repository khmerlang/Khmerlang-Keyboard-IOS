"""Shared encoding + tf.data.Dataset builders for train/eval/convert."""

import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config


def load_char_vocab():
    with open(config.CHAR_VOCAB_PATH, encoding="utf-8") as f:
        return json.load(f)


def load_vocab():
    with open(config.VOCAB_PATH, encoding="utf-8") as f:
        return json.load(f)


def load_context_vocab():
    with open(config.CONTEXT_VOCAB_PATH, encoding="utf-8") as f:
        return json.load(f)


def load_rows(path):
    rows = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def encode(texts, char_vocab):
    """Encodes a list of romanized strings into a (N, max_len) int32 array."""
    chars = char_vocab["chars"]
    max_len = char_vocab["max_len"]
    pad = char_vocab["pad_index"]
    unk = char_vocab["unk_index"]

    arr = np.full((len(texts), max_len), pad, dtype=np.int32)
    for i, text in enumerate(texts):
        for j, c in enumerate(text[:max_len]):
            arr[i, j] = chars.get(c, unk)
    return arr


def encode_context(tokens, context_vocab):
    """Encodes a list of previous-word tokens into a (N,) int32 array."""
    index = {token: i for i, token in enumerate(context_vocab)}
    unk_index = index[config.CONTEXT_UNK]
    return np.array([index.get(t, unk_index) for t in tokens], dtype=np.int32)


def load_split(path, char_vocab, context_vocab):
    """Returns (inputs, y, sample_weight, rows) for one jsonl split, where
    inputs = {"chars": (N, max_len) int32, "prev": (N,) int32}."""
    rows = load_rows(path)
    inputs = {
        "chars": encode([r["roman"] for r in rows], char_vocab),
        "prev": encode_context([r["prev"] for r in rows], context_vocab),
    }
    y = np.array([r["label"] for r in rows], dtype=np.int32)

    log_counts = np.log1p(np.array([r["count"] for r in rows], dtype=np.float64))
    sample_weight = (log_counts / log_counts.mean()).astype(np.float32)

    return inputs, y, sample_weight, rows
