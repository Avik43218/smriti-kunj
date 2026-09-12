"""Self-hosted, unified role-based auth — routes here match the contract in
the uploaded `authService.js`: register -> login (password check, sends an
OTP) -> request-otp (resend) -> verify-otp (issues the session token) ->
logout (revokes it). Mounted at /api/auth to match that client exactly.

Caregiver login is two-factor: /login only validates the password and
triggers an email OTP — it deliberately returns no token, matching
authService.js's login() (which never touches localStorage). Only
/verify-otp issues a session, matching its comment `{ token, caregiver }`.

Patients still never hold credentials — pairing a tablet issues its own
long-lived device token, unchanged from before.
"""
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials

from app.config import settings
from app.core.otp import generate_otp, hash_otp, verify_otp_code
from app.core.security import (
    bearer_scheme,
    create_caregiver_token,
    create_patient_device_token,
    get_current_user,
    hash_password,
    require_caregiver,
    require_patient,
    revoke_current_token,
    verify_password,
)
from app.models.auth import OtpCode
from app.models.user import DevicePairingToken, RoleEnum, User
from app.schemas.auth import (
    CaregiverOut,
    CaregiverRegisterRequest,
    LoginRequest,
    LogoutResponse,
    OtpRequestRequest,
    OtpRequestResponse,
    OtpVerifyRequest,
    OtpVerifyResponse,
    PatientPairCompleteOut,
    PatientPairCompleteRequest,
    PatientPairStartOut,
    TokenOut,
    UserOut,
)

router = APIRouter(prefix="/api/auth", tags=["auth"])


async def _issue_otp(email: str) -> None:
    """Invalidate any outstanding code for this email and issue a fresh one.
    Sending is stubbed to a print — wire up a real provider (SES/SendGrid/
    etc.) here before this goes anywhere near production."""
    await OtpCode.find(OtpCode.email == email).delete()

    code = generate_otp()
    await OtpCode(
        email=email,
        otp_hash=hash_otp(code),
        expires_at=datetime.utcnow() + timedelta(minutes=settings.OTP_EXPIRE_MINUTES),
    ).insert()

    # TODO: send `code` via email instead of logging it.
    print(f"[stub email] OTP for {email}: {code}")


@router.post("/register", response_model=CaregiverOut, status_code=201)
async def register(payload: CaregiverRegisterRequest):
    if await User.find_one(User.email == payload.email):
        raise HTTPException(status_code=409, detail="An account with that email already exists")

    user = User(
        role=RoleEnum.caregiver,
        name=payload.name,
        email=payload.email,
        hashed_password=hash_password(payload.password),
        region_language=payload.region_language,
    )
    await user.insert()
    return user


@router.post("/login", response_model=OtpRequestResponse)
async def login(payload: LoginRequest):
    """Step 1 of 2: validate the password, then send an OTP. No session
    token is issued here — only /verify-otp issues one."""
    user = await User.find_one(User.email == payload.email, User.role == RoleEnum.caregiver)
    if not user or not user.hashed_password or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Incorrect email or password")

    await _issue_otp(user.email)
    return OtpRequestResponse(message="A one-time code has been sent to your email.", email=user.email)


@router.post("/request-otp", response_model=OtpRequestResponse)
async def request_otp(payload: OtpRequestRequest):
    """Resend path ('Didn't get a code?'). Always returns the same generic
    message whether or not the email has an account, to avoid leaking
    which emails are registered."""
    user = await User.find_one(User.email == payload.email, User.role == RoleEnum.caregiver)
    if user:
        await _issue_otp(user.email)
    return OtpRequestResponse(message="If that email has an account, a code has been sent.", email=payload.email)


@router.post("/verify-otp", response_model=OtpVerifyResponse)
async def verify_otp(payload: OtpVerifyRequest):
    user = await User.find_one(User.email == payload.email, User.role == RoleEnum.caregiver)
    otp_record = await OtpCode.find_one(OtpCode.email == payload.email)

    if not user or not otp_record:
        raise HTTPException(status_code=400, detail="Invalid or expired code")

    if otp_record.expires_at < datetime.utcnow():
        await otp_record.delete()
        raise HTTPException(status_code=400, detail="Invalid or expired code")

    if otp_record.attempts >= settings.OTP_MAX_ATTEMPTS:
        await otp_record.delete()
        raise HTTPException(status_code=429, detail="Too many attempts — request a new code")

    if not verify_otp_code(payload.otp, otp_record.otp_hash):
        otp_record.attempts += 1
        await otp_record.save()
        raise HTTPException(status_code=400, detail="Invalid or expired code")

    await otp_record.delete()

    return OtpVerifyResponse(
        token=create_caregiver_token(user.id),
        caregiver=CaregiverOut.model_validate(user),
    )


@router.post("/logout", response_model=LogoutResponse)
async def logout(
    creds: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    user: User = Depends(get_current_user),
):
    await revoke_current_token(creds.credentials)
    return LogoutResponse()


@router.get("/me", response_model=UserOut)
async def me(user: User = Depends(get_current_user)):
    return user


@router.post("/patient/pair/start", response_model=PatientPairStartOut)
async def start_pairing(caregiver: User = Depends(require_caregiver)):
    """Caregiver's app calls this to generate the token behind the QR code /
    magic link shown on the patient's tablet during first-time setup."""
    pairing = DevicePairingToken(
        caregiver_id=caregiver.id,
        token=uuid.uuid4().hex,
        expires_at=datetime.utcnow() + timedelta(minutes=10),
    )
    await pairing.insert()
    return PatientPairStartOut(pairing_token=pairing.token, expires_at=pairing.expires_at)


@router.post("/patient/pair", response_model=PatientPairCompleteOut)
@router.post("/patient/pair/complete", response_model=PatientPairCompleteOut)
async def complete_pairing(payload: PatientPairCompleteRequest):
    """Patient tablet calls this with the pairing code generated during
    registration or setup. Links the tablet hardware to the patient record
    and issues a long-lived device JWT."""
    raw_code = (payload.pairing_code or payload.pairing_token or "").strip()
    if not raw_code:
        raise HTTPException(status_code=400, detail="Pairing code is required")

    clean_code = raw_code.upper()
    candidates = [clean_code]
    if clean_code.startswith("PAIR-"):
        candidates.append(clean_code[5:])
    else:
        candidates.append(f"PAIR-{clean_code}")

    # 1. Check DevicePairingToken table
    pairing_rec = None
    for cand in candidates:
        pairing_rec = await DevicePairingToken.find_one(
            DevicePairingToken.token == cand,
            DevicePairingToken.used == False,  # noqa: E712
        )
        if pairing_rec:
            break

    patient: Optional[User] = None
    if pairing_rec:
        if pairing_rec.patient_id:
            patient = await User.get(pairing_rec.patient_id)
        if not patient and pairing_rec.caregiver_id:
            patient = await User.find_one(
                User.caregiver_id == pairing_rec.caregiver_id,
                User.role == RoleEnum.patient,
                User.pairing_token == pairing_rec.token,
            )

    # 2. Check User.pairing_token directly
    if not patient:
        for cand in candidates:
            patient = await User.find_one(
                User.role == RoleEnum.patient,
                User.pairing_token == cand,
            )
            if patient:
                break

    # 3. Check demo/seed derivation (e.g. p101 -> PAIR-652759)
    if not patient and clean_code in ["PAIR-652759", "652759", "P101"]:
        patient = await User.find_one(User.patient_code == "p101", User.role == RoleEnum.patient)

    # 4. Fallback: if unused token with no patient existed (legacy setup)
    if not patient and pairing_rec:
        patient_name = payload.patient_name or "Patient"
        patient = User(
            role=RoleEnum.patient,
            name=patient_name,
            caregiver_id=pairing_rec.caregiver_id,
            patient_code=f"p{uuid.uuid4().hex[:6]}",
            pairing_token=pairing_rec.token,
        )
        await patient.insert()

    if not patient:
        raise HTTPException(
            status_code=404,
            detail="Invalid or expired pairing code. Please check the code with your caregiver.",
        )

    # Resolve device ID
    device_id = payload.device_id or patient.device_id or f"dev_{uuid.uuid4().hex[:8]}"

    # Unlink any other user holding this device_id
    other_device_user = await User.find_one(
        User.device_id == device_id,
        User.id != patient.id,
    )
    if other_device_user:
        other_device_user.device_id = None
        await other_device_user.save()

    # Link device to patient
    patient.device_id = device_id
    patient.status = "stable"
    patient.status_label = "Active • Tablet synced"
    patient.last_check_in = "Just paired"
    patient.device_status = {
        "linked": True,
        "deviceId": device_id,
        "deviceName": payload.device_name or "Patient Tablet",
        "lastSynced": datetime.utcnow().isoformat(),
    }
    await patient.save()

    if pairing_rec:
        pairing_rec.used = True
        pairing_rec.patient_id = patient.id
        await pairing_rec.save()

    token = TokenOut(
        access_token=create_patient_device_token(patient.id),
        expires_at=datetime.now(timezone.utc) + timedelta(days=settings.PATIENT_TOKEN_EXPIRE_DAYS),
    )

    emergency = patient.emergency_contact or {}
    guardian_phone = emergency.get("phone")
    guardian_name = emergency.get("name")
    guardian_relationship = emergency.get("relationship")

    return PatientPairCompleteOut(
        patient_id=patient.id,
        patient_code=patient.patient_code,
        patient_name=patient.name,
        caregiver_id=patient.caregiver_id,
        token=token,
        region_language=patient.region_language or "bn",
        emergency_contact=patient.emergency_contact,
        guardian_phone=guardian_phone,
        guardian_name=guardian_name,
        guardian_relationship=guardian_relationship,
        diagnosis=patient.diagnosis,
        status=patient.status or "stable",
    )


@router.get("/patient/me", response_model=PatientPairCompleteOut)
async def get_patient_me(patient: User = Depends(require_patient)):
    """Fetch current paired patient profile and emergency contact using device token."""
    emergency = patient.emergency_contact or {}
    guardian_phone = emergency.get("phone")
    guardian_name = emergency.get("name")
    guardian_relationship = emergency.get("relationship")

    return PatientPairCompleteOut(
        patient_id=patient.id,
        patient_code=patient.patient_code,
        patient_name=patient.name,
        caregiver_id=patient.caregiver_id,
        token=TokenOut(
            access_token="",
            expires_at=datetime.now(timezone.utc) + timedelta(days=settings.PATIENT_TOKEN_EXPIRE_DAYS),
        ),
        region_language=patient.region_language or "bn",
        emergency_contact=patient.emergency_contact,
        guardian_phone=guardian_phone,
        guardian_name=guardian_name,
        guardian_relationship=guardian_relationship,
        diagnosis=patient.diagnosis,
        status=patient.status or "stable",
    )

