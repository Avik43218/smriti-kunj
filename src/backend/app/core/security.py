"""Self-hosted authentication.

Credentials never leave MongoDB: caregiver passwords are bcrypt-hashed and
stored on the `users` document (see models/user.py); there is no external
identity provider. Session state is a signed JWT — issued to a caregiver
only after they confirm an email OTP (see api/routes/auth.py), long-lived
for patient devices (paired once, then stays signed in). Logging out
records the token's `jti` in `revoked_tokens` so it's rejected immediately,
even though it hasn't technically expired yet.
"""
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

import bcrypt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from app.config import settings
from app.models.auth import RevokedToken
from app.models.user import RoleEnum, User

bearer_scheme = HTTPBearer()


# ---- Password hashing (caregivers only) ------------------------------------

def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode("utf-8"), hashed.encode("utf-8"))


# ---- JWT issuance ------------------------------------------------------

def _create_token(
    user_id: uuid.UUID,
    role: Any,
    expires_delta: timedelta,
    must_change_password: bool = False,
    token_version: int = 1,
) -> str:
    expire = datetime.now(timezone.utc) + expires_delta
    role_str = role.value if hasattr(role, "value") else str(role)
    payload = {
        "sub": str(user_id),
        "role": role_str,
        "must_change_password": must_change_password,
        "ver": token_version,
        "jti": uuid.uuid4().hex,
        "exp": expire,
    }
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def create_caregiver_token(
    user_id: uuid.UUID,
    must_change_password: bool = False,
    token_version: int = 1,
) -> str:
    return _create_token(
        user_id,
        RoleEnum.caregiver,
        timedelta(minutes=settings.CAREGIVER_TOKEN_EXPIRE_MINUTES),
        must_change_password=must_change_password,
        token_version=token_version,
    )


def create_admin_token(
    user_id: uuid.UUID,
    must_change_password: bool = False,
    token_version: int = 1,
) -> str:
    return _create_token(
        user_id,
        RoleEnum.admin,
        timedelta(minutes=settings.CAREGIVER_TOKEN_EXPIRE_MINUTES),
        must_change_password=must_change_password,
        token_version=token_version,
    )


def create_patient_device_token(user_id: uuid.UUID) -> str:
    return _create_token(
        user_id,
        RoleEnum.patient,
        timedelta(days=settings.PATIENT_TOKEN_EXPIRE_DAYS),
        must_change_password=False,
        token_version=1,
    )


def create_user_token(user: User, expires_delta: Optional[timedelta] = None) -> str:
    delta = expires_delta or timedelta(minutes=settings.CAREGIVER_TOKEN_EXPIRE_MINUTES)
    return _create_token(
        user_id=user.id,
        role=user.role,
        expires_delta=delta,
        must_change_password=bool(getattr(user, "must_change_password", False)),
        token_version=getattr(user, "token_version", 1) or 1,
    )


# ---- Logout / revocation ------------------------------------------------------

async def revoke_current_token(token: str) -> None:
    """Best-effort: an already-malformed or expired token has nothing to
    revoke, so this never raises — logout should always succeed from the
    client's point of view."""
    try:
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
    except JWTError:
        return

    jti, exp = payload.get("jti"), payload.get("exp")
    if not jti or not exp or await RevokedToken.find_one(RevokedToken.jti == jti):
        return

    await RevokedToken(jti=jti, expires_at=datetime.fromtimestamp(exp, tz=timezone.utc)).insert()


# ---- Request-time verification ------------------------------------------------

async def get_current_user(creds: HTTPAuthorizationCredentials = Depends(bearer_scheme)) -> User:
    try:
        payload = jwt.decode(
            creds.credentials, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM]
        )
        user_id = uuid.UUID(payload["sub"])
    except (JWTError, KeyError, ValueError):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token")

    if payload.get("jti") and await RevokedToken.find_one(RevokedToken.jti == payload["jti"]):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token has been revoked")

    user = await User.get(user_id)
    if not user:
        user = await User.find_one(User.id == user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    if getattr(user, "status", None) == "disabled":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is disabled")

    # Invalidate session if user's token version changed (password changed or reset)
    token_ver = payload.get("ver")
    current_ver = getattr(user, "token_version", 1) or 1
    if token_ver is not None and token_ver != current_ver:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session expired due to password change. Please log in again.",
        )

    return user


async def require_admin(user: User = Depends(get_current_user)) -> User:
    if getattr(user, "status", None) == "disabled":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is disabled")
    if getattr(user, "must_change_password", False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Password change required before accessing platform features",
        )
    role_val = user.role.value if hasattr(user.role, "value") else str(user.role)
    if role_val != "admin" and user.role != RoleEnum.admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return user


async def require_caregiver(user: User = Depends(get_current_user)) -> User:
    if getattr(user, "status", None) == "disabled":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is disabled")
    if getattr(user, "must_change_password", False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Password change required before accessing platform features",
        )
    role_val = user.role.value if hasattr(user.role, "value") else str(user.role)
    if role_val not in ["caregiver", "admin"] and user.role not in [RoleEnum.caregiver, RoleEnum.admin]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Caregiver access required")
    return user


async def require_patient(user: User = Depends(get_current_user)) -> User:
    role_val = user.role.value if hasattr(user.role, "value") else str(user.role)
    if role_val != "patient" and user.role != RoleEnum.patient:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Patient device access required")
    return user
