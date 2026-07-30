# roman2khmer shippable bundle

Committed to git (unlike `../artifacts/`) so it can be merged into the iOS
(and Android) projects on another machine without re-running training or
conversion. Regenerate with `python -m conversion.export_dist` from
`ml/roman2khmer/` if the model or vocab ever changes.

This is the **v3** model (frequency-oversampled training) plus the
exact-match shortcut for the 500 highest-frequency words -- see the
`comparison/` scripts for how that combination was chosen over plain (v2)
training and over the shortcut alone.

## Files

- `Roman2Khmer.tflite` / `Roman2Khmer.mlpackage` -- the model, two inputs:
  - `chars`: int32[20], the romanized text typed so far, encoded via
    `char_vocab.json` (`pad_index`/`unk_index`/`chars` map, 0-padded on the right)
  - `prev`: int32 scalar, the previous word, encoded via `context_vocab.json`
    (index 0 = `<unk>` -- no reliable previous-word context, e.g. first word
    of a message; index 1 = `<s>` -- explicit sentence start)
  - output: float32[6782] softmax over `vocab.json` (index -> Khmer word)
- `vocab.json`, `char_vocab.json`, `context_vocab.json` -- the encode/decode
  tables the two inputs/output above are defined against.
- `shortcut.json` -- `{romanization: khmer_word}` for the 500 highest-
  frequency words' exact known spellings. Apply this **before** the model,
  and **only** once the user has finished typing a word (not mid-prefix --
  a partial prefix can coincide character-for-character with one of these
  words' full spelling and wrongly hijack the prediction otherwise, see
  `comparison/shortcut.py`'s docstring for the measured collision rate):
  if the typed text is an exact key in this map, use its value as the
  top-1 suggestion and let the model fill in the rest of the ranked list.

## Known limitations (not yet addressed by this bundle)

- Offline top-1/top-3/top-5 accuracy on held-out data is roughly 31%/45%/50%
  overall (see `comparison/compare_all.py` output) -- useful as a ranked
  suggestion-bar candidate, not a silent auto-correct/auto-commit.
- CoreML inference was exported but not runtime-validated (coremltools can
  only run predictions on macOS); validate on a Mac/iOS device before
  shipping.
- Not yet wired into `KhmerlangCorrector`/`SuggestionProvider` (iOS) or the
  Android equivalent -- that integration is a separate follow-up.
