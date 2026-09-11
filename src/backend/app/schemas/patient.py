from typing import Any, Dict, List, Optional, Union
from pydantic import BaseModel, Field


# ---- Patient Roster & Details Schemas ------------------------------------

class EmergencyContact(BaseModel):
    name: str
    relationship: str
    phone: str


class DeviceStatus(BaseModel):
    linked: bool = True
    deviceName: Optional[str] = None
    deviceId: Optional[str] = None
    lastSynced: Optional[str] = None


class PatientSummaryOut(BaseModel):
    id: str
    name: str
    age: Optional[int] = None
    diagnosis: Optional[str] = None
    avatarUrl: Optional[str] = None
    status: str = "stable"
    statusLabel: str = "Active • Tablet synced"
    lastCheckIn: Optional[str] = None
    pairingToken: Optional[str] = None


class PatientDetailOut(BaseModel):
    id: str
    name: str
    age: Optional[int] = None
    gender: Optional[str] = None
    dateOfBirth: Optional[str] = None
    healthIssue: Optional[str] = None
    avatarUrl: Optional[str] = None
    status: str = "stable"
    statusLabel: str = "Active • Tablet synced"
    lastCheckIn: Optional[str] = None
    emergencyContact: Optional[EmergencyContact] = None
    deviceStatus: Optional[DeviceStatus] = None
    pairingToken: Optional[str] = None


class PatientCreateRequest(BaseModel):
    id: Optional[str] = None
    name: str = Field(min_length=1)
    age: Optional[int] = None
    gender: Optional[str] = None
    dateOfBirth: Optional[str] = None
    diagnosis: Optional[str] = None
    healthIssue: Optional[str] = None
    avatarUrl: Optional[str] = None
    status: Optional[str] = "stable"
    statusLabel: Optional[str] = "Registration completed"
    notes: Optional[str] = None
    emergencyContact: Optional[Dict[str, Any]] = None
    deviceStatus: Optional[Dict[str, Any]] = None
    pairingToken: Optional[str] = None


# ---- Memory Gallery (Family Members) Schemas ----------------------------

class FamilyMemberCreate(BaseModel):
    name: str = Field(min_length=1, description="Full name of family member")
    relation: str = Field(min_length=1, description="Relationship to patient")
    photoUrl: str = Field(min_length=1, description="Photo data URI or URL")


class FamilyMemberOut(BaseModel):
    id: str
    patientId: str
    name: str
    relation: str
    photoUrl: str


# ---- Health & Wellness Reminders Schemas ---------------------------------

class CustomReminderCreate(BaseModel):
    label: str = Field(min_length=1)
    time: str = Field(min_length=1)
    frequency: str = "Daily"


class CustomReminderOut(BaseModel):
    id: str
    label: str
    time: str
    frequency: str = "Daily"


class RemindersOut(BaseModel):
    medication: List[Dict[str, Any]] = []
    hydration: Dict[str, Any] = {}
    meals: List[Dict[str, Any]] = []
    custom: List[Dict[str, Any]] = []


# ---- Cognitive Game Sessions Schemas -------------------------------------

class GameSessionOut(BaseModel):
    session_id: str
    patient_profile_id: str
    game_type: str
    domain: str
    session_date: str
    session_duration: Union[float, int] = 120
    status: str = "completed"
    difficulty_level: Union[int, str] = 1
    score_normalized: float

    # Memory: Pair Matching fields
    correct_match_rate: Optional[float] = None
    total_flips: Optional[int] = None
    time_to_first_correct_match: Optional[float] = None
    repeat_error_rate: Optional[float] = None
    completion_time: Optional[Union[float, int]] = None
    pairs_count: Optional[int] = None
    used_face_name_variant: Optional[bool] = None

    # Language: Word Association fields
    words_recalled_count: Optional[int] = None
    response_latency_per_word: Optional[List[float]] = None
    category_switch_errors: Optional[int] = None
    language_used: Optional[str] = None
    category_prompt: Optional[str] = None
    round_duration: Optional[Union[float, int]] = None

    # Attention: Visual Search fields
    reaction_time_avg: Optional[Union[float, int]] = None
    reaction_time_variability: Optional[Union[float, int]] = None
    omission_rate: Optional[float] = None
    false_positive_rate: Optional[float] = None
    within_session_drift: Optional[float] = None
    trial_count: Optional[int] = None

    raw_trials: Optional[List[Dict[str, Any]]] = Field(default_factory=list)
