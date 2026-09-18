"""Pillar 3 read endpoints for the caregiver portal's charts and alert feed."""
import uuid
from typing import List

from fastapi import APIRouter, Depends, HTTPException

from app.core.security import require_caregiver
from app.models.analytics import Alert, DriftMetric
from app.models.user import User
from app.schemas.analytics import AlertOut, DriftMetricOut

router = APIRouter(prefix="/analytics", tags=["analytics"])


async def _ensure_own_patient(caregiver: User, patient_id: uuid.UUID) -> User:
    patient = await User.find_one(User.id == patient_id, User.caregiver_id == caregiver.id)
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")
    return patient


@router.get("/patient/{patient_id}/drift", response_model=List[DriftMetricOut])
async def get_drift(patient_id: uuid.UUID, caregiver: User = Depends(require_caregiver)):
    await _ensure_own_patient(caregiver, patient_id)
    return (
        await DriftMetric.find(DriftMetric.patient_id == patient_id)
        .sort("-computed_at")
        .limit(20)
        .to_list()
    )


@router.get("/patient/{patient_id}/alerts", response_model=List[AlertOut])
async def get_alerts(patient_id: uuid.UUID, caregiver: User = Depends(require_caregiver)):
    await _ensure_own_patient(caregiver, patient_id)
    return (
        await Alert.find(Alert.patient_id == patient_id)
        .sort("-created_at")
        .limit(50)
        .to_list()
    )
