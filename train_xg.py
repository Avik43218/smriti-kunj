import joblib
import pandas as pd
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.model_selection import train_test_split

# Optional: Swap with native XGBoost if preferred
# from xgboost import XGBClassifier

# ==============================================================================
# 1. LOAD DATASET & DEFINE FEATURE MATRIX
# ==============================================================================
csv_filepath = "clean_supervised_learning_dataset_realistic.csv"
df = pd.read_csv(csv_filepath)

# Define clean feature set (X) and ground-truth target labels (y)
feature_cols = [
    "age",
    "accuracy_rate_pct",
    "reaction_time_ms",
    "drift_slope_7d",
    "active_alert_count",
]

X = df[feature_cols]
y = df["target_risk_level"]  # Target grades: 0 (Low), 1 (Moderate), 2 (High)

# ==============================================================================
# 2. STRATIFIED TRAIN-TEST SPLIT
# ==============================================================================
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.25, random_state=42, stratify=y
)

# ==============================================================================
# 3. INITIALIZE & TRAIN THE MODEL
# ==============================================================================
model = GradientBoostingClassifier(
    n_estimators=100, learning_rate=0.1, max_depth=3, random_state=42
)

# Native XGBoost alternative syntax:
# model = XGBClassifier(n_estimators=100, learning_rate=0.1, max_depth=3, random_state=42, eval_metric='mlogloss')

model.fit(X_train, y_train)

# ==============================================================================
# 4. EVALUATE MODEL PERFORMANCE ON TEST SET
# ==============================================================================
y_pred = model.predict(X_test)
accuracy = accuracy_score(y_test, y_pred)

print(f"--- Model Training Complete ---")
print(f"Test Set Accuracy: {accuracy * 100:.2f}%\n")

print("Classification Report:")
print(
    classification_report(
        y_test,
        y_pred,
        target_names=[
            "Grade 0 (Low Risk)",
            "Grade 1 (Moderate Risk)",
            "Grade 2 (High Risk)",
        ],
    )
)

print("Confusion Matrix:")
print(confusion_matrix(y_test, y_pred))

# ==============================================================================
# 5. SAVE MODEL ARTIFACT TO DISK
# ==============================================================================
model_filename = "xgboost_patient_risk_model.pkl"
joblib.dump(model, model_filename)
print(f"\n[INFO] Trained model successfully saved to '{model_filename}'")

# ==============================================================================
# 6. DEMO INFERENCE: RELOAD SAVED MODEL & PREDICT NEW PATIENTS
# ==============================================================================
# Load the saved .pkl file back into memory
loaded_model = joblib.load(model_filename)

# Sample new patient test case
new_patient_data = pd.DataFrame(
    [
        {
            "age": 68,
            "accuracy_rate_pct": 72.5,
            "reaction_time_ms": 5800.0,
            "drift_slope_7d": -0.012,
            "active_alert_count": 3,
        }
    ]
)

# Run prediction
predicted_grade = loaded_model.predict(new_patient_data)[0]
grade_labels = {
    0: "Grade 0: Low Risk / Stable Routine Check",
    1: "Grade 1: Moderate Risk / Adapt Difficulty",
    2: "Grade 2: High Risk / Clinical Intervention Alert",
}

print("\n--- Live Patient Inference Test ---")
print(f"Predicted Risk Grade: {predicted_grade}")
print(f"Clinical Condition: {grade_labels[predicted_grade]}")
