from enum import unique
import uuid
from datetime import datetime

from typing import Annotated
from beanie import Document, Indexed
from pydantic import Field
from pymongo import IndexModel


class OtpCode(Document):
    """A single outstanding email-OTP challenge for caregiver login. Only
    an HMAC digest of the code is ever stored (see core/otp.py) — never the
    plaintext code. Mongo's TTL index on `expires_at` auto-deletes expired
    challenges, so there's no cleanup job to run."""

    id: uuid.UUID = Field(default_factory=uuid.uuid4)
    email: Annotated[str, Indexed()]
    otp_hash: str
    attempts: int = 0
    created_at: datetime = Field(default_factory=datetime.utcnow)
    expires_at: datetime

    class Settings:
        name = "otp_codes"
        indexes = [IndexModel("expires_at", expireAfterSeconds=0)]


class RevokedToken(Document):
    """Logout support. JWTs are stateless, so ending a session server-side
    means recording the token's `jti` here — get_current_user checks this
    collection on every request and rejects a match. The TTL index purges
    an entry the moment the original token would have expired anyway, so
    the blacklist never grows unbounded."""

    id: uuid.UUID = Field(default_factory=uuid.uuid4)
    jti: Annotated[str, Indexed(unique=True)]
    revoked_at: datetime = Field(default_factory=datetime.utcnow)
    expires_at: datetime

    class Settings:
        name = "revoked_tokens"
        indexes = [IndexModel("expires_at", expireAfterSeconds=0)]
