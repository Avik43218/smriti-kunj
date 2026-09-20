"""Admin API routes for cross-caregiver and patient management."""
import secrets
import string
import uuid
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.dependencies import require_admin
from app.core.security import hash_password
from app.models.audit import AdminAuditLog
from app.models.user import DevicePairingToken, RoleEnum, User
from app.schemas.admin import (
    AdminAuditLogOut,
    CaregiverAdminOut,
    CaregiverAssignedSummary,
    CaregiverCreateAdminRequest,
    CaregiverResetPasswordRequest,
    CaregiverResetPasswordResponse,
    CaregiverUpdateAdminRequest,
    PatientAdminOut,
    PatientAssignCaregiversRequest,
    PatientReassignRequest,
)

router = APIRouter(prefix="/api/admin", tags=["admin"])


def _generate_temporary_password(length: int = 12) -> str:
    """Generate a high-entropy temporary password containing uppercase,
    lowercase, digits, and safe special symbols."""
    alphabet = string.ascii_letters + string.digits + "!@#$%&*"
    # Ensure at least one from each required class
    pwd = [
        secrets.choice(string.ascii_uppercase),
        secrets.choice(string.ascii_lowercase),
        secrets.choice(string.digits),
        secrets.choice("!@#$%&*"),
    ]
    pwd += [secrets.choice(alphabet) for _ in range(length - len(pwd))]
    secrets.SystemRandom().shuffle(pwd)
    return "".join(pwd)


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
    """List all caregivers with their patient counts and assigned patient IDs."""
    caregivers = await User.find(User.role == RoleEnum.caregiver).to_list()
    patients = await User.find(User.role == RoleEnum.patient).to_list()

    # Map caregiver ID -> list of patient codes/ids
    cg_patients: Dict[uuid.UUID, List[str]] = {c.id: [] for c in caregivers}
    for p in patients:
        assigned = set(p.assigned_caregiver_ids or [])
        if p.caregiver_id:
            assigned.add(p.caregiver_id)
        for cid in assigned:
            if cid in cg_patients:
                cg_patients[cid].append(p.patient_code or str(p.id))

    results: List[CaregiverAdminOut] = []
    for c in caregivers:
        p_list = cg_patients.get(c.id, [])
        results.append(
            CaregiverAdminOut(
                id=c.id,
                name=c.name,
                email=c.email,
                phone=getattr(c, "phone", None),
                region_language=c.region_language or "bn",
                role=c.role.value if hasattr(c.role, "value") else str(c.role),
                status=getattr(c, "status", "active") or "active",
                must_change_password=getattr(c, "must_change_password", False),
                patient_count=len(p_list),
                assigned_patient_ids=p_list,
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
    """Admin creates a caregiver account directly.
    Generates a secure temporary password if none is provided, flags account with
    must_change_password=True, and logs to the immutable audit trail."""
    if await User.find_one(User.email == payload.email):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with that email already exists",
        )

    temp_password = (payload.password or "").strip()
    if not temp_password:
        temp_password = _generate_temporary_password(12)

    caregiver = User(
        role=RoleEnum.caregiver,
        name=payload.name.strip(),
        email=payload.email,
        phone=payload.phone.strip() if payload.phone else None,
        hashed_password=hash_password(temp_password),
        region_language=payload.region_language or "bn",
        created_by=admin_user.id,
        status=payload.status or "active",
        must_change_password=True,
    )
    await caregiver.insert()

    # Assign initial patients if provided
    assigned_codes: List[str] = []
    if payload.assigned_patient_ids:
        for p_uuid in payload.assigned_patient_ids:
            p = await User.find_one(User.id == p_uuid, User.role == RoleEnum.patient)
            if p:
                curr_cgs = list(p.assigned_caregiver_ids or [])
                if caregiver.id not in curr_cgs:
                    curr_cgs.append(caregiver.id)
                    p.assigned_caregiver_ids = curr_cgs
                if not p.caregiver_id:
                    p.caregiver_id = caregiver.id
                await p.save()
                assigned_codes.append(p.patient_code or str(p.id))

    # Log audit event
    await AdminAuditLog(
        actor_id=admin_user.id,
        actor_name=admin_user.name,
        actor_email=admin_user.email,
        action="create_caregiver",
        target_type="caregiver",
        target_id=str(caregiver.id),
        target_name=caregiver.name,
        details={
            "email": caregiver.email,
            "phone": caregiver.phone,
            "status": caregiver.status,
            "assigned_patients": assigned_codes,
        },
    ).insert()

    return CaregiverAdminOut(
        id=caregiver.id,
        name=caregiver.name,
        email=caregiver.email,
        phone=caregiver.phone,
        region_language=caregiver.region_language or "bn",
        role=caregiver.role.value if hasattr(caregiver.role, "value") else str(caregiver.role),
        status=caregiver.status or "active",
        must_change_password=True,
        temporary_password=temp_password,
        patient_count=len(assigned_codes),
        assigned_patient_ids=assigned_codes,
        created_at=caregiver.created_at,
        created_by=str(caregiver.created_by) if caregiver.created_by else None,
    )


@router.patch("/caregivers/{caregiver_id}", response_model=CaregiverAdminOut)
async def update_caregiver(
    caregiver_id: uuid.UUID,
    payload: CaregiverUpdateAdminRequest,
    admin_user: User = Depends(require_admin),
):
    """Edit caregiver profile or enable/disable caregiver account."""
    caregiver = await User.find_one(User.id == caregiver_id, User.role == RoleEnum.caregiver)
    if not caregiver:
        raise HTTPException(status_code=404, detail="Caregiver not found")

    old_status = getattr(caregiver, "status", "active")
    changes: Dict[str, Any] = {}

    if payload.email and payload.email != caregiver.email:
        existing = await User.find_one(User.email == payload.email, User.id != caregiver.id)
        if existing:
            raise HTTPException(status_code=409, detail="Email is already in use by another user")
        changes["email"] = {"old": caregiver.email, "new": payload.email}
        caregiver.email = payload.email

    if payload.name is not None and payload.name.strip() != caregiver.name:
        changes["name"] = {"old": caregiver.name, "new": payload.name.strip()}
        caregiver.name = payload.name.strip()

    if payload.phone is not None and payload.phone.strip() != getattr(caregiver, "phone", None):
        changes["phone"] = {"old": getattr(caregiver, "phone", None), "new": payload.phone.strip()}
        caregiver.phone = payload.phone.strip()

    if payload.region_language is not None and payload.region_language != caregiver.region_language:
        changes["region_language"] = {"old": caregiver.region_language, "new": payload.region_language}
        caregiver.region_language = payload.region_language

    if payload.status is not None and payload.status != old_status:
        changes["status"] = {"old": old_status, "new": payload.status}
        caregiver.status = payload.status

    if changes:
        await caregiver.save()
        action_name = "update_caregiver"
        if "status" in changes:
            action_name = "deactivate_caregiver" if payload.status == "disabled" else "activate_caregiver"

        await AdminAuditLog(
            actor_id=admin_user.id,
            actor_name=admin_user.name,
            actor_email=admin_user.email,
            action=action_name,
            target_type="caregiver",
            target_id=str(caregiver.id),
            target_name=caregiver.name,
            details=changes,
        ).insert()

    # Calculate current assigned patients
    patients = await User.find(User.role == RoleEnum.patient).to_list()
    assigned_codes = [
        p.patient_code or str(p.id)
        for p in patients
        if caregiver.id in (p.assigned_caregiver_ids or []) or p.caregiver_id == caregiver.id
    ]

    return CaregiverAdminOut(
        id=caregiver.id,
        name=caregiver.name,
        email=caregiver.email,
        phone=getattr(caregiver, "phone", None),
        region_language=caregiver.region_language or "bn",
        role=caregiver.role.value if hasattr(caregiver.role, "value") else str(caregiver.role),
        status=caregiver.status or "active",
        must_change_password=getattr(caregiver, "must_change_password", False),
        patient_count=len(assigned_codes),
        assigned_patient_ids=assigned_codes,
        created_at=caregiver.created_at,
        created_by=str(caregiver.created_by) if caregiver.created_by else None,
    )


@router.post("/caregivers/{caregiver_id}/reset-password", response_model=CaregiverResetPasswordResponse)
async def reset_caregiver_password(
    caregiver_id: uuid.UUID,
    payload: Optional[CaregiverResetPasswordRequest] = None,
    admin_user: User = Depends(require_admin),
):
    """Admin resets a caregiver's password. Issues a temporary password and forces rotation on next login."""
    caregiver = await User.find_one(User.id == caregiver_id, User.role == RoleEnum.caregiver)
    if not caregiver:
        raise HTTPException(status_code=404, detail="Caregiver not found")

    new_pwd = payload.new_password.strip() if (payload and payload.new_password) else ""
    if not new_pwd:
        new_pwd = _generate_temporary_password(12)

    caregiver.hashed_password = hash_password(new_pwd)
    caregiver.must_change_password = True
    caregiver.token_version = (getattr(caregiver, "token_version", 1) or 1) + 1
    await caregiver.save()

    await AdminAuditLog(
        actor_id=admin_user.id,
        actor_name=admin_user.name,
        actor_email=admin_user.email,
        action="reset_password",
        target_type="caregiver",
        target_id=str(caregiver.id),
        target_name=caregiver.name,
        details={"email": caregiver.email},
    ).insert()

    return CaregiverResetPasswordResponse(
        temporary_password=new_pwd,
        message="Password reset successfully. Please share this temporary password with the caregiver.",
    )


@router.delete("/caregivers/{caregiver_id}")
async def delete_caregiver(
    caregiver_id: uuid.UUID,
    admin_user: User = Depends(require_admin),
):
    """Delete caregiver; blocks with error message if caregiver has assigned patients."""
    caregiver = await User.find_one(User.id == caregiver_id, User.role == RoleEnum.caregiver)
    if not caregiver:
        raise HTTPException(status_code=404, detail="Caregiver not found")

    patients = await User.find(User.role == RoleEnum.patient).to_list()
    assigned_count = sum(
        1 for p in patients if caregiver.id in (p.assigned_caregiver_ids or []) or p.caregiver_id == caregiver.id
    )

    if assigned_count > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot delete caregiver with {assigned_count} assigned patient(s). Please reassign patients first.",
        )

    cg_name = caregiver.name
    cg_email = caregiver.email
    await caregiver.delete()

    await AdminAuditLog(
        actor_id=admin_user.id,
        actor_name=admin_user.name,
        actor_email=admin_user.email,
        action="delete_caregiver",
        target_type="caregiver",
        target_id=str(caregiver_id),
        target_name=cg_name,
        details={"email": cg_email},
    ).insert()

    return {"message": "Caregiver deleted successfully", "id": str(caregiver_id)}


def _build_patient_admin_out(patient: User, caregiver_lookup: Dict[uuid.UUID, User]) -> PatientAdminOut:
    """Helper to assemble PatientAdminOut with populated assigned caregivers."""
    c_ids = list(patient.assigned_caregiver_ids or [])
    if patient.caregiver_id and patient.caregiver_id not in c_ids:
        c_ids.append(patient.caregiver_id)

    assigned_summaries: List[CaregiverAssignedSummary] = []
    primary_name = None
    primary_email = None

    for cid in c_ids:
        cg = caregiver_lookup.get(cid)
        if cg:
            assigned_summaries.append(CaregiverAssignedSummary(id=cg.id, name=cg.name, email=cg.email))
            if cid == patient.caregiver_id or not primary_name:
                primary_name = cg.name
                primary_email = cg.email

    val_weight = patient.body_weight or patient.weight
    return PatientAdminOut(
        id=patient.patient_code or str(patient.id),
        uuid_id=patient.id,
        patient_code=patient.patient_code,
        name=patient.name,
        age=patient.age,
        gender=patient.gender,
        diagnosis=patient.diagnosis,
        weight=val_weight,
        body_weight=val_weight,
        bodyWeight=val_weight,
        status=patient.status or "stable",
        status_label=patient.status_label or "Active • Device synced",
        caregiver_id=patient.caregiver_id,
        caregiver_name=primary_name,
        caregiver_email=primary_email,
        assigned_caregiver_ids=c_ids,
        assigned_caregivers=assigned_summaries,
        device_id=patient.device_id,
        pairing_token=patient.pairing_token,
        created_at=patient.created_at,
    )


@router.get("/patients", response_model=List[PatientAdminOut])
async def list_all_patients(_: User = Depends(require_admin)):
    """List all patients across all caregivers with their multi-caregiver assignments."""
    patients = await User.find(User.role == RoleEnum.patient).to_list()
    caregivers = await User.find(User.role == RoleEnum.caregiver).to_list()
    caregiver_lookup = {c.id: c for c in caregivers}

    return [_build_patient_admin_out(p, caregiver_lookup) for p in patients]


@router.put("/patients/{patient_id}/caregivers", response_model=PatientAdminOut)
async def assign_patient_caregivers(
    patient_id: str,
    payload: PatientAssignCaregiversRequest,
    admin_user: User = Depends(require_admin),
):
    """Assign one or more caregivers to a patient (many-to-many relationship)."""
    patient = await _find_patient_by_identifier(patient_id)
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")

    target_caregivers = await User.find(
        {"_id": {"$in": payload.caregiver_ids}, "role": RoleEnum.caregiver}
    ).to_list()

    if len(target_caregivers) != len(payload.caregiver_ids):
        raise HTTPException(status_code=400, detail="One or more caregiver IDs are invalid or not caregivers")

    for cg in target_caregivers:
        if getattr(cg, "status", None) == "disabled":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot assign patient to disabled caregiver {cg.name} ({cg.email})",
            )

    old_cg_ids = list(patient.assigned_caregiver_ids or [])
    patient.assigned_caregiver_ids = payload.caregiver_ids
    patient.caregiver_id = payload.caregiver_ids[0] if payload.caregiver_ids else None
    await patient.save()

    # Keep pairing token caregiver_id synced to the primary
    if patient.caregiver_id:
        pairing_tokens = await DevicePairingToken.find(
            DevicePairingToken.patient_id == patient.id
        ).to_list()
        for tok in pairing_tokens:
            tok.caregiver_id = patient.caregiver_id
            await tok.save()

    await AdminAuditLog(
        actor_id=admin_user.id,
        actor_name=admin_user.name,
        actor_email=admin_user.email,
        action="assign_caregivers",
        target_type="patient",
        target_id=str(patient.id),
        target_name=patient.name,
        details={
            "previous_caregivers": [str(cid) for cid in old_cg_ids],
            "assigned_caregivers": [str(cid) for cid in payload.caregiver_ids],
        },
    ).insert()

    caregivers = await User.find(User.role == RoleEnum.caregiver).to_list()
    caregiver_lookup = {c.id: c for c in caregivers}
    return _build_patient_admin_out(patient, caregiver_lookup)


@router.patch("/patients/{patient_id}/reassign", response_model=PatientAdminOut)
async def reassign_patient(
    patient_id: str,
    payload: PatientReassignRequest,
    admin_user: User = Depends(require_admin),
):
    """Legacy single caregiver reassign path."""
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

    old_cg = patient.caregiver_id
    patient.caregiver_id = new_caregiver.id
    curr = list(patient.assigned_caregiver_ids or [])
    if new_caregiver.id not in curr:
        curr.append(new_caregiver.id)
    patient.assigned_caregiver_ids = curr
    await patient.save()

    pairing_tokens = await DevicePairingToken.find(
        DevicePairingToken.patient_id == patient.id
    ).to_list()
    for tok in pairing_tokens:
        tok.caregiver_id = new_caregiver.id
        await tok.save()

    await AdminAuditLog(
        actor_id=admin_user.id,
        actor_name=admin_user.name,
        actor_email=admin_user.email,
        action="reassign_patient",
        target_type="patient",
        target_id=str(patient.id),
        target_name=patient.name,
        details={
            "from_caregiver": str(old_cg) if old_cg else None,
            "to_caregiver": str(new_caregiver.id),
        },
    ).insert()

    caregivers = await User.find(User.role == RoleEnum.caregiver).to_list()
    caregiver_lookup = {c.id: c for c in caregivers}
    return _build_patient_admin_out(patient, caregiver_lookup)


@router.get("/audit-logs", response_model=List[AdminAuditLogOut])
async def get_admin_audit_logs(
    limit: int = 100,
    _: User = Depends(require_admin),
):
    """Retrieve immutable audit trail of administrative actions."""
    logs = await AdminAuditLog.find().sort("-timestamp").limit(limit).to_list()
    return [
        AdminAuditLogOut(
            id=str(log.id),
            actor_id=log.actor_id,
            actor_name=log.actor_name,
            actor_email=log.actor_email,
            action=log.action,
            target_type=log.target_type,
            target_id=log.target_id,
            target_name=log.target_name,
            details=log.details,
            timestamp=log.timestamp,
        )
        for log in logs
    ]
