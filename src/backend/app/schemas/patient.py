import re
from typing import Any, Dict, List, Literal, Optional, Union
from pydantic import BaseModel, Field, model_validator


def normalize_phone_digits(phone: Optional[str]) -> str:
    """Extract standard digits for comparison, stripping country code if 91."""
    if not phone:
        return ""
    digits = re.sub(r"\D", "", phone)
    if digits.startswith("91") and len(digits) == 12:
        digits = digits[2:]
    return digits


def validate_phone_number(phone: str) -> bool:
    """Validate standard phone number (accepts 10-digit mobile or international format with 7-15 digits)."""
    digits = re.sub(r"\D", "", phone)
    return 7 <= len(digits) <= 15


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
    weight: Optional[str] = None
    body_weight: Optional[str] = None
    bodyWeight: Optional[str] = None
    avatarUrl: Optional[str] = None
    status: str = "stable"
    statusLabel: str = "Active • Device synced"
    lastCheckIn: Optional[str] = None
    pairingToken: Optional[str] = None


class PatientDetailOut(BaseModel):
    id: str
    name: str
    age: Optional[int] = None
    gender: Optional[str] = None
    dateOfBirth: Optional[str] = None
    healthIssue: Optional[str] = None
    weight: Optional[str] = None
    body_weight: Optional[str] = None
    bodyWeight: Optional[str] = None
    diabetic: Optional[str] = None
    nutritionDiet: Optional[str] = None
    alcoholLevel: Optional[str] = None
    smokingStatus: Optional[str] = None
    avatarUrl: Optional[str] = None
    status: str = "stable"
    statusLabel: str = "Active • Device synced"
    lastCheckIn: Optional[str] = None
    emergencyContact: Optional[EmergencyContact] = None
    alternativeEmergencyContact: Optional[EmergencyContact] = None
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
    weight: Optional[str] = None
    body_weight: Optional[str] = None
    bodyWeight: Optional[str] = None
    diabetic: Optional[str] = None
    nutritionDiet: Optional[str] = None
    alcoholLevel: Optional[str] = None
    smokingStatus: Optional[str] = None
    avatarUrl: Optional[str] = None
    status: Optional[str] = "stable"
    statusLabel: Optional[str] = "Registration completed"
    notes: Optional[str] = None
    emergencyContact: Optional[Dict[str, Any]] = None
    alternativeEmergencyContact: Optional[Dict[str, Any]] = None
    deviceStatus: Optional[Dict[str, Any]] = None
    pairingToken: Optional[str] = None

    @model_validator(mode="after")
    def validate_emergency_contacts(self) -> "PatientCreateRequest":
        # Normalize alternativeEmergencyContact: if dict has only empty values or whitespace, normalize to None
        alt = self.alternativeEmergencyContact
        if alt is not None:
            if isinstance(alt, dict):
                cleaned_name = str(alt.get("name") or "").strip()
                cleaned_phone = str(alt.get("phone") or "").strip()
                cleaned_rel = str(alt.get("relationship") or "").strip()

                # If all fields are empty, normalize to None
                if not cleaned_name and not cleaned_phone and not cleaned_rel:
                    self.alternativeEmergencyContact = None
                else:
                    if not cleaned_name:
                        raise ValueError("Alternative emergency contact name is required when alternative contact is provided.")
                    if not cleaned_phone:
                        raise ValueError("Alternative emergency contact phone is required when alternative contact is provided.")
                    if not validate_phone_number(cleaned_phone):
                        raise ValueError("Please enter a valid phone number for alternative emergency contact.")

                    self.alternativeEmergencyContact = {
                        "name": cleaned_name,
                        "relationship": cleaned_rel or "Alternative Guardian",
                        "phone": cleaned_phone,
                    }

        # Check duplicate phone number against primary contact
        if self.alternativeEmergencyContact and self.emergencyContact:
            primary_phone = str(self.emergencyContact.get("phone") or "").strip()
            alt_phone = str(self.alternativeEmergencyContact.get("phone") or "").strip()
            if primary_phone and alt_phone:
                primary_digits = normalize_phone_digits(primary_phone)
                alt_digits = normalize_phone_digits(alt_phone)
                if primary_digits and primary_digits == alt_digits:
                    raise ValueError("Alternative emergency contact cannot have the same phone number as the primary emergency contact.")

        return self


# ---- Memory Gallery (Family Members & Familiar Sounds) Schemas ----------

class FamilyMemberCreate(BaseModel):
    name: str = Field(min_length=1, description="Full name of family member")
    relation: str = Field(min_length=1, description="Relationship to patient")
    photoUrl: str = Field(min_length=1, description="Photo data URI or URL")
    audioUrl: Optional[str] = Field(default=None, description="Optional audio message or voice clip URL")


class FamilyMemberOut(BaseModel):
    id: str
    patientId: str
    name: str
    relation: str
    photoUrl: str
    audioUrl: Optional[str] = None


class FamiliarSoundCreate(BaseModel):
    caption: str = Field(min_length=1, description="Title or description of voice clip or familiar sound")
    audioUrl: str = Field(min_length=1, description="Audio data URI or URL")
    fileName: Optional[str] = Field(default=None, description="Original uploaded audio file name")


class FamiliarSoundOut(BaseModel):
    id: str
    patientId: str
    caption: str
    audioUrl: str
    fileName: Optional[str] = None
    createdAt: Optional[str] = None


class MemoryItemOut(BaseModel):
    id: str
    patientId: str
    title: str
    subtitle: Optional[str] = None
    relationship: str
    type: Literal["photo", "audio"]
    photoUrl: Optional[str] = None
    audioUrl: Optional[str] = None
    audioDuration: Optional[str] = None
    createdAt: Optional[str] = None


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


class PatientDailyRemindersOut(BaseModel):
    patient_id: str
    patient_name: Optional[str] = None
    pairing_code: Optional[str] = None
    medication: List[Dict[str, Any]] = Field(default_factory=list)
    hydration: Union[Dict[str, Any], List[Dict[str, Any]]] = Field(default_factory=dict)
    meals: List[Dict[str, Any]] = Field(default_factory=list)
    custom: List[Dict[str, Any]] = Field(default_factory=list)
    reminders: List[Dict[str, Any]] = Field(default_factory=list)



# ---- Cognitive Game Sessions Schemas -------------------------------------

class GameSessionOut(BaseModel):
    session_id: str
    patient_profile_id: str
    game_type: str
    domain: str
    session_date: str
    synced_at: Optional[str] = None
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


# ---- Patient Profile Status Schemas (Read-only for patient device) -------

class CaregiverInfoOut(BaseModel):
    name: str
    phone: Optional[str] = None
    is_primary: bool = False


class ProfileStatusContactOut(BaseModel):
    type: str  # "primary" or "alternative"
    name: str
    relationship: str
    phone: str


class PatientProfileStatusOut(BaseModel):
    patient_name: str
    caregivers: List[CaregiverInfoOut] = Field(default_factory=list)
    emergency_contacts: List[ProfileStatusContactOut] = Field(default_factory=list)
    last_updated: Optional[str] = None

