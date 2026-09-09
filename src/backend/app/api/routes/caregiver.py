"""Caregiver Portal API: patient roster & details + dashboard analytics."""
import random
import uuid
from datetime import datetime, timedelta, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException

from app.core.security import require_caregiver
from app.models.session import GameSession
from app.models.user import DevicePairingToken, RoleEnum, User
from app.schemas.patient import (
    DeviceStatus,
    EmergencyContact,
    PatientCreateRequest,
    PatientDetailOut,
    PatientSummaryOut,
)

router = APIRouter(prefix="/api/caregiver", tags=["caregiver"])


def _user_to_patient_summary(user: User) -> PatientSummaryOut:
    return PatientSummaryOut(
        id=user.patient_code or str(user.id),
        name=user.name,
        age=user.age,
        diagnosis=user.diagnosis,
        avatarUrl=user.avatar_url,
        status=user.status or "stable",
        statusLabel=user.status_label or "Active • Tablet synced",
        lastCheckIn=user.last_check_in or "Just registered",
        pairingToken=user.pairing_token,
    )


def _user_to_patient_detail(user: User) -> PatientDetailOut:
    ec = None
    if user.emergency_contact:
        ec = EmergencyContact(
            name=user.emergency_contact.get("name", "Emergency Contact"),
            relationship=user.emergency_contact.get("relationship", "Guardian"),
            phone=user.emergency_contact.get("phone", "+91 90000 00000"),
        )
    ds = None
    if user.device_status:
        ds = DeviceStatus(
            linked=user.device_status.get("linked", False),
            deviceName=user.device_status.get("deviceName"),
            deviceId=user.device_status.get("deviceId"),
            lastSynced=user.device_status.get("lastSynced"),
        )

    return PatientDetailOut(
        id=user.patient_code or str(user.id),
        name=user.name,
        age=user.age,
        gender=user.gender,
        dateOfBirth=user.date_of_birth,
        healthIssue=user.health_issue,
        avatarUrl=user.avatar_url,
        status=user.status or "stable",
        statusLabel=user.status_label or "Active • Tablet synced",
        lastCheckIn=user.last_check_in or "Just registered",
        emergencyContact=ec,
        deviceStatus=ds,
        pairingToken=user.pairing_token,
    )


async def find_patient_for_caregiver(patient_id_str: str, caregiver_id: uuid.UUID) -> Optional[User]:
    """Find a patient by patient_code, id, or normalized aliases."""
    normalized_id = patient_id_str.strip()

    # Try patient_code first
    patient = await User.find_one(
        User.caregiver_id == caregiver_id,
        User.role == RoleEnum.patient,
        User.patient_code == normalized_id,
    )
    if patient:
        return patient

    # Try UUID if valid
    try:
        parsed_uuid = uuid.UUID(normalized_id)
        patient = await User.find_one(
            User.caregiver_id == caregiver_id,
            User.role == RoleEnum.patient,
            User.id == parsed_uuid,
        )
        if patient:
            return patient
    except ValueError:
        pass

    return None


@router.get("/patients", response_model=List[PatientSummaryOut])
async def list_patients(caregiver: User = Depends(require_caregiver)):
    """Fetch list of all patients assigned to the logged-in caregiver."""
    patients = await User.find(
        User.caregiver_id == caregiver.id,
        User.role == RoleEnum.patient,
    ).to_list()
    return [_user_to_patient_summary(p) for p in patients]


@router.post("/patients", response_model=PatientDetailOut, status_code=201)
async def register_patient(
    payload: PatientCreateRequest,
    caregiver: User = Depends(require_caregiver),
):
    """Register or save a patient under the active caregiver."""
    patient_code = (
        payload.id.strip() if payload.id and payload.id.strip() else f"p{uuid.uuid4().hex[:6]}"
    )

    pairing_token = (
        payload.pairingToken.strip().upper()
        if payload.pairingToken and payload.pairingToken.strip()
        else f"PAIR-{random.randint(100000, 999999)}"
    )

    existing = await User.find_one(
        User.caregiver_id == caregiver.id,
        User.patient_code == patient_code,
    )
    if existing:
        existing.name = payload.name.strip()
        existing.age = payload.age
        existing.gender = payload.gender
        existing.date_of_birth = payload.dateOfBirth
        existing.diagnosis = payload.diagnosis
        existing.health_issue = payload.healthIssue
        existing.avatar_url = payload.avatarUrl
        existing.status = payload.status or "stable"
        existing.status_label = payload.statusLabel or "Active • Tablet synced"
        existing.notes = payload.notes
        existing.pairing_token = pairing_token
        if payload.emergencyContact:
            existing.emergency_contact = payload.emergencyContact
        if payload.deviceStatus:
            existing.device_status = payload.deviceStatus
        await existing.save()
        patient_doc = existing
    else:
        patient = User(
            role=RoleEnum.patient,
            name=payload.name.strip(),
            caregiver_id=caregiver.id,
            patient_code=patient_code,
            pairing_token=pairing_token,
            age=payload.age,
            gender=payload.gender,
            date_of_birth=payload.dateOfBirth,
            diagnosis=payload.diagnosis,
            health_issue=payload.healthIssue,
            avatar_url=payload.avatarUrl,
            status=payload.status or "stable",
            status_label=payload.statusLabel or "Active • Tablet synced",
            last_check_in="Just registered",
            notes=payload.notes,
            emergency_contact=payload.emergencyContact,
            device_status=payload.deviceStatus,
        )
        await patient.insert()
        patient_doc = patient

    # Ensure DevicePairingToken is updated/inserted for immediate pairing
    try:
        pairing_rec = await DevicePairingToken.find_one(
            DevicePairingToken.patient_id == patient_doc.id,
            DevicePairingToken.used == False,  # noqa: E712
        )
        if not pairing_rec:
            pairing_rec = await DevicePairingToken.find_one(
                DevicePairingToken.token == pairing_token,
            )
        if pairing_rec:
            pairing_rec.token = pairing_token
            pairing_rec.patient_id = patient_doc.id
            pairing_rec.caregiver_id = caregiver.id
            pairing_rec.expires_at = datetime.now(timezone.utc) + timedelta(days=365)
            pairing_rec.used = False
            await pairing_rec.save()
        else:
            await DevicePairingToken(
                caregiver_id=caregiver.id,
                patient_id=patient_doc.id,
                token=pairing_token,
                expires_at=datetime.now(timezone.utc) + timedelta(days=365),
                used=False,
            ).insert()
    except Exception as e:
        print(f"[warning] could not upsert DevicePairingToken: {e}")

    return _user_to_patient_detail(patient_doc)


@router.get("/patients/{id}", response_model=PatientDetailOut)
async def get_patient_detail(id: str, caregiver: User = Depends(require_caregiver)):
    """Fetch detailed profile, emergency contact, and device pairing status for a patient."""
    patient = await find_patient_for_caregiver(id, caregiver.id)
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found or unauthorized access")

    return _user_to_patient_detail(patient)


@router.get("/dashboard/{patient_id}")
async def dashboard(patient_id: uuid.UUID, caregiver: User = Depends(require_caregiver)):
    pipeline = [
        {"$match": {"patient_id": patient_id}},
        {
            "$group": {
                "_id": {"$dateToString": {"format": "%Y-%m-%d", "date": "$client_timestamp"}},
                "avg_score": {"$avg": "$performance_score"},
                "sessions": {"$sum": 1},
            }
        },
        {"$sort": {"_id": 1}},
    ]
    rows = await GameSession.find(GameSession.patient_id == patient_id).aggregate(pipeline).to_list()
    return [{"day": r["_id"], "avg_score": r["avg_score"], "sessions": r["sessions"]} for r in rows]
