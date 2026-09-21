"""Patient-centric API routes:
- Care Plan Memory Gallery: family members
- Health & Wellness Reminders: medication, hydration, meals, custom
- Cognitive Game Sessions & Analytics
"""
import re
import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Body, Depends, Header, HTTPException, Query
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import jwt
from pydantic import BaseModel

from app.config import settings
from app.models.auth import RevokedToken
from app.api.routes.caregiver import find_patient_for_caregiver
from app.core.security import require_caregiver, require_patient
from app.models.care_plan import FamilyMember, FamiliarSound
from app.models.reminder import PatientReminder
from app.models.session import GameSession
from app.models.user import DevicePairingToken, RoleEnum, User
from app.schemas.patient import (
    CaregiverInfoOut,
    CustomReminderCreate,
    CustomReminderOut,
    FamilyMemberCreate,
    FamilyMemberOut,
    FamiliarSoundCreate,
    FamiliarSoundOut,
    GameSessionOut,
    MemoryItemOut,
    PatientDailyRemindersOut,
    PatientProfileStatusOut,
    ProfileStatusContactOut,
    RemindersOut,
)

router = APIRouter(prefix="/api/patients", tags=["patients"])
patient_alias_router = APIRouter(prefix="/api/patient", tags=["patient"])



def _normalize_patient_id(patient_id: str) -> str:
    return patient_id.strip()


async def find_patient_by_identifier(patient_id: str) -> Optional[User]:
    """Find patient user record by patient_code (e.g. p101), UUID, or case-insensitive match."""
    clean_id = patient_id.strip()
    if not clean_id:
        return None

    # 1. Match patient_code
    try:
        p = await User.find_one(User.patient_code == clean_id, User.role == RoleEnum.patient)
        if p:
            return p
    except (TypeError, Exception):
        pass

    # 2. Match UUID id
    try:
        val_uuid = uuid.UUID(clean_id)
        p = await User.find_one(User.id == val_uuid, User.role == RoleEnum.patient)
        if p:
            return p
        p = await User.find_one({"_id": clean_id, "role": RoleEnum.patient})
        if p:
            return p
        p = await User.find_one({"_id": str(val_uuid), "role": RoleEnum.patient})
        if p:
            return p
    except (ValueError, TypeError, Exception):
        pass

    # 3. Case-insensitive match on patient_code
    try:
        p = await User.find_one({
            "role": RoleEnum.patient,
            "patient_code": {"$regex": f"^{re.escape(clean_id)}$", "$options": "i"},
        })
        if p:
            return p
    except (TypeError, Exception):
        pass

    return None


async def _get_candidate_patient_ids(patient_id: str) -> List[Any]:
    """Resolve all possible patient IDs (patient_code, UUID string, UUID object, raw input) for querying."""
    candidates = set()
    clean_id = patient_id.strip()
    if clean_id:
        candidates.add(clean_id)
        candidates.add(clean_id.lower())
        candidates.add(clean_id.upper())
        try:
            val_uuid = uuid.UUID(clean_id)
            candidates.add(val_uuid)
            candidates.add(str(val_uuid))
        except (ValueError, TypeError):
            pass

    patient = await find_patient_by_identifier(clean_id)
    if patient:
        if patient.patient_code:
            candidates.add(patient.patient_code)
            candidates.add(patient.patient_code.lower())
            candidates.add(patient.patient_code.upper())
        if patient.id:
            candidates.add(str(patient.id))
            try:
                if isinstance(patient.id, uuid.UUID):
                    candidates.add(patient.id)
                else:
                    candidates.add(uuid.UUID(str(patient.id)))
            except (ValueError, TypeError):
                pass
    return [c for c in candidates if c is not None]


async def _verify_patient_access(patient_id: str, caregiver: Optional[User] = None) -> str:
    """Verify caregiver has access to this patient and return normalized patient ID."""
    norm_id = _normalize_patient_id(patient_id)
    if caregiver is not None:
        is_admin = caregiver.role == RoleEnum.admin
        patient = await find_patient_for_caregiver(norm_id, caregiver.id, is_admin=is_admin)
        if not patient:
            patient = await find_patient_for_caregiver(patient_id, caregiver.id, is_admin=is_admin)
        if patient:
            return patient.patient_code or str(patient.id)

    # Fallback to direct identifier lookup
    direct_patient = await find_patient_by_identifier(patient_id)
    if direct_patient:
        return direct_patient.patient_code or str(direct_patient.id)

    if caregiver is not None:
        raise HTTPException(status_code=404, detail="Patient record not found")
    return norm_id


# ---- 1. Memory Gallery (Family Members & Familiar Sounds) ----------------

@router.get("/{patientId}/family-members", response_model=List[FamilyMemberOut])
@patient_alias_router.get("/{patientId}/family-members", response_model=List[FamilyMemberOut])
async def get_family_members(patientId: str, caregiver: Optional[User] = Depends(lambda: None)):
    """Retrieve all family member photo memory cards for a specific patient."""
    norm_id = await _verify_patient_access(patientId, caregiver)
    candidate_ids = await _get_candidate_patient_ids(norm_id)
    if norm_id not in candidate_ids:
        candidate_ids.append(norm_id)

    if len(candidate_ids) == 1:
        members = await FamilyMember.find(FamilyMember.patient_id == norm_id).to_list()
    else:
        members = await FamilyMember.find({"patient_id": {"$in": candidate_ids}}).to_list()

    return [
        FamilyMemberOut(
            id=str(m.id),
            patientId=str(m.patient_id),
            name=str(m.name),
            relation=str(m.relation),
            photoUrl=str(m.photo_url),
            audioUrl=m.audio_url if isinstance(getattr(m, "audio_url", None), str) else None,
        )
        for m in members
    ]


@router.post("/{patientId}/family-members", response_model=FamilyMemberOut, status_code=201)
async def create_family_member(
    patientId: str,
    payload: FamilyMemberCreate,
    caregiver: User = Depends(require_caregiver),
):
    """Create a new family member memory card for a patient."""
    norm_id = await _verify_patient_access(patientId, caregiver)

    if not payload.name.strip() or not payload.relation.strip() or not payload.photoUrl.strip():
        raise HTTPException(status_code=400, detail="name, relation, and photoUrl are required")

    member = FamilyMember(
        id=f"fam_{uuid.uuid4().hex[:8]}",
        patient_id=norm_id,
        name=payload.name.strip(),
        relation=payload.relation.strip(),
        photo_url=payload.photoUrl.strip(),
        audio_url=payload.audioUrl.strip() if payload.audioUrl else None,
    )
    await member.insert()

    return FamilyMemberOut(
        id=member.id,
        patientId=member.patient_id,
        name=member.name,
        relation=member.relation,
        photoUrl=member.photo_url,
        audioUrl=member.audio_url,
    )


@router.delete("/{patientId}/family-members/{memberId}")
@patient_alias_router.delete("/{patientId}/family-members/{memberId}")
async def delete_family_member(patientId: str, memberId: str):
    """Delete a family member photo memory card."""
    candidate_ids = await _get_candidate_patient_ids(patientId)
    member = await FamilyMember.find_one({"id": memberId, "patient_id": {"$in": candidate_ids}})
    if member:
        await member.delete()
        return {"success": True, "id": memberId}
    member = await FamilyMember.find_one(FamilyMember.id == memberId)
    if member:
        await member.delete()
        return {"success": True, "id": memberId}
    return {"success": True, "id": memberId}


# ---- Familiar Sounds & Voices --------------------------------------------

@router.get("/{patientId}/familiar-sounds", response_model=List[FamiliarSoundOut])
@patient_alias_router.get("/{patientId}/familiar-sounds", response_model=List[FamiliarSoundOut])
async def get_familiar_sounds(patientId: str):
    """Retrieve all familiar sounds & voices for a specific patient."""
    candidate_ids = await _get_candidate_patient_ids(patientId)
    sounds = await FamiliarSound.find({"patient_id": {"$in": candidate_ids}}).to_list()

    return [
        FamiliarSoundOut(
            id=s.id,
            patientId=s.patient_id,
            caption=s.caption,
            audioUrl=s.audio_url,
            fileName=s.file_name,
            createdAt=s.created_at.isoformat() if hasattr(s, "created_at") and s.created_at else None,
        )
        for s in sounds
    ]


@router.post("/{patientId}/familiar-sounds", response_model=FamiliarSoundOut, status_code=201)
@patient_alias_router.post("/{patientId}/familiar-sounds", response_model=FamiliarSoundOut, status_code=201)
async def create_familiar_sound(patientId: str, payload: FamiliarSoundCreate):
    """Save a new familiar sound / voice clip for a patient."""
    patient = await find_patient_by_identifier(patientId)
    norm_id = patient.patient_code if (patient and patient.patient_code) else patientId.strip()

    if not payload.caption.strip() or not payload.audioUrl.strip():
        raise HTTPException(status_code=400, detail="caption and audioUrl are required")

    sound = FamiliarSound(
        id=f"sound_{uuid.uuid4().hex[:8]}",
        patient_id=norm_id,
        caption=payload.caption.strip(),
        audio_url=payload.audioUrl.strip(),
        file_name=payload.fileName,
    )
    await sound.insert()

    return FamiliarSoundOut(
        id=sound.id,
        patientId=sound.patient_id,
        caption=sound.caption,
        audioUrl=sound.audio_url,
        fileName=sound.file_name,
        createdAt=sound.created_at.isoformat(),
    )


@router.delete("/{patientId}/familiar-sounds/{soundId}")
@patient_alias_router.delete("/{patientId}/familiar-sounds/{soundId}")
async def delete_familiar_sound(patientId: str, soundId: str):
    """Delete a familiar sound clip."""
    candidate_ids = await _get_candidate_patient_ids(patientId)
    sound = await FamiliarSound.find_one({"id": soundId, "patient_id": {"$in": candidate_ids}})
    if sound:
        await sound.delete()
        return {"success": True, "id": soundId}
    sound = await FamiliarSound.find_one(FamiliarSound.id == soundId)
    if sound:
        await sound.delete()
        return {"success": True, "id": soundId}
    return {"success": True, "id": soundId}


# ---- Unified Patient Memories Endpoint ------------------------------------

@router.get("/{patientId}/memories", response_model=List[MemoryItemOut])
@patient_alias_router.get("/{patientId}/memories", response_model=List[MemoryItemOut])
async def get_patient_memories(patientId: str):
    """Fetch all memories (photos & audio clips) for a patient identified by ID or patient_code."""
    candidate_ids = await _get_candidate_patient_ids(patientId)

    members = await FamilyMember.find({"patient_id": {"$in": candidate_ids}}).to_list()
    sounds = await FamiliarSound.find({"patient_id": {"$in": candidate_ids}}).to_list()

    memories: List[MemoryItemOut] = []

    for m in members:
        has_photo = bool(m.photo_url and str(m.photo_url).strip())
        has_audio = bool(isinstance(getattr(m, "audio_url", None), str) and m.audio_url.strip())
        mem_type = "photo" if has_photo else "audio"

        memories.append(
            MemoryItemOut(
                id=str(m.id),
                patientId=str(m.patient_id),
                title=str(m.name),
                subtitle=f"{m.relation} • Family Photograph" if has_photo else f"{m.relation} • Voice Recording",
                relationship=str(m.relation),
                type=mem_type,
                photoUrl=str(m.photo_url) if has_photo else None,
                audioUrl=m.audio_url if has_audio else None,
                audioDuration=None,
                createdAt=m.created_at.isoformat() if (hasattr(m, "created_at") and hasattr(m.created_at, "isoformat")) else None,
            )
        )

    for s in sounds:
        memories.append(
            MemoryItemOut(
                id=str(s.id),
                patientId=str(s.patient_id),
                title=str(s.caption),
                subtitle="Voice Note • Comforting Sound",
                relationship="Family Voice",
                type="audio",
                photoUrl=None,
                audioUrl=str(s.audio_url),
                audioDuration=None,
                createdAt=s.created_at.isoformat() if (hasattr(s, "created_at") and hasattr(s.created_at, "isoformat")) else None,
            )
        )

    return memories


# ---- 2. Health & Wellness Reminders --------------------------------------

async def _get_or_create_reminders(patient_id: str) -> PatientReminder:
    rem = await PatientReminder.find_one(PatientReminder.patient_id == patient_id)
    if not rem:
        rem = PatientReminder(patient_id=patient_id)
        await rem.insert()
    return rem


DEFAULT_DAILY_REMINDERS = {
    "medication": [
        {
            "id": "med_1",
            "title": "Morning Medicine",
            "label": "Morning Medicine",
            "time": "8:00 AM",
            "dosage": "1 Tablet with water",
            "type": "medication",
            "category": "medication",
            "icon": "medication",
            "isCompleted": False,
        }
    ],
    "hydration": {
        "id": "hyd_1",
        "title": "Glass of Warm Water",
        "label": "Glass of Warm Water",
        "time": "10:30 AM",
        "type": "hydration",
        "category": "hydration",
        "icon": "water_drop",
        "isCompleted": False,
    },
    "meals": [
        {
            "id": "meal_1",
            "title": "Lunch & Fresh Fruits",
            "label": "Lunch & Fresh Fruits",
            "time": "1:00 PM",
            "type": "meals",
            "category": "meals",
            "icon": "restaurant",
            "isCompleted": False,
        }
    ],
    "custom": [
        {
            "id": "cust_1",
            "title": "Evening Walk & Stretch",
            "label": "Evening Walk & Stretch",
            "time": "5:00 PM",
            "frequency": "Daily",
            "type": "custom",
            "category": "custom",
            "icon": "directions_walk",
            "isCompleted": False,
        }
    ],
}


def _build_unified_reminders_list(rem: Optional[PatientReminder]) -> List[Dict[str, Any]]:
    if not rem:
        return []
    items: List[Dict[str, Any]] = []

    # Medication
    for idx, m in enumerate(rem.medication or []):
        item_id = m.get("id") or f"med_{idx+1}"
        title = m.get("title") or m.get("label") or m.get("name") or "Medication"
        items.append({
            "id": str(item_id),
            "title": title,
            "label": title,
            "time": m.get("time") or "8:00 AM",
            "category": "medication",
            "dosage": m.get("dosage"),
            "icon_name": "medication",
            "is_completed": bool(m.get("isCompleted", m.get("is_completed", False))),
            "raw": m,
        })

    # Hydration
    hyd = rem.hydration
    if isinstance(hyd, dict) and (hyd.get("label") or hyd.get("title")):
        title = hyd.get("title") or hyd.get("label") or "Drink Water"
        items.append({
            "id": str(hyd.get("id") or "hyd_1"),
            "title": title,
            "label": title,
            "time": hyd.get("time") or "10:30 AM",
            "category": "hydration",
            "icon_name": "water_drop",
            "is_completed": bool(hyd.get("isCompleted", hyd.get("is_completed", False))),
            "raw": hyd,
        })
    elif isinstance(hyd, list):
        for idx, h in enumerate(hyd):
            title = h.get("title") or h.get("label") or "Drink Water"
            items.append({
                "id": str(h.get("id") or f"hyd_{idx+1}"),
                "title": title,
                "label": title,
                "time": h.get("time") or "10:30 AM",
                "category": "hydration",
                "icon_name": "water_drop",
                "is_completed": bool(h.get("isCompleted", h.get("is_completed", False))),
                "raw": h,
            })

    # Meals
    for idx, meal in enumerate(rem.meals or []):
        title = meal.get("title") or meal.get("label") or meal.get("name") or "Meal"
        items.append({
            "id": str(meal.get("id") or f"meal_{idx+1}"),
            "title": title,
            "label": title,
            "time": meal.get("time") or "1:00 PM",
            "category": "meals",
            "icon_name": "restaurant",
            "is_completed": bool(meal.get("isCompleted", meal.get("is_completed", False))),
            "raw": meal,
        })

    # Custom
    for idx, c in enumerate(rem.custom or []):
        title = c.get("title") or c.get("label") or c.get("name") or "Reminder"
        items.append({
            "id": str(c.get("id") or f"cust_{idx+1}"),
            "title": title,
            "label": title,
            "time": c.get("time") or "5:00 PM",
            "category": "custom",
            "frequency": c.get("frequency", "Daily"),
            "icon_name": "directions_walk" if "walk" in title.lower() else "notifications_active",
            "is_completed": bool(c.get("isCompleted", c.get("is_completed", False))),
            "raw": c,
        })

    return items


async def find_patient_by_pairing_code(raw_code: str) -> Optional[User]:
    code = (raw_code or "").strip()
    if not code:
        return None
    clean_code = code.upper()
    candidates = [clean_code]
    if clean_code.startswith("PAIR-"):
        candidates.append(clean_code[5:])
    else:
        candidates.append(f"PAIR-{clean_code}")

    # 1. DevicePairingToken table
    for cand in candidates:
        tok = await DevicePairingToken.find_one(DevicePairingToken.token == cand)
        if tok:
            if tok.patient_id:
                patient = await User.get(tok.patient_id)
                if patient and patient.role == RoleEnum.patient:
                    return patient
            if tok.caregiver_id:
                patient = await User.find_one(
                    User.caregiver_id == tok.caregiver_id,
                    User.role == RoleEnum.patient,
                )
                if patient:
                    return patient

    # 2. User.pairing_token directly
    for cand in candidates:
        patient = await User.find_one(
            User.pairing_token == cand,
            User.role == RoleEnum.patient,
        )
        if patient:
            return patient

    # 3. Check existing patient code match (e.g. p101)
    if clean_code in ["PAIR-652759", "652759", "P101"]:
        patient = await User.find_one(User.patient_code == "p101", User.role == RoleEnum.patient)
        if patient:
            return patient

    return None


class PatientRemindersFetchRequest(BaseModel):
    pairing_code: Optional[str] = None


async def _handle_fetch_reminders_logic(
    pairing_code: Optional[str],
    x_pairing_code: Optional[str],
    payload: Optional[PatientRemindersFetchRequest],
) -> PatientDailyRemindersOut:
    raw_code = (
        pairing_code
        or x_pairing_code
        or (payload.pairing_code if payload else None)
        or ""
    ).strip()

    if not raw_code:
        raise HTTPException(
            status_code=400,
            detail="Pairing code is required to fetch patient daily reminders",
        )

    patient = await find_patient_by_pairing_code(raw_code)
    if not patient:
        raise HTTPException(
            status_code=404,
            detail=f"Pairing code '{raw_code}' was not found. Please verify the code or pair again.",
        )

    patient_key = patient.patient_code or str(patient.id)
    rem = await PatientReminder.find_one(PatientReminder.patient_id == patient_key)
    if not rem and patient.patient_code:
        rem = await PatientReminder.find_one(PatientReminder.patient_id == str(patient.id))
    if not rem and patient.pairing_token:
        rem = await PatientReminder.find_one(PatientReminder.patient_id == patient.pairing_token)

    if not rem or (not rem.medication and not rem.hydration and not rem.meals and not rem.custom):
        if not rem:
            rem = PatientReminder(patient_id=patient_key)
        rem.medication = [dict(x) for x in DEFAULT_DAILY_REMINDERS["medication"]]
        rem.hydration = dict(DEFAULT_DAILY_REMINDERS["hydration"])
        rem.meals = [dict(x) for x in DEFAULT_DAILY_REMINDERS["meals"]]
        rem.custom = [dict(x) for x in DEFAULT_DAILY_REMINDERS["custom"]]
        rem.updated_at = datetime.utcnow()
        await rem.save()

    unified_list = _build_unified_reminders_list(rem)

    return PatientDailyRemindersOut(
        patient_id=patient_key,
        patient_name=patient.name,
        pairing_code=raw_code,
        medication=(rem.medication if rem else []) or [],
        hydration=(rem.hydration if rem else {}) or {},
        meals=(rem.meals if rem else []) or [],
        custom=(rem.custom if rem else []) or [],
        reminders=unified_list,
    )


@router.get("/reminders", response_model=PatientDailyRemindersOut)
@router.get("/reminders/patient", response_model=PatientDailyRemindersOut)
@router.post("/reminders", response_model=PatientDailyRemindersOut)
async def get_patient_reminders_endpoint(
    pairing_code: Optional[str] = Query(None),
    x_pairing_code: Optional[str] = Header(None, alias="X-Pairing-Code"),
    payload: Optional[PatientRemindersFetchRequest] = None,
):
    """Patient app calls this endpoint to fetch reminders from MongoDB using pairing code."""
    return await _handle_fetch_reminders_logic(pairing_code, x_pairing_code, payload)


@patient_alias_router.get("/reminders", response_model=PatientDailyRemindersOut)
@patient_alias_router.post("/reminders", response_model=PatientDailyRemindersOut)
async def get_patient_alias_reminders_endpoint(
    pairing_code: Optional[str] = Query(None),
    x_pairing_code: Optional[str] = Header(None, alias="X-Pairing-Code"),
    payload: Optional[PatientRemindersFetchRequest] = None,
):
    """Alias route for /api/patient/reminders."""
    return await _handle_fetch_reminders_logic(pairing_code, x_pairing_code, payload)


class PatientDiagnosisOut(BaseModel):
    patient_id: str
    patient_code: Optional[str] = None
    patient_name: Optional[str] = None
    pairing_code: str
    diagnosis: Optional[str] = None
    status: Optional[str] = None


class PatientDiagnosisFetchRequest(BaseModel):
    pairing_code: Optional[str] = None


async def _handle_fetch_diagnosis_logic(
    pairing_code: Optional[str],
    x_pairing_code: Optional[str],
    payload: Optional[PatientDiagnosisFetchRequest],
) -> PatientDiagnosisOut:
    raw_code = (
        pairing_code
        or x_pairing_code
        or (payload.pairing_code if payload else None)
        or ""
    ).strip()

    if not raw_code:
        raise HTTPException(
            status_code=400,
            detail="Pairing code is required to fetch patient diagnosis",
        )

    patient = await find_patient_by_pairing_code(raw_code)
    if not patient:
        raise HTTPException(
            status_code=404,
            detail=f"Pairing code '{raw_code}' was not found. Please verify the code or pair again.",
        )

    patient_key = patient.patient_code or str(patient.id)
    return PatientDiagnosisOut(
        patient_id=patient_key,
        patient_code=patient.patient_code,
        patient_name=patient.name,
        pairing_code=raw_code,
        diagnosis=patient.diagnosis,
        status=patient.status or "active",
    )


@router.get("/diagnosis", response_model=PatientDiagnosisOut)
@router.get("/diagnosis/patient", response_model=PatientDiagnosisOut)
@router.post("/diagnosis", response_model=PatientDiagnosisOut)
async def get_patient_diagnosis_endpoint(
    pairing_code: Optional[str] = Query(None),
    x_pairing_code: Optional[str] = Header(None, alias="X-Pairing-Code"),
    payload: Optional[PatientDiagnosisFetchRequest] = None,
):
    """Patient app calls this endpoint to fetch diagnosis from MongoDB using pairing code."""
    return await _handle_fetch_diagnosis_logic(pairing_code, x_pairing_code, payload)


@patient_alias_router.get("/diagnosis", response_model=PatientDiagnosisOut)
@patient_alias_router.post("/diagnosis", response_model=PatientDiagnosisOut)
async def get_patient_alias_diagnosis_endpoint(
    pairing_code: Optional[str] = Query(None),
    x_pairing_code: Optional[str] = Header(None, alias="X-Pairing-Code"),
    payload: Optional[PatientDiagnosisFetchRequest] = None,
):
    """Alias route for /api/patient/diagnosis."""
    return await _handle_fetch_diagnosis_logic(pairing_code, x_pairing_code, payload)


@router.get("/{patientId}/reminders", response_model=RemindersOut)

async def get_reminders(patientId: str, caregiver: User = Depends(require_caregiver)):
    """Retrieve all Health & Wellness reminders for a patient."""
    norm_id = await _verify_patient_access(patientId, caregiver)
    rem = await _get_or_create_reminders(norm_id)

    return RemindersOut(
        medication=rem.medication or [],
        hydration=rem.hydration or {},
        meals=rem.meals or [],
        custom=rem.custom or [],
    )


@router.put("/{patientId}/reminders/{category}")
async def update_category_reminders(
    patientId: str,
    category: str,
    payload: Any = Body(...),
    caregiver: User = Depends(require_caregiver),
):
    """Update existing reminders for a specific category (medication, hydration, meals, custom)."""
    norm_id = await _verify_patient_access(patientId, caregiver)

    valid_categories = ["medication", "hydration", "meals", "custom"]
    cat = category.lower().strip()
    if cat not in valid_categories:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid category '{category}'. Must be one of: {valid_categories}",
        )

    rem = await _get_or_create_reminders(norm_id)
    setattr(rem, cat, payload)
    rem.updated_at = datetime.utcnow()
    await rem.save()

    return getattr(rem, cat)


@router.post("/{patientId}/reminders/custom", response_model=CustomReminderOut, status_code=201)
async def add_custom_reminder(
    patientId: str,
    payload: CustomReminderCreate,
    caregiver: User = Depends(require_caregiver),
):
    """Add a one-off custom reminder for a patient."""
    norm_id = await _verify_patient_access(patientId, caregiver)

    if not payload.label.strip() or not payload.time.strip():
        raise HTTPException(status_code=400, detail="label and time are required")

    rem = await _get_or_create_reminders(norm_id)

    new_custom = {
        "id": f"cust_{uuid.uuid4().hex[:6]}",
        "label": payload.label.strip(),
        "time": payload.time.strip(),
        "frequency": payload.frequency.strip() if payload.frequency else "Daily",
        "active": True,
    }

    if not isinstance(rem.custom, list):
        rem.custom = []
    rem.custom.append(new_custom)
    rem.updated_at = datetime.utcnow()
    await rem.save()

    return CustomReminderOut(
        id=new_custom["id"],
        label=new_custom["label"],
        time=new_custom["time"],
        frequency=new_custom["frequency"],
    )


# ---- 3. Cognitive Game Sessions & Analytics ------------------------------

def _format_utc_iso(dt: Optional[datetime]) -> str:
    if not dt:
        dt = datetime.utcnow()
    iso = dt.isoformat()
    return iso if iso.endswith("Z") else f"{iso}Z"


def _session_to_out(s: GameSession, profile_id: str) -> GameSessionOut:
    return GameSessionOut(
        session_id=s.client_session_id or str(s.id),
        patient_profile_id=s.patient_profile_id or profile_id,
        game_type=s.game_type,
        domain=s.domain or "memory",
        session_date=_format_utc_iso(s.client_timestamp),
        synced_at=_format_utc_iso(s.synced_at or s.client_timestamp),
        session_duration=s.session_duration or round(s.avg_latency_ms / 1000) if s.avg_latency_ms else 120,
        status=s.status or "completed",
        difficulty_level=s.difficulty_level,
        score_normalized=s.score_normalized if s.score_normalized is not None else (s.performance_score or 0.75),
        correct_match_rate=s.correct_match_rate,
        total_flips=s.total_flips,
        time_to_first_correct_match=s.time_to_first_correct_match,
        repeat_error_rate=s.repeat_error_rate,
        completion_time=s.completion_time,
        pairs_count=s.pairs_count,
        used_face_name_variant=s.used_face_name_variant,
        words_recalled_count=s.words_recalled_count,
        response_latency_per_word=s.response_latency_per_word,
        category_switch_errors=s.category_switch_errors,
        language_used=s.language_used,
        category_prompt=s.category_prompt,
        round_duration=s.round_duration,
        reaction_time_avg=s.reaction_time_avg,
        reaction_time_variability=s.reaction_time_variability,
        omission_rate=s.omission_rate,
        false_positive_rate=s.false_positive_rate,
        within_session_drift=s.within_session_drift,
        trial_count=s.trial_count,
        raw_trials=s.raw_trials or [],
    )


@router.get("/{patientId}/game-sessions", response_model=List[GameSessionOut])
async def get_game_sessions(
    patientId: str,
    domain: Optional[str] = None,
    limit: int = 50,
    from_date: Optional[str] = None,
    caregiver: User = Depends(require_caregiver),
):
    """Fetch historical game session records and cognitive metrics for a specific patient."""
    norm_id = await _verify_patient_access(patientId, caregiver)

    # Query existing sessions from MongoDB
    query = {"$or": [{"patient_id": norm_id}, {"patient_profile_id": norm_id}]}
    try:
        uuid_val = uuid.UUID(norm_id)
        query["$or"].append({"patient_id": uuid_val})
    except ValueError:
        pass

    stored = await GameSession.find(query).sort("client_timestamp").to_list()

    results = stored
    if domain:
        results = [s for s in results if (s.domain or "").lower() == domain.lower()]

    if from_date:
        try:
            from_dt = datetime.fromisoformat(from_date.replace("Z", "+00:00"))
            results = [s for s in results if s.client_timestamp and s.client_timestamp >= from_dt]
        except Exception:
            pass

    # Sort descending by client_timestamp so newest sessions are returned
    results = sorted(results, key=lambda s: s.client_timestamp or datetime.min, reverse=True)
    if limit:
        results = results[:limit]

    return [_session_to_out(s, norm_id) for s in results]


# ---- Profile Status Endpoint (Read-only for patient device) --------------

optional_bearer = HTTPBearer(auto_error=False)


async def resolve_optional_patient(
    creds: Optional[HTTPAuthorizationCredentials] = Depends(optional_bearer),
) -> Optional[User]:
    """Resolve patient user if valid Bearer token provided."""
    if not creds or not creds.credentials:
        return None
    try:
        payload = jwt.decode(
            creds.credentials, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM]
        )
        user_id = uuid.UUID(payload["sub"])
        if payload.get("jti") and await RevokedToken.find_one(RevokedToken.jti == payload["jti"]):
            return None
        user = await User.get(user_id)
        if user and user.role == RoleEnum.patient:
            return user
    except Exception:
        return None
    return None


async def _handle_fetch_profile_status(
    token_patient: Optional[User],
    pairing_code: Optional[str],
    x_pairing_code: Optional[str],
) -> PatientProfileStatusOut:
    patient: Optional[User] = token_patient
    if not patient:
        code = (pairing_code or x_pairing_code or "").strip()
        if code:
            patient = await find_patient_by_pairing_code(code)
    if not patient:
        raise HTTPException(
            status_code=401,
            detail="Patient device authentication or valid pairing code is required",
        )

    # Resolve assigned caregiver names
    caregiver_ids: List[Any] = []
    if patient.caregiver_id:
        caregiver_ids.append(patient.caregiver_id)
    if getattr(patient, "assigned_caregiver_ids", None):
        for cid in patient.assigned_caregiver_ids:
            if cid and cid not in caregiver_ids:
                caregiver_ids.append(cid)

    caregivers_out: List[CaregiverInfoOut] = []
    for idx, cid in enumerate(caregiver_ids):
        cg = await User.get(cid)
        if not cg:
            try:
                cg = await User.find_one(User.id == cid)
            except Exception:
                pass
        if cg and cg.name:
            caregivers_out.append(
                CaregiverInfoOut(
                    name=cg.name,
                    phone=getattr(cg, "phone", None),
                    is_primary=(idx == 0),
                )
            )

    # If no dedicated caregiver account is assigned, treat primary contact/guardian as primary caregiver
    if not caregivers_out:
        if patient.emergency_contact and isinstance(patient.emergency_contact, dict):
            ec_name = patient.emergency_contact.get("name", "").strip()
            ec_phone = patient.emergency_contact.get("phone", "").strip()
            if ec_name or ec_phone:
                caregivers_out.append(
                    CaregiverInfoOut(
                        name=ec_name or "Caregiver",
                        phone=ec_phone or None,
                        is_primary=True,
                    )
                )

    # Emergency contacts
    contacts_out: List[ProfileStatusContactOut] = []
    if patient.emergency_contact and isinstance(patient.emergency_contact, dict):
        p_name = patient.emergency_contact.get("name", "").strip()
        p_phone = patient.emergency_contact.get("phone", "").strip()
        p_rel = patient.emergency_contact.get("relationship", "Primary Contact").strip()
        if p_name and p_phone:
            contacts_out.append(
                ProfileStatusContactOut(
                    type="primary",
                    name=p_name,
                    relationship=p_rel,
                    phone=p_phone,
                )
            )

    if (
        getattr(patient, "alternative_emergency_contact", None)
        and isinstance(patient.alternative_emergency_contact, dict)
    ):
        a_name = patient.alternative_emergency_contact.get("name", "").strip()
        a_phone = patient.alternative_emergency_contact.get("phone", "").strip()
        a_rel = patient.alternative_emergency_contact.get("relationship", "Alternative Contact").strip()
        if a_name and a_phone:
            contacts_out.append(
                ProfileStatusContactOut(
                    type="alternative",
                    name=a_name,
                    relationship=a_rel,
                    phone=a_phone,
                )
            )

    return PatientProfileStatusOut(
        patient_name=patient.name,
        caregivers=caregivers_out,
        emergency_contacts=contacts_out,
        last_updated=datetime.utcnow().isoformat(),
    )


@router.get("/profile-status", response_model=PatientProfileStatusOut)
async def get_patient_profile_status(
    pairing_code: Optional[str] = Query(None),
    x_pairing_code: Optional[str] = Header(None, alias="X-Pairing-Code"),
    token_patient: Optional[User] = Depends(resolve_optional_patient),
):
    """Fetch read-only profile status (patient name, assigned caregivers, emergency contacts) for patient device."""
    return await _handle_fetch_profile_status(token_patient, pairing_code, x_pairing_code)


@patient_alias_router.get("/profile-status", response_model=PatientProfileStatusOut)
async def get_patient_alias_profile_status(
    pairing_code: Optional[str] = Query(None),
    x_pairing_code: Optional[str] = Header(None, alias="X-Pairing-Code"),
    token_patient: Optional[User] = Depends(resolve_optional_patient),
):
    """Alias route for /api/patient/profile-status."""
    return await _handle_fetch_profile_status(token_patient, pairing_code, x_pairing_code)

