import uuid
from datetime import datetime
from enum import Enum
from typing import Any, Dict, Optional, Annotated, Union, Literal

from beanie import Document, Indexed, PydanticObjectId
from pydantic import Field


from pymongo import ASCENDING, IndexModel


class RoleEnum(str, Enum):
    admin = "admin"
    caregiver = "caregiver"
    patient = "patient"


class User(Document):
    """Unified auth collection — this *is* the credential store. Caregivers
    and admins register with email + password (bcrypt hash below, never the raw
    password). Patients hold no credentials of their own: `caregiver_id`
    links a patient doc back to the caregiver who paired the tablet, and
    `device_id` identifies the paired hardware."""

    id: uuid.UUID = Field(default_factory=uuid.uuid4)
    role: Union[RoleEnum, Literal["admin", "caregiver", "patient"]] = Field(default=RoleEnum.caregiver)
    name: str

    email: Optional[str] = None  # caregivers & admins
    hashed_password: Optional[str] = None  # bcrypt hash
    created_by: Optional[Union[PydanticObjectId, uuid.UUID]] = None

    region_language: str = "bn"  # as / bn / mni ...
    caregiver_id: Optional[uuid.UUID] = None
    device_id: Optional[str] = None

    # Patient profile attributes
    patient_code: Optional[str] = None  # e.g. "p101"
    pairing_token: Optional[str] = None  # e.g. "PAIR-123456"
    age: Optional[int] = None
    gender: Optional[str] = None
    date_of_birth: Optional[str] = None
    diagnosis: Optional[str] = None
    health_issue: Optional[str] = None
    avatar_url: Optional[str] = None
    status: Optional[str] = "active"
    status_label: Optional[str] = "Active • Tablet synced"
    last_check_in: Optional[str] = None
    notes: Optional[str] = None
    emergency_contact: Optional[Dict[str, Any]] = None
    device_status: Optional[Dict[str, Any]] = None

    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "users"
        indexes = [
            IndexModel(
                [("email", ASCENDING)],
                unique=True,
                partialFilterExpression={"email": {"$type": "string"}},
            ),
            IndexModel(
                [("device_id", ASCENDING)],
                unique=True,
                partialFilterExpression={"device_id": {"$type": "string"}},
            ),
            IndexModel(
                [("patient_code", ASCENDING)],
                unique=True,
                partialFilterExpression={"patient_code": {"$type": "string"}},
            ),
            IndexModel(
                [("pairing_token", ASCENDING)],
                partialFilterExpression={"pairing_token": {"$type": "string"}},
            ),
            IndexModel([("caregiver_id", ASCENDING)]),
        ]


class DevicePairingToken(Document):
    """Short-lived, single-use token behind the caregiver's QR code / magic
    link, used to pair a patient's tablet into Patient Mode. Separate from
    the JWT the device is issued once pairing completes."""

    id: uuid.UUID = Field(default_factory=uuid.uuid4)
    caregiver_id: uuid.UUID
    patient_id: Optional[uuid.UUID] = None
    token: Annotated[str, Indexed(unique=True)]
    expires_at: datetime
    used: bool = False

    class Settings:
        name = "device_pairing_tokens"
