"""Admin API routes for cross-caregiver and patient management."""
import uuid
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.dependencies import require_admin
from app.core.security import hash_password
from app.models.user import DevicePairingToken, RoleEnum, User
from app.schemas.admin import (
    CaregiverAdminOut,
    CaregiverCreateAdminRequest,
    CaregiverUpdateAdminRequest,
    PatientAdminOut,
    PatientReassignRequest,
)

router = APIRouter(prefix="/api/admin", tags=["admin"])


async def _find_patient_by_identifier(identifier: str) -> Optional[User]:
    """Find patient by UUID or patient_code."""
    ident = identifier.strip()
    try:
        parsed_uuid = uuid.UUID(ident)
        patient = await User.find_one(User.id == parsed_uuid, User.role == RoleEnum.patient)
        if patient:
            return patient
    except ValueError:
        pass

    patient = await User.find_one(User.patient_code == ident, User.role == RoleEnum.patient)
    return patient


@router.get("/caregivers", response_model=List[CaregiverAdminOut])
async def list_caregivers(_: User = Depends(require_admin)):
    """List all caregivers with their patient counts."""
    caregivers = await User.find(
        User.role == RoleEnum.caregiver
    ).to_list()

    results: List[CaregiverAdminOut] = []
    for c in caregivers:
        patient_count = await User.find(
            User.caregiver_id == c.id,
            User.role == RoleEnum.patient,
        ).count()

        results.append(
            CaregiverAdminOut(
                id=c.id,
                name=c.name,
                email=c.email,
                region_language=c.region_language or "bn",
                role=c.role.value if hasattr(c.role, "value") else str(c.role),
                status=getattr(c, "status", "active") or "active",
                patient_count=patient_count,
                created_at=c.created_at,
                created_by=str(c.created_by) if c.created_by else None,
            )
        )

    return results


@router.post("/caregivers", response_model=CaregiverAdminOut, status_code=201)
async def create_caregiver(
    payload: CaregiverCreateAdminRequest,
    admin_user: User = Depends(require_admin),
):
    """Admin creates a caregiver account directly (bypassing self-registration OTP)."""
    if await User.find_one(User.email == payload.email):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with that email already exists",
        )

    caregiver = User(
        role=RoleEnum.caregiver,
        name=payload.name.strip(),
        email=payload.email,
        hashed_password=hash_password(payload.password),
        region_language=payload.region_language or "bn",
        created_by=admin_user.id,
        status=payload.status or "active",
    )
    await caregiver.insert()

    return CaregiverAdminOut(
        id=caregiver.id,
        name=caregiver.name,
        email=caregiver.email,
        region_language=caregiver.region_language,
        role=caregiver.role.value if hasattr(caregiver.role, "value") else str(caregiver.role),
        status=caregiver.status or "active",
        patient_count=0,
        created_at=caregiver.created_at,
        created_by=str(caregiver.created_by) if caregiver.created_by else None,
    )


@router.patch("/caregivers/{caregiver_id}", response_model=CaregiverAdminOut)
async def update_caregiver(
    caregiver_id: uuid.UUID,
    payload: CaregiverUpdateAdminRequest,
    _: User = Depends(require_admin),
):
    """Edit caregiver profile or enable/disable caregiver account."""
    caregiver = await User.find_one(User.id == caregiver_id, User.role == RoleEnum.caregiver)
    if not caregiver:
        raise HTTPException(status_code=404, detail="Caregiver not found")

    if payload.email and payload.email != caregiver.email:
        existing = await User.find_one(User.email == payload.email, User.id != caregiver.id)
        if existing:
            raise HTTPException(status_code=409, detail="Email is already in use by another user")
        caregiver.email = payload.email

    if payload.name is not None:
        caregiver.name = payload.name.strip()

    if payload.region_language is not None:
        caregiver.region_language = payload.region_language

    if payload.status is not None:
        caregiver.status = payload.status

    await caregiver.save()

    patient_count = await User.find(
        User.caregiver_id == caregiver.id,
        User.role == RoleEnum.patient,
    ).count()

    return CaregiverAdminOut(
        id=caregiver.id,
        name=caregiver.name,
        email=caregiver.email,
        region_language=caregiver.region_language or "bn",
        role=caregiver.role.value if hasattr(caregiver.role, "value") else str(caregiver.role),
        status=caregiver.status or "active",
        patient_count=patient_count,
        created_at=caregiver.created_at,
        created_by=str(caregiver.created_by) if caregiver.created_by else None,
    )


@router.delete("/caregivers/{caregiver_id}")
async def delete_caregiver(
    caregiver_id: uuid.UUID,
    _: User = Depends(require_admin),
):
    """Delete caregiver; blocks with error message if caregiver has assigned patients."""
    caregiver = await User.find_one(User.id == caregiver_id, User.role == RoleEnum.caregiver)
    if not caregiver:
        raise HTTPException(status_code=404, detail="Caregiver not found")

    patient_count = await User.find(
        User.caregiver_id == caregiver.id,
        User.role == RoleEnum.patient,
    ).count()

    if patient_count > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot delete caregiver with {patient_count} assigned patient(s). Please reassign patients first.",
        )

    await caregiver.delete()
    return {"message": "Caregiver deleted successfully", "id": str(caregiver_id)}


@router.get("/patients", response_model=List[PatientAdminOut])
async def list_all_patients(_: User = Depends(require_admin)):
    """List all patients across all caregivers."""
    patients = await User.find(User.role == RoleEnum.patient).to_list()

    caregivers = await User.find(User.role == RoleEnum.caregiver).to_list()
    caregiver_lookup = {c.id: (c.name, c.email) for c in caregivers}

    results: List[PatientAdminOut] = []
    for p in patients:
        cg_name, cg_email = caregiver_lookup.get(p.caregiver_id, (None, None))
        results.append(
            PatientAdminOut(
                id=p.patient_code or str(p.id),
                uuid_id=p.id,
                patient_code=p.patient_code,
                name=p.name,
                age=p.age,
                gender=p.gender,
                diagnosis=p.diagnosis,
                status=p.status or "stable",
                status_label=p.status_label or "Active • Tablet synced",
                caregiver_id=p.caregiver_id,
                caregiver_name=cg_name,
                caregiver_email=cg_email,
                device_id=p.device_id,
                pairing_token=p.pairing_token,
                created_at=p.created_at,
            )
        )

    return results


@router.patch("/patients/{patient_id}/reassign", response_model=PatientAdminOut)
async def reassign_patient(
    patient_id: str,
    payload: PatientReassignRequest,
    _: User = Depends(require_admin),
):
    """Reassign a patient to a different caregiver."""
    patient = await _find_patient_by_identifier(patient_id)
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")

    new_caregiver = await User.find_one(
        User.id == payload.new_caregiver_id,
        User.role == RoleEnum.caregiver,
    )
    if not new_caregiver:
        raise HTTPException(status_code=404, detail="Target caregiver not found")

    if getattr(new_caregiver, "status", None) == "disabled":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot reassign patient to a disabled caregiver account",
        )

    patient.caregiver_id = new_caregiver.id
    await patient.save()

    # Update any device pairing token registered to this patient
    pairing_tokens = await DevicePairingToken.find(
        DevicePairingToken.patient_id == patient.id
    ).to_list()
    for tok in pairing_tokens:
        tok.caregiver_id = new_caregiver.id
        await tok.save()

    return PatientAdminOut(
        id=patient.patient_code or str(patient.id),
        uuid_id=patient.id,
        patient_code=patient.patient_code,
        name=patient.name,
        age=patient.age,
        gender=patient.gender,
        diagnosis=patient.diagnosis,
        status=patient.status or "stable",
        status_label=patient.status_label or "Active • Tablet synced",
        caregiver_id=patient.caregiver_id,
        caregiver_name=new_caregiver.name,
        caregiver_email=new_caregiver.email,
        device_id=patient.device_id,
        pairing_token=patient.pairing_token,
        created_at=patient.created_at,
    )
