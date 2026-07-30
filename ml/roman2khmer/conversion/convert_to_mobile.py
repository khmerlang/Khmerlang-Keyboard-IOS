"""Convert the trained roman2khmer Keras model to TFLite + CoreML.

Structurally mirrors tools/convert_wordseg_to_coreml.py, but simpler: that
script reconstructs a Keras model from an externally-trained .tflite file's
raw tensors. Here the Keras model already IS the freshly-trained source of
truth, so there's no weight-copying/tensor-index bookkeeping.

Usage: python -m conversion.convert_to_mobile   (run from ml/roman2khmer/)
"""

import shutil
import sys
import time
from pathlib import Path

import coremltools as ct
import numpy as np
import tensorflow as tf
from tensorflow import keras

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import config
from training.dataset import load_char_vocab, load_context_vocab, load_split, load_vocab
from training.model import build_model


def convert_tflite(model, tflite_path):
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_bytes = converter.convert()
    tflite_path.write_bytes(tflite_bytes)
    return tflite_bytes


def convert_coreml(model, coreml_path):
    @tf.function
    def f(chars, prev):
        return model({"chars": chars, "prev": prev})

    cf = f.get_concrete_function(
        chars=tf.TensorSpec((1, config.MAX_ROMAN_LEN), tf.int32, name="chars"),
        prev=tf.TensorSpec((1,), tf.int32, name="prev"),
    )
    mlmodel = ct.convert(
        [cf],
        source="tensorflow",
        inputs=[
            ct.TensorType(name="chars", shape=(1, config.MAX_ROMAN_LEN), dtype=np.int32),
            ct.TensorType(name="prev", shape=(1,), dtype=np.int32),
        ],
        minimum_deployment_target=ct.target.iOS15,
        compute_precision=ct.precision.FLOAT32,
    )
    mlmodel.save(str(coreml_path))
    return mlmodel


def tflite_predict(tflite_bytes, inputs):
    interp = tf.lite.Interpreter(model_content=tflite_bytes)
    interp.allocate_tensors()
    in_idx = {d["name"].split(":")[0]: d["index"] for d in interp.get_input_details()}
    chars_idx = next(v for k, v in in_idx.items() if "chars" in k)
    prev_idx = next(v for k, v in in_idx.items() if "prev" in k)
    out_idx = interp.get_output_details()[0]["index"]

    n = len(inputs["chars"])
    results = []
    for i in range(n):
        interp.set_tensor(chars_idx, inputs["chars"][i:i + 1].astype(np.int32))
        interp.set_tensor(prev_idx, inputs["prev"][i:i + 1].astype(np.int32))
        interp.invoke()
        results.append(interp.get_tensor(out_idx).reshape(-1).copy())
    return np.array(results)


def coreml_predict(mlmodel, inputs):
    outname = mlmodel.get_spec().description.output[0].name
    n = len(inputs["chars"])
    results = []
    for i in range(n):
        pred = mlmodel.predict({
            "chars": inputs["chars"][i:i + 1].astype(np.int32),
            "prev": inputs["prev"][i:i + 1].astype(np.int32),
        })
        results.append(np.array(pred[outname]).reshape(-1))
    return np.array(results)


def agreement(keras_probs, other_probs, k):
    keras_top = np.argsort(-keras_probs, axis=1)[:, :k]
    other_top = np.argsort(-other_probs, axis=1)[:, :k]
    if k == 1:
        return float((keras_top[:, 0] == other_top[:, 0]).mean())
    overlaps = [len(set(a) & set(b)) / k for a, b in zip(keras_top, other_top)]
    return float(np.mean(overlaps))


def slice_inputs(inputs, idx):
    return {k: v[idx] for k, v in inputs.items()}


def benchmark(fn, inputs, n=50):
    single = slice_inputs(inputs, slice(0, 1))
    t0 = time.time()
    for _ in range(n):
        fn(single)
    return (time.time() - t0) / n * 1000


def convert(keras_path, tflite_path, coreml_path, dest_dir):
    trained = keras.models.load_model(keras_path, safe_mode=False)
    vocab = load_vocab()
    context_vocab = load_context_vocab()

    # TFLite can't lower go_backwards=True LSTMs via TensorListReserve when the
    # batch dim is dynamic, so rebuild with unroll=True and transfer weights --
    # same architecture/shapes, so set_weights is a straight copy.
    model = build_model(vocab_size=len(vocab), context_vocab_size=len(context_vocab), unroll=True)
    model.set_weights(trained.get_weights())

    char_vocab = load_char_vocab()

    X_val, _y_val, _w_val, rows = load_split(config.VAL_PATH, char_vocab, context_vocab)
    n_sample = min(300, len(X_val["chars"]))
    rng = np.random.default_rng(0)
    sample_idx = rng.choice(len(X_val["chars"]), size=n_sample, replace=False)
    X_sample = slice_inputs(X_val, sample_idx)

    keras_probs = model.predict(X_sample, verbose=0)

    print(f"converting {keras_path.name} to TFLite...")
    tflite_bytes = convert_tflite(model, tflite_path)
    tflite_probs = tflite_predict(tflite_bytes, X_sample)

    print(f"converting {keras_path.name} to CoreML...")
    mlmodel = convert_coreml(model, coreml_path)

    max_diff = np.abs(keras_probs - tflite_probs).max()
    top1 = agreement(keras_probs, tflite_probs, 1)
    top3 = agreement(keras_probs, tflite_probs, 3)
    print(f"TFLite: max prob diff={max_diff:.6f}  top-1 agreement={top1:.4f}  top-3 overlap={top3:.4f}")

    tflite_latency = benchmark(lambda x: tflite_predict(tflite_bytes, x), X_sample)
    print(f"TFLite latency: {tflite_latency:.2f} ms/inference")

    tflite_size_kb = tflite_path.stat().st_size / 1024
    print(f"TFLite size: {tflite_size_kb:.1f} KB")

    try:
        coreml_probs = coreml_predict(mlmodel, X_sample)
    except Exception as e:
        print(f"CoreML runtime check skipped ({e}) -- coremltools can only run inference on "
              "macOS; the .mlpackage was still exported and should be validated on a Mac/iOS "
              "device before shipping.")
    else:
        max_diff = np.abs(keras_probs - coreml_probs).max()
        top1 = agreement(keras_probs, coreml_probs, 1)
        top3 = agreement(keras_probs, coreml_probs, 3)
        print(f"CoreML: max prob diff={max_diff:.6f}  top-1 agreement={top1:.4f}  top-3 overlap={top3:.4f}")
        coreml_latency = benchmark(lambda x: coreml_predict(mlmodel, x), X_sample)
        print(f"CoreML latency: {coreml_latency:.2f} ms/inference")

    dest_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy(config.VOCAB_PATH, dest_dir / config.VOCAB_PATH.name)
    shutil.copy(config.CHAR_VOCAB_PATH, dest_dir / config.CHAR_VOCAB_PATH.name)
    shutil.copy(config.CONTEXT_VOCAB_PATH, dest_dir / config.CONTEXT_VOCAB_PATH.name)

    print(f"saved {tflite_path}")
    print(f"saved {coreml_path}")
    print(f"saved {dest_dir / config.VOCAB_PATH.name}")
    print(f"saved {dest_dir / config.CHAR_VOCAB_PATH.name}")
    print(f"saved {dest_dir / config.CONTEXT_VOCAB_PATH.name}")


def main():
    convert(config.KERAS_MODEL_PATH, config.TFLITE_PATH, config.COREML_PATH, config.MODEL_DIR)


if __name__ == "__main__":
    main()
