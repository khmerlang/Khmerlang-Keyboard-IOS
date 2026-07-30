"""Export roman2khmer training data from Khmerlang/khmerlang.sqlite.

Reads Khmer unigrams (gram=1, lang=0) with a non-empty `other` column
(comma-separated romanizations), filters to a manageable vocabulary,
generates prefix- and typo-augmented training examples paired with a
previous-word context token (from the Khmer bigram rows, gram=2 lang=0),
and writes:

  artifacts/vocab.json           - array of Khmer words, index == class label
  artifacts/char_vocab.json      - roman char -> index map + encoding config
  artifacts/context_vocab.json   - [<unk>, <s>, *vocab] -- previous-word token -> index
  artifacts/dataset/train.jsonl
  artifacts/dataset/val.jsonl

Usage: python -m data.export_dataset   (run from ml/roman2khmer/)
"""

import json
import math
import random
import sqlite3
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config
from data.typo import apply_typo
from comparison.shortcut import build_shortcut_map

ROMAN_RE = config.ROMAN_RE


def load_words(conn):
    """Returns [(word, count, [variants]), ...] for the filtered vocabulary."""
    rows = conn.execute(
        "SELECT keyword, count, other FROM ngram "
        "WHERE gram = 1 AND lang = 0 AND other != '' AND count >= ?",
        (config.MIN_WORD_COUNT,),
    ).fetchall()

    words = []
    for keyword, count, other in rows:
        variants = [v.lower() for v in other.split(",") if v]
        variants = sorted(set(v for v in variants if ROMAN_RE.match(v)))
        if variants:
            words.append((keyword, count, variants))
    return words


def load_bigram_context(conn, vocab_set):
    """Returns {word: {prev_token: count}} for words in vocab_set.

    prev_token is either the previous word itself (if it's also in
    vocab_set), the sentence-start sentinel <s>, or <unk> -- which is what
    everything else (rare/out-of-vocab words, and the corpus's own <oth>/
    <num> sentinels) folds into.
    """
    rows = conn.execute("SELECT keyword, count FROM ngram WHERE gram = 2 AND lang = 0").fetchall()

    context = defaultdict(lambda: defaultdict(int))
    for keyword, count in rows:
        parts = keyword.split(" ", 1)
        if len(parts) != 2:
            continue
        prev, word = parts
        if word not in vocab_set:
            continue
        token = prev if (prev in vocab_set or prev == config.CONTEXT_S) else config.CONTEXT_UNK
        context[word][token] += count
    return context


def prefix_lengths(length, max_prefixes=config.MAX_PREFIXES_PER_VARIANT, min_len=config.MIN_PREFIX_LEN):
    """Evenly-spaced prefix lengths in [min_len, length-1], capped at max_prefixes."""
    available = length - min_len
    if available <= 0:
        return []
    n = min(available, max_prefixes)
    if n == 1:
        return [min_len]
    step = (length - 1 - min_len) / (n - 1)
    return sorted({round(min_len + i * step) for i in range(n)})


def build_examples(variant):
    """Returns [(text, is_full), ...] for one romanized variant."""
    examples = [(variant, True)]
    examples += [(variant[:n], False) for n in prefix_lengths(len(variant))]
    return examples


def split_examples(rng, variants):
    """Splits one word's (text, is_full) examples into (train, val).

    Every class must survive in train (a class absent from train can never
    be predicted by a closed-vocab softmax). Words with >=2 variants hold
    out one whole variant for val; single-variant words keep their full
    spelling in train always and hold out an interior prefix instead.
    """
    train, val = [], []

    if len(variants) >= 2:
        held_out = rng.choice(variants)
        for variant in variants:
            rows = build_examples(variant)
            (val if variant == held_out else train).extend(rows)
    else:
        rows = build_examples(variants[0])
        prefix_rows = [r for r in rows if not r[1]]
        if prefix_rows:
            held_out = rng.choice(prefix_rows)
            train.extend(r for r in rows if r != held_out)
            val.append(held_out)
        else:
            train.extend(rows)

    return train, val


def augment(text, is_full, word, label, count, context_pool, rng):
    """Expands one (text, is_full) example into 1-2 rows: the example itself
    plus (usually) a typo-noised copy, each independently paired with a
    previous-word context token sampled from the word's real bigram
    distribution (so common contexts appear more often, exactly like the
    training data for the rest of the model)."""
    variants = [(text, False)]
    noisy = apply_typo(text, rng)
    if noisy != text:
        variants.append((noisy, True))

    pool = context_pool if context_pool else {config.CONTEXT_UNK: 1}
    tokens, weights = list(pool.keys()), list(pool.values())

    rows = []
    for variant_text, is_typo in variants:
        prev = rng.choices(tokens, weights=weights, k=1)[0]
        rows.append({
            "roman": variant_text,
            "prev": prev,
            "word": word,
            "label": label,
            "is_full": is_full,
            "is_typo": is_typo,
            "count": count,
        })
    return rows


def oversample_factor(count, cap=config.OVERSAMPLE_MAX_FACTOR):
    """How many independently-augmented copies of each base example a word's
    training rows get, scaled by log2(count/MIN_WORD_COUNT) and capped. Each
    copy re-samples its own typo noise and context draw (see augment()), so
    duplication adds real variety, not just repeated identical rows -- more
    exposure to a common word's input space, not more weight on one example
    of it."""
    return min(1 + int(math.log2(max(count, config.MIN_WORD_COUNT) / config.MIN_WORD_COUNT)), cap)


def build_dataset(words, context_by_word):
    """Returns (train_rows, val_rows, train_base_by_word) -- the last is
    reused by build_oversampled_train() below so the expensive word/variant
    split doesn't need to be recomputed (and, more importantly, so its rng
    draws stay untouched, keeping train_rows/val_rows byte-identical to a
    plain, non-oversampled export)."""
    split_rng = random.Random(config.VAL_SEED)
    augment_rng = random.Random(config.VAL_SEED + 1)
    train_rows, val_rows = [], []
    train_base_by_word = []

    for label, (word, count, variants) in enumerate(words):
        train_base, val_base = split_examples(split_rng, variants)
        context_pool = context_by_word.get(word)
        train_base_by_word.append((word, label, count, context_pool, train_base))
        for base, out in [(train_base, train_rows), (val_base, val_rows)]:
            for text, is_full in base:
                out.extend(augment(text, is_full, word, label, count, context_pool, augment_rng))

    return train_rows, val_rows, train_base_by_word


def build_oversampled_train(train_base_by_word):
    """Frequency-oversampled train set: each word's base examples get
    oversample_factor(count) independently-augmented copies. Uses its own
    rng stream, entirely separate from build_dataset()'s, so it has no
    effect on train.jsonl/val.jsonl."""
    rng = random.Random(config.VAL_SEED + 3)
    rows = []
    for word, label, count, context_pool, train_base in train_base_by_word:
        factor = oversample_factor(count)
        for _ in range(factor):
            for text, is_full in train_base:
                rows.extend(augment(text, is_full, word, label, count, context_pool, rng))
    return rows


def fully_ambiguous_words(vocab_set):
    """Words in vocab_set with no unambiguous romanization -- i.e. every one
    of their known spellings is shared with some other Khmer word, so the
    exact-match shortcut (comparison/shortcut.py) can never resolve them and
    they depend entirely on the model. Reused by build_oversampled_train_v4
    to give this specific, harder population extra training exposure."""
    reachable = set(build_shortcut_map().values())
    return {word for word in vocab_set if word not in reachable}


def oversample_factor_v4(count, is_fully_ambiguous, cap=config.OVERSAMPLE_MAX_FACTOR):
    """Like oversample_factor, but fully-ambiguous words (see above) get an
    extra AMBIGUOUS_OVERSAMPLE_BONUS multiplier, capped at
    cap * AMBIGUOUS_OVERSAMPLE_BONUS -- everything else is unchanged from
    v3, so this only reallocates exposure toward the harder subset rather
    than inflating the dataset uniformly."""
    factor = oversample_factor(count, cap=cap)
    if is_fully_ambiguous:
        factor = min(factor * config.AMBIGUOUS_OVERSAMPLE_BONUS, cap * config.AMBIGUOUS_OVERSAMPLE_BONUS)
    return factor


def build_oversampled_train_v4(train_base_by_word, ambiguous_words):
    """v4 train set: like build_oversampled_train, but using
    oversample_factor_v4 so fully-ambiguous words get extra independently-
    augmented copies. Uses its own rng stream, separate from v3's and
    build_dataset()'s."""
    rng = random.Random(config.VAL_SEED + 4)
    rows = []
    for word, label, count, context_pool, train_base in train_base_by_word:
        factor = oversample_factor_v4(count, word in ambiguous_words)
        for _ in range(factor):
            for text, is_full in train_base:
                rows.extend(augment(text, is_full, word, label, count, context_pool, rng))
    return rows


def write_jsonl(path, rows):
    with open(path, "w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")


def main():
    config.DATASET_DIR.mkdir(parents=True, exist_ok=True)
    config.ARTIFACTS_DIR.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(str(config.SQLITE_PATH))
    words = load_words(conn)
    words.sort(key=lambda w: -w[1])  # stable, deterministic label ordering by frequency desc
    vocab_set = {word for word, _count, _variants in words}
    context_by_word = load_bigram_context(conn, vocab_set)
    conn.close()

    vocab = [word for word, _count, _variants in words]
    train_rows, val_rows, train_base_by_word = build_dataset(words, context_by_word)
    train_v3_rows = build_oversampled_train(train_base_by_word)

    ambiguous_words = fully_ambiguous_words(vocab_set)
    train_v4_rows = build_oversampled_train_v4(train_base_by_word, ambiguous_words)

    write_jsonl(config.TRAIN_PATH, train_rows)
    write_jsonl(config.VAL_PATH, val_rows)
    write_jsonl(config.TRAIN_V3_PATH, train_v3_rows)
    write_jsonl(config.TRAIN_V4_PATH, train_v4_rows)

    with open(config.VOCAB_PATH, "w", encoding="utf-8") as f:
        json.dump(vocab, f, ensure_ascii=False, indent=2)

    context_vocab = [config.CONTEXT_UNK, config.CONTEXT_S] + vocab
    with open(config.CONTEXT_VOCAB_PATH, "w", encoding="utf-8") as f:
        json.dump(context_vocab, f, ensure_ascii=False, indent=2)

    char_vocab = {
        "pad_index": config.PAD_INDEX,
        "unk_index": config.UNK_INDEX,
        "chars": {c: i + 2 for i, c in enumerate(config.CHARS)},
        "max_len": config.MAX_ROMAN_LEN,
    }
    with open(config.CHAR_VOCAB_PATH, "w", encoding="utf-8") as f:
        json.dump(char_vocab, f, ensure_ascii=False, indent=2)

    print(f"vocab size: {len(vocab)}")
    print(f"context vocab size: {len(context_vocab)}")
    print(f"words with bigram context: {len(context_by_word)}")
    print(f"train rows: {len(train_rows)}")
    print(f"val rows:   {len(val_rows)}")
    print(f"train_v3 (oversampled) rows: {len(train_v3_rows)}")
    print(f"fully-ambiguous words (no unambiguous romanization): {len(ambiguous_words)}/{len(vocab)}")
    print(f"train_v4 (ambiguous-focused oversampled) rows: {len(train_v4_rows)}")


if __name__ == "__main__":
    main()
