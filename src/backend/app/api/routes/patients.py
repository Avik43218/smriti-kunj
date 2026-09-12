"""Patient-centric API routes:
- Care Plan Memory Gallery: family members
- Health & Wellness Reminders: medication, hydration, meals, custom
- Cognitive Game Sessions & Analytics
"""
import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Body, Depends, Header, HTTPException, Query
from pydantic import BaseModel

from app.api.routes.caregiver import find_patient_for_caregiver
from app.core.security import require_caregiver
from app.models.care_plan import FamilyMember
from app.models.reminder import PatientReminder
from app.models.session import GameSession
from app.models.user import DevicePairingToken, RoleEnum, User
from app.schemas.patient import (
    CustomReminderCreate,
    CustomReminderOut,
    FamilyMemberCreate,
    FamilyMemberOut,
    GameSessionOut,
    PatientDailyRemindersOut,
    RemindersOut,
)

router = APIRouter(prefix="/api/patients", tags=["patients"])
patient_alias_router = APIRouter(prefix="/api/patient", tags=["patient"])



def _normalize_patient_id(patient_id: str) -> str:
    return patient_id.strip()


async def _verify_patient_access(patient_id: str, caregiver: User) -> str:
    """Verify caregiver has access to this patient and return normalized patient ID."""
    norm_id = _normalize_patient_id(patient_id)
    patient = await find_patient_for_caregiver(norm_id, caregiver.id)
    if not patient:
        patient = await find_patient_for_caregiver(patient_id, caregiver.id)
    if not patient:
        raise HTTPException(status_code=404, detail="Patient record not found")
    return patient.patient_code or str(patient.id)


# ---- 1. Memory Gallery (Family Members) -----------------------------------

@router.get("/{patientId}/family-members", response_model=List[FamilyMemberOut])
async def get_family_members(patientId: str, caregiver: User = Depends(require_caregiver)):
    """Retrieve all family member photo memory cards for a specific patient."""
    norm_id = await _verify_patient_access(patientId, caregiver)
    members = await FamilyMember.find(FamilyMember.patient_id == norm_id).to_list()

    return [
        FamilyMemberOut(
            id=m.id,
            patientId=m.patient_id,
            name=m.name,
            relation=m.relation,
            photoUrl=m.photo_url,
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
    )
    await member.insert()

    return FamilyMemberOut(
        id=member.id,
        patientId=member.patient_id,
        name=member.name,
        relation=member.relation,
        photoUrl=member.photo_url,
    )


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

    # 3. Seed / demo fallback (p101 -> PAIR-652759)
    if clean_code in ["PAIR-652759", "652759", "P101"]:
        patient = await User.find_one(User.patient_code == "p101", User.role == RoleEnum.patient)
        if not patient:
            patient = User(
                role=RoleEnum.patient,
                name="Aarav Sharma",
                patient_code="p101",
                pairing_token="PAIR-652759",
                region_language="bn",
                status="stable",
                status_label="Active • Tablet synced",
            )
            await patient.insert()
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

def _session_to_out(s: GameSession, profile_id: str) -> GameSessionOut:
    return GameSessionOut(
        session_id=s.client_session_id or str(s.id),
        patient_profile_id=s.patient_profile_id or profile_id,
        game_type=s.game_type,
        domain=s.domain or "memory",
        session_date=s.client_timestamp.isoformat() if s.client_timestamp else datetime.utcnow().isoformat(),
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
