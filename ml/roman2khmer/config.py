"""Shared constants for the roman2khmer pipeline.

Every stage (data export, training, evaluation, conversion) imports from
here so they can't silently drift out of sync with each other.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent
SQLITE_PATH = ROOT.parent.parent / "Khmerlang" / "khmerlang.sqlite"

ARTIFACTS_DIR = ROOT / "artifacts"
DATASET_DIR = ARTIFACTS_DIR / "dataset"
MODEL_DIR = ARTIFACTS_DIR / "model"

TRAIN_PATH = DATASET_DIR / "train.jsonl"
VAL_PATH = DATASET_DIR / "val.jsonl"
VOCAB_PATH = ARTIFACTS_DIR / "vocab.json"
CHAR_VOCAB_PATH = ARTIFACTS_DIR / "char_vocab.json"
CONTEXT_VOCAB_PATH = ARTIFACTS_DIR / "context_vocab.json"

KERAS_MODEL_PATH = MODEL_DIR / "roman2khmer.keras"
HISTORY_PATH = MODEL_DIR / "training_history.csv"
TFLITE_PATH = MODEL_DIR / "Roman2Khmer.tflite"
COREML_PATH = MODEL_DIR / "Roman2Khmer.mlpackage"

# v3 experiment: frequency-oversampled training (see comparison/ for the
# side-by-side against v2 and the exact-match shortcut layer).
KERAS_MODEL_V2_PATH = MODEL_DIR / "roman2khmer_v2.keras"
KERAS_MODEL_V3_PATH = MODEL_DIR / "roman2khmer_v3.keras"
HISTORY_V3_PATH = MODEL_DIR / "training_history_v3.csv"
TRAIN_V3_PATH = DATASET_DIR / "train_v3.jsonl"
OVERSAMPLE_MAX_FACTOR = 6   # train-example duplication cap for high-count words
SHORTCUT_TOP_N = 500        # exact-match shortcut covers this many highest-count words

# Data export
MIN_WORD_COUNT = 5          # vocab filter: keep Khmer unigrams with count >= this
MIN_PREFIX_LEN = 2          # never generate a prefix shorter than this
MAX_PREFIXES_PER_VARIANT = 6   # evenly-spaced prefix lengths sampled per romanized variant
VAL_SEED = 1234

# Typo augmentation: one keyboard-aware-noisy copy generated per base example
# (skipped for very short strings), reusing the QWERTY-neighbor table from
# Khmerlang/Levenshtein.swift so noise matches plausible fat-finger mistakes.
MIN_LEN_FOR_TYPO = 3

# Previous-word context: <unk> = no known/recognized previous word (also what
# rare/out-of-vocab predecessors fold into), <s> = sentence start. Real
# distributions come from khmerlang.sqlite's Khmer bigram rows (gram=2,
# lang=0), which already contain <s>/<unk>/<oth>/<num> sentinel predecessors.
CONTEXT_UNK = "<unk>"
CONTEXT_S = "<s>"

# Model / encoding
MAX_ROMAN_LEN = 20          # p99 romanized-variant length is 17; longer strings are truncated
PAD_INDEX = 0
UNK_INDEX = 1
CHARS = "abcdefghijklmnopqrstuvwxyz"
CHAR_VOCAB_SIZE = len(CHARS) + 2   # + PAD + UNK

# Model architecture
EMBED_DIM = 32
LSTM1_UNITS = 64
LSTM2_UNITS = 32
DENSE_UNITS = 128
DROPOUT_RATE = 0.2
PREV_EMBED_DIM = 16

# Training
BATCH_SIZE = 128
LEARNING_RATE = 1e-3
MAX_EPOCHS = 100
EARLY_STOPPING_PATIENCE = 5
