"""
risk_batch_inference.py
=======================
Standalone Python Backend Handler for real-time XGBoost Patient Risk Grading.

Loads 'xgboost_patient_risk_model.pkl', validates patient feature vectors:
  ['age', 'accuracy_rate_pct', 'reaction_time_ms', 'drift_slope_7d', 'active_alert_count']
and executes batch inference to output standardized JSON:
  - 0: "Low Risk" (Grade 0) | UI Badge: Green (#2ecc71) | Action: "Routine Check"
  - 1: "Moderate Risk" (Grade 1) | UI Badge: Orange (#f39c12) | Action: "Adapt Difficulty"
  - 2: "High Risk" (Grade 2) | UI Badge: Red (#e74c3c) | Action: "Immediate Intervention"

Usage:
  1. CLI evaluation of JSON file:
     python risk_batch_inference.py --input patients.json --output results.json

  2. Run standalone demo:
     python risk_batch_inference.py --demo

  3. Run as a dedicated FastAPI server:
     python risk_batch_inference.py --serve --port 8000
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Any, Dict, List, Optional

import joblib
import pandas as pd

FEATURE_COLUMNS: List[str] = [
    "age",
    "accuracy_rate_pct",
    "reaction_time_ms",
    "drift_slope_7d",
    "active_alert_count",
]

RISK_MAPPING: Dict[int, Dict[str, str]] = {
    0: {
        "grade_label": "Grade 0",
        "risk_level": "Low Risk",
        "badge_color": "#2ecc71",
        "recommended_action": "Routine Check",
        "action_description": "Stable cognitive routine check. Continue active monitoring.",
    },
    1: {
        "grade_label": "Grade 1",
        "risk_level": "Moderate Risk",
        "badge_color": "#f39c12",
        "recommended_action": "Adapt Difficulty",
        "action_description": "Mild performance deviation or fatigue. Calibrate cognitive task difficulty.",
    },
    2: {
        "grade_label": "Grade 2",
        "risk_level": "High Risk",
        "badge_color": "#e74c3c",
        "recommended_action": "Immediate Intervention",
        "action_description": "Significant cognitive drift or high alert density. Clinical intervention recommended.",
    },
}

SAMPLE_PATIENTS: List[Dict[str, Any]] = [
    {
        "patient_id": "P-101",
        "name": "Ananya Roy",
        "age": 74,
        "gender": "Female",
        "accuracy_rate_pct": 52.4,
        "reaction_time_ms": 6250.0,
        "drift_slope_7d": -0.048,
        "active_alert_count": 4,
    },
    {
        "patient_id": "P-102",
        "name": "Bimal Sen",
        "age": 68,
        "gender": "Male",
        "accuracy_rate_pct": 71.0,
        "reaction_time_ms": 4890.0,
        "drift_slope_7d": -0.018,
        "active_alert_count": 2,
    },
    {
        "patient_id": "P-103",
        "name": "Chitra Das",
        "age": 63,
        "gender": "Female",
        "accuracy_rate_pct": 89.2,
        "reaction_time_ms": 2980.0,
        "drift_slope_7d": 0.005,
        "active_alert_count": 0,
    },
    {
        "patient_id": "P-104",
        "name": "Debabrata Ghosh",
        "age": 79,
        "gender": "Male",
        "accuracy_rate_pct": 46.8,
        "reaction_time_ms": 6850.0,
        "drift_slope_7d": -0.062,
        "active_alert_count": 5,
    },
    {
        "patient_id": "P-105",
        "name": "Farida Begum",
        "age": 67,
        "gender": "Female",
        "accuracy_rate_pct": 74.5,
        "reaction_time_ms": 4720.0,
        "drift_slope_7d": -0.011,
        "active_alert_count": 1,
    },
    {
        "patient_id": "P-106",
        "name": "Gopal Mukherjee",
        "age": 61,
        "gender": "Male",
        "accuracy_rate_pct": 92.6,
        "reaction_time_ms": 2650.0,
        "drift_slope_7d": 0.008,
        "active_alert_count": 0,
    },
]


def find_model_path(explicit_path: Optional[str] = None) -> str:
    """Resolves path to 'xgboost_patient_risk_model.pkl' across common directories."""
    candidates = [
        explicit_path,
        "xgboost_patient_risk_model.pkl",
        os.path.join(os.path.dirname(__file__), "xgboost_patient_risk_model.pkl"),
        os.path.join(os.path.dirname(__file__), "src", "backend", "app", "agents", "xgboost_patient_risk_model.pkl"),
        os.path.join("src", "backend", "app", "agents", "xgboost_patient_risk_model.pkl"),
    ]
    for c in candidates:
        if c and os.path.isfile(c):
            return os.path.abspath(c)
    raise FileNotFoundError("Could not find 'xgboost_patient_risk_model.pkl'.")


def load_model(model_path: Optional[str] = None) -> Any:
    path = find_model_path(model_path)
    return joblib.load(path)


def run_batch_inference(
    patient_records: List[Dict[str, Any]],
    model: Optional[Any] = None,
    model_path: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Executes batch inference across patient records using the 5 feature attributes.
    Returns structured JSON with summary cards and 6-column tabular attributes.
    """
    if not patient_records:
        return {
            "summary": {
                "total_patients": 0,
                "high_risk_count": 0,
                "moderate_risk_count": 0,
                "low_risk_count": 0,
            },
            "patients": [],
        }

    if model is None:
        model = load_model(model_path)

    # Build feature matrix
    clean_rows = []
    for item in patient_records:
        clean_rows.append({
            "age": float(item.get("age", 65)),
            "accuracy_rate_pct": float(item.get("accuracy_rate_pct", 75.0)),
            "reaction_time_ms": float(item.get("reaction_time_ms", 4500.0)),
            "drift_slope_7d": float(item.get("drift_slope_7d", 0.0)),
            "active_alert_count": int(item.get("active_alert_count", item.get("active_alerts_count", 0))),
        })

    df = pd.DataFrame(clean_rows)[FEATURE_COLUMNS]
    predictions = model.predict(df)

    high_risk = 0
    moderate_risk = 0
    low_risk = 0
    evaluated_patients = []

    for idx, raw in enumerate(patient_records):
        pred = int(predictions[idx])
        if pred == 2:
            high_risk += 1
        elif pred == 1:
            moderate_risk += 1
        else:
            pred = 0
            low_risk += 1

        info = RISK_MAPPING[pred]
        alerts_count = clean_rows[idx]["active_alert_count"]

        evaluated_patients.append({
            "patient_id": str(raw.get("patient_id") or raw.get("id") or f"P-{101+idx}"),
            "name": str(raw.get("name") or f"Patient {idx+1}"),
            "age": int(clean_rows[idx]["age"]),
            "gender": str(raw.get("gender") or "Not Specified"),
            "active_alerts_count": alerts_count,
            "risk_grade": pred,
            "grade_label": info["grade_label"],
            "risk_level": info["risk_level"],
            "badge_color": info["badge_color"],
            "recommended_action": info["recommended_action"],
            "action_description": info["action_description"],
            "features": clean_rows[idx],
        })

    return {
        "summary": {
            "total_patients": len(evaluated_patients),
            "high_risk_count": high_risk,
            "moderate_risk_count": moderate_risk,
            "low_risk_count": low_risk,
        },
        "patients": evaluated_patients,
    }


def create_fastapi_app() -> Any:
    """Creates a standalone FastAPI instance if user runs with --serve."""
    from fastapi import FastAPI
    from fastapi.middleware.cors import CORSMiddleware
    from pydantic import BaseModel, Field

    app = FastAPI(
        title="Patient Risk Inference Service",
        description="XGBoost real-time cognitive decline grading handler",
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

    loaded_ml_model = load_model()

    class PatientItem(BaseModel):
        patient_id: Optional[str] = None
        id: Optional[str] = None
        name: Optional[str] = "Unknown"
        age: int = 65
        gender: Optional[str] = "Not Specified"
        accuracy_rate_pct: float
        reaction_time_ms: float
        drift_slope_7d: float
        active_alert_count: int

    class BatchReq(BaseModel):
        patients: List[PatientItem]

    @app.post("/api/risk/predict")
    def predict(req: BatchReq):
        records = [p.model_dump() for p in req.patients]
        return run_batch_inference(records, model=loaded_ml_model)

    @app.get("/api/risk/demo-patients")
    def get_demo():
        return run_batch_inference(SAMPLE_PATIENTS, model=loaded_ml_model)

    @app.get("/health")
    def health():
        return {"status": "ok", "model_loaded": True}

    return app


def main():
    parser = argparse.ArgumentParser(description="XGBoost Patient Risk Batch Inference Handler")
    parser.add_argument("--input", "-i", help="Path to input JSON file containing array of patient objects")
    parser.add_argument("--output", "-o", help="Path to write formatted output JSON")
    parser.add_argument("--model", "-m", help="Path to xgboost_patient_risk_model.pkl")
    parser.add_argument("--demo", action="store_true", help="Run inference on sample benchmark patients")
    parser.add_argument("--serve", action="store_true", help="Launch standalone FastAPI server")
    parser.add_argument("--port", type=int, default=8000, help="Port for standalone FastAPI server")
    args = parser.parse_args()

    if args.serve:
        import uvicorn
        print(f"Launching standalone FastAPI inference server on port {args.port}...")
        uvicorn.run(create_fastapi_app(), host="0.0.0.0", port=args.port)
        return

    # Load input data
    if args.input:
        with open(args.input, "r", encoding="utf-8") as f:
            data = json.load(f)
            if isinstance(data, dict) and "patients" in data:
                patients = data["patients"]
            elif isinstance(data, list):
                patients = data
            else:
                raise ValueError("Input JSON must be a list of patients or an object with 'patients' key.")
    else:
        print("[INFO] No input file specified. Running demonstration dataset:")
        patients = SAMPLE_PATIENTS

    result = run_batch_inference(patients, model_path=args.model)

    output_str = json.dumps(result, indent=2)

    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(output_str)
        print(f"[SUCCESS] Evaluated {result['summary']['total_patients']} patients. Output written to '{args.output}'.")
    else:
        print(output_str)


if __name__ == "__main__":
    main()
