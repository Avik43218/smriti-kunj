"""
Risk Model Service
==================
Loads pre-trained XGBoost / GradientBoosting model artifact ('xgboost_patient_risk_model.pkl')
and executes real-time batch inference across patient records.
"""

from __future__ import annotations

import os
from typing import Any, Dict, List, Optional, Tuple, Union
import joblib
import pandas as pd

FEATURE_COLUMNS: List[str] = [
    "age",
    "accuracy_rate_pct",
    "reaction_time_ms",
    "drift_slope_7d",
    "active_alert_count",
]

RISK_METADATA: Dict[int, Dict[str, str]] = {
    0: {
        "grade_label": "Grade 0",
        "risk_level": "Low Risk",
        "badge_color": "#2ecc71",
        "recommended_action": "Routine Check",
        "description": "Stable cognitive routine check. Continue active monitoring.",
    },
    1: {
        "grade_label": "Grade 1",
        "risk_level": "Moderate Risk",
        "badge_color": "#f39c12",
        "recommended_action": "Adapt Difficulty",
        "description": "Mild performance deviation or fatigue. Calibrate cognitive task difficulty.",
    },
    2: {
        "grade_label": "Grade 2",
        "risk_level": "High Risk",
        "badge_color": "#e74c3c",
        "recommended_action": "Immediate Intervention",
        "description": "Significant cognitive drift or high alert density. Clinical intervention recommended.",
    },
}

_MODEL_CACHE: Optional[Any] = None


def resolve_model_path(custom_path: Optional[str] = None) -> str:
    """Finds the xgboost_patient_risk_model.pkl artifact across common directories."""
    candidates = []
    if custom_path:
        candidates.append(custom_path)

    current_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.abspath(os.path.join(current_dir, "..", "..", "..", ".."))

    candidates.extend([
        os.path.join(current_dir, "..", "agents", "xgboost_patient_risk_model.pkl"),
        os.path.join(current_dir, "xgboost_patient_risk_model.pkl"),
        os.path.join(project_root, "src", "backend", "app", "agents", "xgboost_patient_risk_model.pkl"),
        os.path.join(project_root, "xgboost_patient_risk_model.pkl"),
        os.path.join(os.getcwd(), "src", "backend", "app", "agents", "xgboost_patient_risk_model.pkl"),
        os.path.join(os.getcwd(), "xgboost_patient_risk_model.pkl"),
        "xgboost_patient_risk_model.pkl",
    ])

    for candidate in candidates:
        if candidate and os.path.isfile(candidate):
            return os.path.abspath(candidate)

    raise FileNotFoundError(
        "Could not locate 'xgboost_patient_risk_model.pkl'. Please ensure the artifact exists."
    )


def get_risk_model(model_path: Optional[str] = None) -> Any:
    """Singleton getter for the loaded model instance."""
    global _MODEL_CACHE
    if _MODEL_CACHE is not None:
        return _MODEL_CACHE

    target_path = resolve_model_path(model_path)
    _MODEL_CACHE = joblib.load(target_path)
    return _MODEL_CACHE


def evaluate_patients_risk(
    patients_data: List[Dict[str, Any]],
    model_path: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Executes batch inference on incoming patient records using the 5 required features:
      ['age', 'accuracy_rate_pct', 'reaction_time_ms', 'drift_slope_7d', 'active_alert_count']

    Maps predicted integer:
      0 -> "Low Risk" (Grade 0) | UI Badge: Green (#2ecc71) | Action: "Routine Check"
      1 -> "Moderate Risk" (Grade 1) | UI Badge: Orange (#f39c12) | Action: "Adapt Difficulty"
      2 -> "High Risk" (Grade 2) | UI Badge: Red (#e74c3c) | Action: "Immediate Intervention"
    """
    if not patients_data:
        return {
            "summary": {
                "total_patients": 0,
                "high_risk_count": 0,
                "moderate_risk_count": 0,
                "low_risk_count": 0,
            },
            "patients": [],
        }

    model = get_risk_model(model_path)

    # Extract features into normalized DataFrame
    feature_rows = []
    for item in patients_data:
        row = {
            "age": float(item.get("age", 65) or 65),
            "accuracy_rate_pct": float(item.get("accuracy_rate_pct", 75.0) if item.get("accuracy_rate_pct") is not None else 75.0),
            "reaction_time_ms": float(item.get("reaction_time_ms", 4500.0) if item.get("reaction_time_ms") is not None else 4500.0),
            "drift_slope_7d": float(item.get("drift_slope_7d", 0.0) if item.get("drift_slope_7d") is not None else 0.0),
            "active_alert_count": int(item.get("active_alert_count", item.get("active_alerts_count", 0)) or 0),
        }
        feature_rows.append(row)

    df_features = pd.DataFrame(feature_rows)[FEATURE_COLUMNS]

    predictions = model.predict(df_features)

    high_risk = 0
    moderate_risk = 0
    low_risk = 0
    evaluated_records = []

    for i, item in enumerate(patients_data):
        pred_int = int(predictions[i])
        if pred_int == 2:
            high_risk += 1
        elif pred_int == 1:
            moderate_risk += 1
        else:
            pred_int = 0
            low_risk += 1

        meta = RISK_METADATA.get(pred_int, RISK_METADATA[0])
        alerts_count = feature_rows[i]["active_alert_count"]

        evaluated_records.append({
            "patient_id": str(item.get("patient_id") or item.get("id") or f"P-{101+i}"),
            "name": str(item.get("name") or f"Patient {i+1}"),
            "age": int(feature_rows[i]["age"]),
            "gender": str(item.get("gender") or "Not Specified"),
            "active_alerts_count": alerts_count,
            "risk_grade": pred_int,
            "grade_label": meta["grade_label"],
            "risk_level": meta["risk_level"],
            "badge_color": meta["badge_color"],
            "recommended_action": meta["recommended_action"],
            "action_description": meta["description"],
            "features": feature_rows[i],
        })

    return {
        "summary": {
            "total_patients": len(evaluated_records),
            "high_risk_count": high_risk,
            "moderate_risk_count": moderate_risk,
            "low_risk_count": low_risk,
        },
        "patients": evaluated_records,
    }
