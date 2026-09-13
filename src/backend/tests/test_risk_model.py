"""
Unit and integration tests for XGBoost Patient Risk Grading Handler.
"""

import os
import sys
import unittest

# Ensure src/backend is in python path
current_dir = os.path.dirname(os.path.abspath(__file__))
backend_dir = os.path.abspath(os.path.join(current_dir, ".."))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from app.services.risk_model_service import (
    evaluate_patients_risk,
    FEATURE_COLUMNS,
    RISK_METADATA,
)


class TestRiskModelEvaluation(unittest.TestCase):
    def setUp(self):
        self.sample_patients = [
            {
                "patient_id": "P-HIGH",
                "name": "High Risk Patient",
                "age": 78,
                "gender": "Female",
                "accuracy_rate_pct": 45.0,
                "reaction_time_ms": 6800.0,
                "drift_slope_7d": -0.055,
                "active_alert_count": 4,
            },
            {
                "patient_id": "P-MOD",
                "name": "Moderate Risk Patient",
                "age": 67,
                "gender": "Male",
                "accuracy_rate_pct": 74.0,
                "reaction_time_ms": 4700.0,
                "drift_slope_7d": -0.012,
                "active_alert_count": 1,
            },
            {
                "patient_id": "P-LOW",
                "name": "Low Risk Patient",
                "age": 62,
                "gender": "Female",
                "accuracy_rate_pct": 92.0,
                "reaction_time_ms": 2700.0,
                "drift_slope_7d": 0.005,
                "active_alert_count": 0,
            },
        ]

    def test_feature_columns_contract(self):
        self.assertEqual(
            FEATURE_COLUMNS,
            ["age", "accuracy_rate_pct", "reaction_time_ms", "drift_slope_7d", "active_alert_count"],
        )

    def test_batch_evaluation_structure(self):
        result = evaluate_patients_risk(self.sample_patients)
        summary = result["summary"]
        patients = result["patients"]

        self.assertEqual(summary["total_patients"], 3)
        self.assertEqual(
            summary["high_risk_count"] + summary["moderate_risk_count"] + summary["low_risk_count"],
            3,
        )
        self.assertEqual(len(patients), 3)

        for p in patients:
            # Check 6 required column fields exist
            self.assertIn("patient_id", p)
            self.assertIn("name", p)
            self.assertIn("age", p)
            self.assertIn("gender", p)
            self.assertIn("active_alerts_count", p)
            self.assertIn("risk_level", p)
            self.assertIn("recommended_action", p)

            # Check mapping integrity
            grade = p["risk_grade"]
            self.assertIn(grade, [0, 1, 2])
            if grade == 0:
                self.assertEqual(p["risk_level"], "Low Risk")
                self.assertEqual(p["badge_color"], "#2ecc71")
                self.assertEqual(p["recommended_action"], "Routine Check")
            elif grade == 1:
                self.assertEqual(p["risk_level"], "Moderate Risk")
                self.assertEqual(p["badge_color"], "#f39c12")
                self.assertEqual(p["recommended_action"], "Adapt Difficulty")
            elif grade == 2:
                self.assertEqual(p["risk_level"], "High Risk")
                self.assertEqual(p["badge_color"], "#e74c3c")
                self.assertEqual(p["recommended_action"], "Immediate Intervention")

    def test_empty_patient_list(self):
        result = evaluate_patients_risk([])
        self.assertEqual(result["summary"]["total_patients"], 0)
        self.assertEqual(len(result["patients"]), 0)


if __name__ == "__main__":
    unittest.main()
