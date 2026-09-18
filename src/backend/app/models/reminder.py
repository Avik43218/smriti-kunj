import uuid
from datetime import datetime
from typing import Annotated, Any, Dict, List

from beanie import Document, Indexed
from pydantic import Field


class PatientReminder(Document):
    """Health & Wellness reminders schedule for a patient.
    Stores medication, hydration, meals, and custom routine reminders.
    """

    id: uuid.UUID = Field(default_factory=uuid.uuid4)
    patient_id: Annotated[str, Indexed(unique=True)]

    medication: List[Dict[str, Any]] = Field(default_factory=list)
    hydration: Dict[str, Any] = Field(default_factory=dict)
    meals: List[Dict[str, Any]] = Field(default_factory=list)
    custom: List[Dict[str, Any]] = Field(default_factory=list)

    updated_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "patient_reminders"
