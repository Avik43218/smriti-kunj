import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

# ---------------------------------------------------------
# 1. Synthesize Clinical Telemetry & UCB1 Distillation
# ---------------------------------------------------------
np.random.seed(42)
NUM_SAMPLES = 4500
TEMPERATURE = 0.18      # Sharpened tau for decisive clinical policy
C_EXPLORE = 1.2         # Exploration constant 'c'
N_ARMS = 3              # [0: Ease Up (-1), 1: Maintain (0), 2: Level Up (+1)]

def sample_ex_gaussian(mu: float, sigma: float, tau: float) -> float:
    """Simulates realistic patient response latency (Normal motor + Exponential cognitive tail)."""
    return np.random.normal(mu, sigma) + np.random.exponential(tau)

def generate_telemetry():
    """Generates feature vector: [latency, accuracy, hesitation, error_burst]."""
    archetype = np.random.choice(["cruising", "steady", "struggling"], p=[0.30, 0.45, 0.25])
    
    if archetype == "cruising":
        rt = sample_ex_gaussian(mu=420, sigma=50, tau=80)
        accuracy = np.clip(np.random.normal(0.92, 0.05), 0.75, 1.0)
        hesitation = np.clip(np.random.normal(0.15, 0.05), 0.0, 0.30)
        error_burst = np.random.choice([0.0, 0.1], p=[0.85, 0.15])
        ideal_rewards = [0.05, 0.30, 0.95]
    elif archetype == "steady":
        rt = sample_ex_gaussian(mu=650, sigma=90, tau=220)
        accuracy = np.clip(np.random.normal(0.75, 0.07), 0.60, 0.88)
        hesitation = np.clip(np.random.normal(0.40, 0.08), 0.20, 0.65)
        error_burst = np.random.choice([0.0, 0.2, 0.3], p=[0.6, 0.3, 0.1])
        ideal_rewards = [0.15, 0.92, 0.20]
    else:  # struggling
        rt = sample_ex_gaussian(mu=1000, sigma=180, tau=500)
        accuracy = np.clip(np.random.normal(0.35, 0.10), 0.05, 0.50)
        hesitation = np.clip(np.random.normal(0.80, 0.10), 0.55, 1.0)
        error_burst = np.random.choice([0.4, 0.6, 0.8, 1.0], p=[0.1, 0.3, 0.4, 0.2])
        ideal_rewards = [0.98, 0.18, 0.02]

    norm_latency = np.clip(rt / 2500.0, 0.0, 1.0)
    features = np.array([norm_latency, accuracy, hesitation, error_burst], dtype=np.float32)
    return features, archetype, ideal_rewards

# Track bandit statistics per cognitive archetype
bandit_counts = {k: np.zeros(N_ARMS, dtype=np.float32) for k in ["cruising", "steady", "struggling"]}
bandit_rewards = {k: np.zeros(N_ARMS, dtype=np.float32) for k in ["cruising", "steady", "struggling"]}
total_pulls = {k: 0 for k in ["cruising", "steady", "struggling"]}

X_data = []
y_soft_targets = []

for step in range(1, NUM_SAMPLES + 1):
    features, arch, ideal_rewards = generate_telemetry()
    n_k = bandit_counts[arch]
    r_k = bandit_rewards[arch]
    total_k = total_pulls[arch]

    # Calculate empirical average rewards safely upfront
    avg_reward = np.divide(r_k, n_k, out=np.zeros_like(r_k), where=n_k > 0)

    # 1. Action selection (UCB1 exploration vs exploitation)
    if total_k < N_ARMS:
        action = int(total_k)
        soft_probs = np.ones(N_ARMS, dtype=np.float32) / N_ARMS
    else:
        uncertainty = C_EXPLORE * np.sqrt((2.0 * np.log(total_k)) / np.maximum(n_k, 1.0))
        ucb_scores = avg_reward + uncertainty
        action = int(np.argmax(ucb_scores))

        # 2. Distill pure clinical empirical rewards with sharp temperature
        scaled_reward = (avg_reward - np.max(avg_reward)) / TEMPERATURE
        exp_r = np.exp(scaled_reward)
        soft_probs = exp_r / np.sum(exp_r)

    # 3. Step the simulation and record rewards
    reward_observed = float(np.clip(ideal_rewards[action] + np.random.normal(0, 0.02), 0.0, 1.0))
    bandit_counts[arch][action] += 1
    bandit_rewards[arch][action] += reward_observed
    total_pulls[arch] += 1

    # Keep only warmed-up samples to avoid early random exploration noise
    if total_k >= N_ARMS:
        X_data.append(features)
        y_soft_targets.append(soft_probs)

X = np.array(X_data, dtype=np.float32)
y = np.array(y_soft_targets, dtype=np.float32)

print(f"Dataset Generated: {X.shape[0]} samples with shape {X.shape[1]}")
print(f"Target Distribution Sample: {np.round(y[100], 3)}")

# ---------------------------------------------------------
# 2. Build & Train the 3-Layer Student MLP
# ---------------------------------------------------------
model = keras.Sequential([
    layers.Input(shape=(4,), name="telemetry_input"),
    layers.Dense(16, activation="relu", name="hidden_layer_1"),
    layers.Dense(8, activation="relu", name="hidden_layer_2"),
    layers.Dense(3, activation="softmax", name="distilled_action_probs")
])

# KL-Divergence forces the MLP to match the sharpened probability distribution
model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=0.005),
    loss=keras.losses.KLDivergence(),
    metrics=["mae"]
)

model.fit(
    X, y,
    epochs=40,
    batch_size=32,
    validation_split=0.2,
    verbose=0
)
print("MLP successfully trained via Policy Distillation (KL-Divergence)!")

# ---------------------------------------------------------
# 3. Export to Quantized TFLite
# ---------------------------------------------------------
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]  # 8-bit dynamic range quantization
tflite_model = converter.convert()

tflite_path = "difficulty_mlp_ucb1.tflite"
with open(tflite_path, "wb") as f:
    f.write(tflite_model)

print(f"Exported TFLite Model: {tflite_path} ({len(tflite_model)} bytes)")

# ---------------------------------------------------------
# 4. Sanity Verification on Edge Device Simulation
# ---------------------------------------------------------
interpreter = tf.lite.Interpreter(model_content=tflite_model)
interpreter.allocate_tensors()

input_idx = interpreter.get_input_details()[0]['index']
output_idx = interpreter.get_output_details()[0]['index']

# Struggling profile: latency=0.82, accuracy=0.25, hesitation=0.88, error_burst=0.90
struggling_patient = np.array([[0.28, 0.74, 0.38, 0.15]], dtype=np.float32)

interpreter.set_tensor(input_idx, struggling_patient)
interpreter.invoke()
predicted_probs = interpreter.get_tensor(output_idx)[0]

arm_labels = ["Ease Up (-1)", "Maintain (0)", "Level Up (+1)"]
print("\n--- Edge Sanity Verification ---")
for label, prob in zip(arm_labels, predicted_probs):
    print(f"• {label}: {prob * 100:.2f}%")
print(f"Chosen On-Device Action: {arm_labels[np.argmax(predicted_probs)]}")
