import numpy as np
import tensorflow as tf

class DifficultyPredictor:
    def __init__(self, model_path: str = "difficulty_mlp_ucb1.tflite"):
        # 1. Load the TFLite binary into memory
        self.interpreter = tf.lite.Interpreter(model_path=model_path)
        self.interpreter.allocate_tensors()

        # 2. Cache input & output tensor addresses
        self.input_details = self.interpreter.get_input_details()
        self.output_details = self.interpreter.get_output_details()
        self.input_index = self.input_details[0]["index"]
        self.output_index = self.output_details[0]["index"]

        self.actions = ["Ease Up (-1)", "Maintain (0)", "Level Up (+1)"]

    def predict(self, latency: float, accuracy: float, hesitation: float, error_burst: float):
        """
        Feeds normalized telemetry [0.0 - 1.0] and returns dynamic difficulty action.
        """
        # Shape must match model input: (batch_size=1, features=4)
        input_data = np.array([[latency, accuracy, hesitation, error_burst]], dtype=np.float32)

        # 3. Set input tensor, run execution, and extract logits
        self.interpreter.set_tensor(self.input_index, input_data)
        self.interpreter.invoke()
        probabilities = self.interpreter.get_tensor(self.output_index)[0]

        best_action_idx = int(np.argmax(probabilities))
        
        return {
            "action": self.actions[best_action_idx],
            "difficulty_delta": [-1, 0, 1][best_action_idx],
            "confidence": float(probabilities[best_action_idx]),
            "raw_distribution": {
                label: float(prob) for label, prob in zip(self.actions, probabilities)
            }
        }

# ---------------------------------------------------------
# Test Drive in Another Script
# ---------------------------------------------------------
if __name__ == "__main__":
    predictor = DifficultyPredictor("difficulty_mlp_ucb1.tflite")

    # Example: Patient experiencing sudden motor fatigue
    # (high latency, low accuracy, high hesitation, high error burst)
    result = predictor.predict(latency=0.78, accuracy=0.30, hesitation=0.85, error_burst=0.80)

    print(f"Action: {result['action']}")
    print(f"Confidence: {result['confidence'] * 100:.2f}%")
    print(f"Distribution: {result['raw_distribution']}")
