# roman2khmer

Trains a small on-device model that predicts a Khmer word from romanized
(English-letter) input, as a machine-learned alternative/complement to the
BK-tree fuzzy matcher in `Khmerlang/KhmerlangCorrector.swift`.

**Scope**: this pipeline produces a trained, validated model bundle
(`.tflite` + `.mlpackage` + vocab files). Wiring it into the iOS/Android
apps is a separate, later phase.

The model is a char-level BiLSTM classifier over a closed vocabulary of
~6,800 Khmer words (those with `count >= 5` romanizations in
`Khmerlang/khmerlang.sqlite`), trained on both full romanized spellings and
truncated prefixes, so it can predict the completed word while the user is
still typing.

## Setup

```bash
cd ml/roman2khmer
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

If `pip install` fails to resolve on your Python version (tensorflow and
coremltools both lag behind new CPython releases), use a Python 3.11 or
3.12 interpreter instead and pin older versions:

```
tensorflow>=2.16,<2.21
coremltools>=8.0,<9.0
```

(This is close to the toolchain `tools/convert_wordseg_to_coreml.py` was
run under.)

## Run the pipeline

All commands run from `ml/roman2khmer/`:

```bash
python -m data.export_dataset        # sqlite -> artifacts/dataset/*.jsonl, vocab.json, char_vocab.json
python -m training.train             # -> artifacts/model/roman2khmer.keras
python -m evaluation.evaluate        # top-1/3/5 accuracy report
python -m conversion.convert_to_mobile   # -> artifacts/model/Roman2Khmer.{tflite,mlpackage}
```

`data/export_dataset.py` has no ML dependencies (stdlib only) and can be
re-run any time the source `khmerlang.sqlite` changes.

## Artifacts

Everything under `artifacts/` is generated and gitignored — it's fully
reproducible from `Khmerlang/khmerlang.sqlite` plus these scripts. The
deliverable bundle for a future mobile integration is the five files in
`artifacts/model/`: `Roman2Khmer.tflite`, `Roman2Khmer.mlpackage`,
`vocab.json`, `char_vocab.json`, `context_vocab.json`.

## Model inputs

The model takes two inputs: `chars` (the romanized text typed so far,
encoded via `char_vocab.json`) and `prev` (the previous word, encoded via
`context_vocab.json` -- use index 0 (`<unk>`) if there's no reliable
previous-word context, e.g. the first word of a message, and index 1
(`<s>`) for an explicit sentence start).
