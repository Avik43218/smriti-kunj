import uuid
from datetime import datetime
from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, EmailStr, Field, field_validator


class CaregiverAdminOut(BaseModel):
    id: uuid.UUID
    name: str
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    region_language: str = "bn"
    role: str = "caregiver"
    status: str = "active"
    must_change_password: Optional[bool] = False
    temporary_password: Optional[str] = None
    patient_count: int = 0
    assigned_patient_ids: List[str] = Field(default_factory=list)
    created_at: Optional[datetime] = None
    created_by: Optional[str] = None

    class Config:
        from_attributes = True


class CaregiverCreateAdminRequest(BaseModel):
    name: str
    email: EmailStr
    password: Optional[str] = None
    phone: Optional[str] = None
    region_language: str = "bn"
    status: Literal["active", "disabled"] = "active"
    assigned_patient_ids: Optional[List[uuid.UUID]] = None

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v.strip() and len(v.strip()) < 10:
            raise ValueError("Password must be at least 10 characters long")
        return v


class CaregiverUpdateAdminRequest(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    region_language: Optional[str] = None
    status: Optional[Literal["active", "disabled"]] = None


class CaregiverResetPasswordRequest(BaseModel):
    new_password: Optional[str] = None

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v.strip() and len(v.strip()) < 10:
            raise ValueError("New password must be at least 10 characters long")
        return v


class CaregiverResetPasswordResponse(BaseModel):
    temporary_password: str
    message: str = "Password reset successfully. Please share this temporary password with the caregiver."


class CaregiverAssignedSummary(BaseModel):
    id: uuid.UUID
    name: str
    email: Optional[str] = None


class PatientAdminOut(BaseModel):
    id: str
    uuid_id: uuid.UUID
    patient_code: Optional[str] = None
    name: str
    age: Optional[int] = None
    gender: Optional[str] = None
    diagnosis: Optional[str] = None
    weight: Optional[str] = None
    body_weight: Optional[str] = None
    bodyWeight: Optional[str] = None
    status: Optional[str] = "stable"
    status_label: Optional[str] = None
    caregiver_id: Optional[uuid.UUID] = None
    caregiver_name: Optional[str] = None
    caregiver_email: Optional[str] = None
    assigned_caregiver_ids: List[uuid.UUID] = Field(default_factory=list)
    assigned_caregivers: List[CaregiverAssignedSummary] = Field(default_factory=list)
    device_id: Optional[str] = None
    pairing_token: Optional[str] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class PatientReassignRequest(BaseModel):
    new_caregiver_id: uuid.UUID


class PatientAssignCaregiversRequest(BaseModel):
    caregiver_ids: List[uuid.UUID]


class AdminAuditLogOut(BaseModel):
    id: str
    actor_id: Optional[uuid.UUID] = None
    actor_name: Optional[str] = None
    actor_email: Optional[str] = None
    action: str
    target_type: Optional[str] = None
    target_id: Optional[str] = None
    target_name: Optional[str] = None
    details: Optional[Dict[str, Any]] = None
    timestamp: datetime

    class Config:
        from_attributes = True
