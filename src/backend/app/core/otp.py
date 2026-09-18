"""Email-OTP generation and verification — the second factor for caregiver
login. Codes are short-lived, numeric, and generated with `secrets` (not
`random`) for cryptographic randomness. Only an HMAC-SHA256 digest, keyed
with the app's JWT secret, is ever persisted (see models/auth.OtpCode)."""
import hashlib
import hmac
import secrets

from app.config import settings


def generate_otp(length: int | None = None) -> str:
    length = length or settings.OTP_LENGTH
    return "".join(secrets.choice("0123456789") for _ in range(length))


def hash_otp(otp: str) -> str:
    return hmac.new(
        settings.JWT_SECRET_KEY.encode("utf-8"), otp.encode("utf-8"), hashlib.sha256
    ).hexdigest()


def verify_otp_code(otp: str, hashed: str) -> bool:
    return hmac.compare_digest(hash_otp(otp), hashed)
