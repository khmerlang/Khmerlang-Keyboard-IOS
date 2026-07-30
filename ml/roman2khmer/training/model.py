"""roman2khmer model architecture.

Char-level BiLSTM encoder -> softmax over the closed vocabulary of Khmer
words with known romanizations. Same forward+backward-LSTM-concat idea as
Khmerlang/MLWordSegmenter.swift's WordSegModel, adapted from per-timestep
tagging to whole-sequence classification. Unlike that model (which
hand-rolls forward/backward LSTMs + a Lambda reverse layer to match
weights ported from an external .tflite file), this model is trained from
scratch, so it uses the standard `Bidirectional` wrapper instead -- no
weight-porting constraint, and it avoids a custom Lambda layer that would
otherwise complicate Keras safe-mode deserialization and mobile conversion.

No mask_zero on the Embedding: masking is a known TFLite conversion risk
(pushes the converter off the fast fused-LSTM kernel path), and unlike
ordinary text classification, the padding boundary is itself signal here
-- it tells the model how much of the word has been typed so far.

A second input, `prev`, is the previous word's context vocab id (see
data/export_dataset.py's CONTEXT_UNK/CONTEXT_S tokens): an embedding of it
is concatenated onto the pooled char representation before the final
softmax, so a short/ambiguous prefix like "ko" can be disambiguated by
what word preceded it -- the same signal the existing BK-tree/n-gram
corrector uses, just learned instead of hand-coded.
"""

import sys
from pathlib import Path

from tensorflow import keras
from tensorflow.keras import layers

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config


def build_model(
    char_vocab_size=config.CHAR_VOCAB_SIZE,
    vocab_size=None,
    context_vocab_size=None,
    max_len=config.MAX_ROMAN_LEN,
    embed_dim=config.EMBED_DIM,
    lstm1_units=config.LSTM1_UNITS,
    lstm2_units=config.LSTM2_UNITS,
    dense_units=config.DENSE_UNITS,
    dropout_rate=config.DROPOUT_RATE,
    prev_embed_dim=config.PREV_EMBED_DIM,
    unroll=False,
):
    """`unroll=True` produces a graph-identical model (same layer names/shapes,
    so trained weights transfer via set_weights) but fully unrolls the LSTMs
    over the fixed max_len instead of using tf.while_loop/TensorList ops.
    Needed only for TFLite conversion, which can't lower go_backwards=True
    LSTMs through TensorListReserve when the batch dimension is dynamic;
    training uses unroll=False since it's faster and the limitation doesn't
    apply there.
    """
    if vocab_size is None:
        raise ValueError("vocab_size is required")
    if context_vocab_size is None:
        raise ValueError("context_vocab_size is required")

    chars_inp = keras.Input(shape=(max_len,), dtype="int32", name="chars")
    x = layers.Embedding(char_vocab_size, embed_dim, name="emb")(chars_inp)

    x = layers.Bidirectional(
        layers.LSTM(lstm1_units, return_sequences=True, unroll=unroll),
        merge_mode="concat", name="bilstm1",
    )(x)
    x = layers.Bidirectional(
        layers.LSTM(lstm2_units, return_sequences=False, unroll=unroll),
        merge_mode="concat", name="bilstm2",
    )(x)

    prev_inp = keras.Input(shape=(), dtype="int32", name="prev")
    prev_x = layers.Embedding(context_vocab_size, prev_embed_dim, name="prev_emb")(prev_inp)

    x = layers.Concatenate(name="cat_context")([x, prev_x])
    x = layers.Dense(dense_units, activation="relu", name="dense1")(x)
    x = layers.Dropout(dropout_rate, name="dropout")(x)
    out = layers.Dense(vocab_size, activation="softmax", name="predictions")(x)

    return keras.Model({"chars": chars_inp, "prev": prev_inp}, out, name="roman2khmer")
