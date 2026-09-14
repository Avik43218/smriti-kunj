import uuid
from datetime import datetime
from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, EmailStr, Field


class CaregiverAdminOut(BaseModel):
    id: uuid.UUID
    name: str
    email: Optional[EmailStr] = None
    region_language: str = "bn"
    role: str = "caregiver"
    status: str = "active"
    patient_count: int = 0
    created_at: Optional[datetime] = None
    created_by: Optional[str] = None

    class Config:
        from_attributes = True


class CaregiverCreateAdminRequest(BaseModel):
    name: str
    email: EmailStr
    password: str = Field(min_length=8)
    region_language: str = "bn"
    status: Literal["active", "disabled"] = "active"


class CaregiverUpdateAdminRequest(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None
    region_language: Optional[str] = None
    status: Optional[Literal["active", "disabled"]] = None


class PatientAdminOut(BaseModel):
    id: str
    uuid_id: uuid.UUID
    patient_code: Optional[str] = None
    name: str
    age: Optional[int] = None
    gender: Optional[str] = None
    diagnosis: Optional[str] = None
    status: Optional[str] = "stable"
    status_label: Optional[str] = None
    caregiver_id: Optional[uuid.UUID] = None
    caregiver_name: Optional[str] = None
    caregiver_email: Optional[str] = None
    device_id: Optional[str] = None
    pairing_token: Optional[str] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class PatientReassignRequest(BaseModel):
    new_caregiver_id: uuid.UUID
