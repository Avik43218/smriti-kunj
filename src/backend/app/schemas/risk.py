"""
Pydantic schemas for real-time XGBoost patient risk grading.
"""

from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class PatientRiskInput(BaseModel):
    patient_id: Optional[str] = Field(None, description="Patient UUID or code (e.g. P-101)")
    id: Optional[str] = None
    name: Optional[str] = Field("Unknown Patient", description="Full patient name")
    age: int = Field(65, ge=0, le=125, description="Patient age in years")
    gender: Optional[str] = Field("Not Specified", description="Patient gender")
    accuracy_rate_pct: float = Field(
        ...,
        ge=0.0,
        le=100.0,
        description="Cognitive session accuracy percentage (0.0 - 100.0)",
    )
    reaction_time_ms: float = Field(
        ...,
        ge=0.0,
        description="Average reaction time in milliseconds",
    )
    drift_slope_7d: float = Field(
        ...,
        description="Rolling 7-day linear regression slope beta_1",
    )
    active_alert_count: int = Field(
        ...,
        ge=0,
        description="Count of currently active unresolved clinical alerts",
    )


class BatchRiskPredictionRequest(BaseModel):
    patients: List[PatientRiskInput]


class PatientRiskOutput(BaseModel):
    patient_id: str
    name: str
    age: int
    gender: str
    active_alerts_count: int
    risk_grade: int
    grade_label: str
    risk_level: str
    badge_color: str
    recommended_action: str
    action_description: str
    features: Dict[str, Any]


class RiskSummary(BaseModel):
    total_patients: int
    high_risk_count: int
    moderate_risk_count: int
    low_risk_count: int


class BatchRiskPredictionResponse(BaseModel):
    summary: RiskSummary
    patients: List[PatientRiskOutput]
