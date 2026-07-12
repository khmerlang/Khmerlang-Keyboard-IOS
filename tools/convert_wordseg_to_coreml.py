import numpy as np, tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

interp = tf.lite.Interpreter(
    model_path="/tmp/khmerlang-android/app/src/main/ml/word_seg_model.tflite",
    experimental_op_resolver_type=tf.lite.experimental.OpResolverType.BUILTIN_WITHOUT_DEFAULT_DELEGATES)
interp.allocate_tensors()
T = lambda i: interp.get_tensor(i)
def W(i2, rec, bias):
    return [np.concatenate([T(i).T for i in i2], axis=1),
            np.concatenate([T(i).T for i in rec], axis=1),
            np.concatenate([T(i) for i in bias])]

inp = keras.Input(shape=(328,), dtype="int32", name="chars")
x = layers.Embedding(114, 256, name="emb")(inp)
flip = layers.Lambda(lambda t: tf.reverse(t, axis=[1]))
fw1 = layers.LSTM(64, return_sequences=True, name="fw1")(x)
bw1 = flip(layers.LSTM(64, return_sequences=True, go_backwards=True, name="bw1")(x))
x = layers.Concatenate(name="cat1")([fw1, bw1])
fw2 = layers.LSTM(32, return_sequences=True, name="fw2")(x)
bw2 = flip(layers.LSTM(32, return_sequences=True, go_backwards=True, name="bw2")(x))
x = layers.Concatenate(name="cat2")([fw2, bw2])
x = layers.Dense(64, activation="relu", name="d1")(x)
out = layers.Dense(1, name="d2")(x)
model = keras.Model(inp, out)

model.get_layer("emb").set_weights([T(1)])
model.get_layer("fw1").set_weights(W([29,30,31,32],[21,22,23,24],[25,26,27,28]))
model.get_layer("bw1").set_weights(W([17,18,19,20],[9,10,11,12],[13,14,15,16]))
model.get_layer("fw2").set_weights(W([53,54,55,56],[45,46,47,48],[49,50,51,52]))
model.get_layer("bw2").set_weights(W([41,42,43,44],[33,34,35,36],[37,38,39,40]))
model.get_layer("d1").set_weights([T(57).T, T(3)])
model.get_layer("d2").set_weights([T(58).T, T(2)])

def tflite_run(idx):
    interp.reset_all_variables()
    interp.set_tensor(interp.get_input_details()[0]["index"], idx.astype(np.float32).reshape(1,328))
    interp.invoke()
    return interp.get_tensor(interp.get_output_details()[0]["index"]).reshape(328)

rng = np.random.default_rng(7)
tests = [np.zeros(328, np.int64)] + [rng.integers(0, 114, 328) for _ in range(4)]
worst = max(np.abs(tflite_run(a) - model.predict(a.reshape(1,328).astype("int32"), verbose=0).reshape(328)).max() for a in tests)
print(f"KERAS vs TFLITE max abs diff: {worst:.7f}")
assert worst < 1e-2

import coremltools as ct
@tf.function
def f(chars):
    return model(chars)
cf = f.get_concrete_function(tf.TensorSpec((1, 328), tf.int32, name="chars"))
mlmodel = ct.convert([cf], source="tensorflow",
                     inputs=[ct.TensorType(name="chars", shape=(1,328), dtype=np.int32)],
                     minimum_deployment_target=ct.target.iOS15,
                     compute_precision=ct.precision.FLOAT32)
mlmodel.save("/tmp/WordSegModel.mlpackage")

m = ct.models.MLModel("/tmp/WordSegModel.mlpackage")
outname = m.get_spec().description.output[0].name
print("coreml output name:", outname)
worst = max(np.abs(tflite_run(a) - np.array(m.predict({"chars": a.reshape(1,328).astype(np.int32)})[outname]).reshape(328)).max() for a in tests)
print(f"COREML vs TFLITE max abs diff: {worst:.7f}")

import time
a = tests[1].reshape(1,328).astype(np.int32)
t0 = time.time()
for _ in range(50): m.predict({"chars": a})
print(f"coreml latency: {(time.time()-t0)/50*1000:.1f} ms/inference (mac)")
