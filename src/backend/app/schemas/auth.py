import uuid
from datetime import datetime
from typing import Any, Dict, Optional, List

from pydantic import BaseModel, EmailStr, Field


class UserOut(BaseModel):
    id: uuid.UUID
    role: str
    name: str
    email: Optional[str] = None
    status: Optional[str] = "active"
    patient_code: Optional[str] = None
    region_language: Optional[str] = "bn"
    pairing_token: Optional[str] = None
    emergency_contact: Optional[Dict[str, Any]] = None
    device_id: Optional[str] = None
    must_change_password: Optional[bool] = False

    class Config:
        from_attributes = True


class CaregiverOut(BaseModel):
    id: uuid.UUID
    name: str
    email: EmailStr
    phone: Optional[str] = None
    region_language: Optional[str] = "bn"
    role: str = "caregiver"
    status: Optional[str] = "active"
    must_change_password: Optional[bool] = False

    class Config:
        from_attributes = True


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_at: datetime


class CaregiverRegisterRequest(BaseModel):
    name: str
    email: EmailStr
    password: str = Field(min_length=10)
    region_language: str = "bn"


class LoginRequest(BaseModel):
    email: EmailStr
    password: str
    role: Optional[str] = None


class OtpRequestRequest(BaseModel):
    email: EmailStr


class OtpVerifyRequest(BaseModel):
    email: EmailStr
    otp: str = Field(min_length=4, max_length=8)


class OtpRequestResponse(BaseModel):
    message: str
    email: EmailStr
    debug_otp: Optional[str] = None


class OtpVerifyResponse(BaseModel):
    """Matches authService.js's `verifyOtp()`, which reads `data.token` and
    comments that the response is `{ token, caregiver }`."""

    token: str
    caregiver: CaregiverOut
    user: Optional[UserOut] = None
    must_change_password: Optional[bool] = False


class ChangePasswordRequest(BaseModel):
    current_password: Optional[str] = None
    new_password: str = Field(min_length=10)


class ChangePasswordResponse(BaseModel):
    message: str = "Password changed successfully"
    must_change_password: bool = False
    token: Optional[str] = None


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    otp: str = Field(min_length=4, max_length=8)
    new_password: str = Field(min_length=10)


class LogoutResponse(BaseModel):
    success: bool = True


class PatientPairStartOut(BaseModel):
    pairing_token: str
    expires_at: datetime


class PatientPairCompleteRequest(BaseModel):
    pairing_token: Optional[str] = None
    pairing_code: Optional[str] = None
    device_id: Optional[str] = None
    device_name: Optional[str] = "Patient Device"
    patient_name: Optional[str] = None


class PatientPairCompleteOut(BaseModel):
    patient_id: uuid.UUID
    patient_code: Optional[str] = None
    patient_name: str
    caregiver_id: Optional[uuid.UUID] = None
    token: TokenOut
    region_language: Optional[str] = "bn"
    emergency_contact: Optional[Dict[str, Any]] = None
    guardian_phone: Optional[str] = None
    guardian_name: Optional[str] = None
    guardian_relationship: Optional[str] = None
    diagnosis: Optional[str] = None
    status: Optional[str] = "stable"
    alternative_emergency_contact: Optional[Dict[str, Any]] = None
    caregiver_name: Optional[str] = None
    caregiver_phone: Optional[str] = None
    caregivers: Optional[List[Dict[str, Any]]] = None


