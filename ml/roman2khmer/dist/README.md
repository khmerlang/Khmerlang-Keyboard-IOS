# roman2khmer shippable bundle

Committed to git (unlike `../artifacts/`) so it can be merged into the iOS
(and Android) projects on another machine without re-running training or
conversion. Regenerate with `python -m conversion.export_dist` from
`ml/roman2khmer/` if the model or vocab ever changes.

This is the **v3** model (frequency-oversampled training) plus an
exact-match shortcut covering every romanization that maps unambiguously to
exactly one Khmer word across the full `khmerlang.sqlite` unigram table
(27,751 romanizations as of the last export, covering 5,656/6,782 of the
model's vocab words) -- see the `comparison/` scripts for how that
combination was chosen over plain (v2) training and over a smaller,
frequency-ranked-only shortcut. Romanizations shared by multiple Khmer words
(homographs in romanized spelling) are intentionally left out of the
shortcut and fall through to the model, whose `prev` context input exists
specifically to disambiguate those using the previous word.

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
- `shortcut.json` -- `{romanization: khmer_word}` for every romanization
  that maps unambiguously to exactly one Khmer word (see above). Apply this
  **before** the model, and **only** once the user has finished typing a
  word (not mid-prefix -- a partial prefix can coincide character-for-
  character with one of these words' full spelling and wrongly hijack the
  prediction otherwise, see `comparison/shortcut.py`'s docstring for the
  measured collision rate, ~13.5%, which is why the `is_full` gate matters):
  if the typed text is an exact key in this map, use its value as the
  top-1 suggestion and let the model fill in the rest of the ranked list.
- `confidence.json` -- for words the shortcut does *not* resolve, a menu of
  recommended ML top-1 softmax confidence thresholds (evaluated on held-out
  data, at target frequency-weighted precision bars of 95/97/99%) and the
  coverage each buys. Intended for a future auto-commit gate: only trust
  the model's top-1 above the chosen threshold, otherwise just populate the
  suggestion bar without committing. **Not yet consumed by the iOS/Android
  apps.**

## Known limitations (not yet addressed by this bundle)

- Offline top-1/top-3/top-5 accuracy of the model **alone** (no shortcut)
  on held-out data is roughly 31%/45%/51% overall (see
  `comparison/compare_all.py` output) -- useful as a ranked suggestion-bar
  candidate, not a silent auto-correct/auto-commit.
- The **combined system** (shortcut, then model as fallback, no confidence
  gating) does much better on fully-typed words: shortcut resolves 43.3% of
  full-word inputs outright (100% correct by construction), taking combined
  top-1 from 35.8% (model alone) to 61.4% (uniform) / 53.0%
  (frequency-weighted) on that population. The remaining ~57% that reach
  the model are still the hard, ambiguous-spelling cases --
  `evaluation/calibrate_confidence.py`'s sweep shows they only clear ~99%
  weighted precision at a confidence threshold of 1.00, and even then at
  well under 1% coverage of that fallback population -- i.e. the model
  cannot yet be trusted for silent auto-commit on its own even with
  confidence gating; only the deterministic shortcut layer is currently
  safe to auto-commit from.
- CoreML inference was exported but not runtime-validated (coremltools can
  only run predictions on macOS); validate on a Mac/iOS device before
  shipping.
- Not yet wired into `KhmerlangCorrector`/`SuggestionProvider` (iOS) or the
  Android equivalent -- that integration is a separate follow-up.
