"""Train the roman2khmer classifier.

Usage: python -m training.train      (run from ml/roman2khmer/)
       python -m training.train_v3   (oversampled-frequency variant, see train_v3.py)
"""

import csv
import sys
from pathlib import Path

from tensorflow import keras

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config
from training.dataset import load_char_vocab, load_context_vocab, load_split, load_vocab
from training.model import build_model


def train(train_path, keras_path, history_path, use_sample_weight=True):
    char_vocab = load_char_vocab()
    vocab = load_vocab()
    context_vocab = load_context_vocab()

    X_train, y_train, w_train, _ = load_split(train_path, char_vocab, context_vocab)
    X_val, y_val, w_val, _ = load_split(config.VAL_PATH, char_vocab, context_vocab)
    if not use_sample_weight:
        w_train = None  # oversampling already encodes frequency preference via row duplication

    model = build_model(vocab_size=len(vocab), context_vocab_size=len(context_vocab))
    model.summary()

    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=config.LEARNING_RATE),
        loss="sparse_categorical_crossentropy",
        weighted_metrics=[
            keras.metrics.SparseCategoricalAccuracy(name="top1"),
            keras.metrics.SparseTopKCategoricalAccuracy(k=3, name="top3"),
            keras.metrics.SparseTopKCategoricalAccuracy(k=5, name="top5"),
        ],
    )

    callbacks = [
        keras.callbacks.EarlyStopping(
            monitor="val_top3",
            mode="max",
            patience=config.EARLY_STOPPING_PATIENCE,
            restore_best_weights=True,
        ),
    ]

    history = model.fit(
        X_train,
        y_train,
        sample_weight=w_train,
        validation_data=(X_val, y_val, w_val),
        batch_size=config.BATCH_SIZE,
        epochs=config.MAX_EPOCHS,
        callbacks=callbacks,
        verbose=2,
    )

    config.MODEL_DIR.mkdir(parents=True, exist_ok=True)
    model.save(keras_path)

    with open(history_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        keys = list(history.history.keys())
        writer.writerow(["epoch"] + keys)
        for epoch, row in enumerate(zip(*history.history.values())):
            writer.writerow([epoch] + list(row))

    print(f"saved model to {keras_path}")
    print(f"saved history to {history_path}")


def main():
    train(config.TRAIN_PATH, config.KERAS_MODEL_PATH, config.HISTORY_PATH, use_sample_weight=True)


if __name__ == "__main__":
    main()
