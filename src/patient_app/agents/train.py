import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

# 1. Forge synthetic clinical telemetry data (1500 samples)
np.random.seed(42)
NUM_SAMPLES = 1500

# Features: [latency, accuracy, hesitation, error_burst, current_level]
X = np.random.uniform(0.0, 1.0, size=(NUM_SAMPLES, 5)).astype(np.float32)
y = np.zeros(NUM_SAMPLES, dtype=np.int32)

for i in range(NUM_SAMPLES):
    latency, acc, hes, err_burst, lvl = X[i]
    # Ease up (0): High errors, bad accuracy, or excessive fatigue
    if acc < 0.5 or err_burst > 0.6 or (latency > 0.75 and hes > 0.7):
        y[i] = 0
    # Level up (2): High accuracy, sharp response times, minimal hesitation
    elif acc > 0.85 and latency < 0.4 and err_burst < 0.2:
        y[i] = 2
    # Maintain (1): Steady progress in the middle ground
    else:
        y[i] = 1

# 2. Build the lightweight MLP architecture
model = keras.Sequential([
    layers.Input(shape=(5,), name="telemetry_input"),
    layers.Dense(16, activation="relu", name="dense_1"),
    layers.Dense(8, activation="relu", name="dense_2"),
    layers.Dense(3, activation="softmax", name="difficulty_decision")
])

model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=0.01),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"]
)

# 3. Train the model
model.fit(X, y, epochs=30, batch_size=32, verbose=0)

# 4. Convert and quantize to TFLite
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]  # Dynamic range quantization
tflite_model = converter.convert()

# 5. Export binary
model_path = "difficulty_mlp.tflite"
with open(model_path, "wb") as f:
    f.write(tflite_model)

print(f"Model successfully exported to {model_path} ({len(tflite_model)} bytes)")

# 6. Sanity check: Run test inference
interpreter = tf.lite.Interpreter(model_content=tflite_model)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

# Test vector: Struggling patient [latency=0.85, acc=0.35, hes=0.80, err=0.75, lvl=0.5]
sample_patient = np.array([[0.85, 0.35, 0.80, 0.75, 0.5]], dtype=np.float32)
interpreter.set_tensor(input_details[0]['index'], sample_patient)
interpreter.invoke()
output = interpreter.get_tensor(output_details[0]['index'])[0]

actions = ["Ease Up (-1)", "Maintain (0)", "Level Up (+1)"]
print(f"Test Prediction: {actions[np.argmax(output)]} with confidence {np.max(output):.2f}")
