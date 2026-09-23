import uuid
from datetime import datetime
from typing import Annotated, Optional

from beanie import Document, Indexed
from pydantic import Field


class FamilyMember(Document):
    """Memory gallery family member card for a patient.
    Feeds Care Plan page Memory Gallery and Pair Matching game face-name variant.
    """

    id: str = Field(default_factory=lambda: f"fam_{uuid.uuid4().hex[:8]}")
    patient_id: Annotated[str, Indexed()]
    name: str
    relation: str
    photo_url: str
    audio_url: Optional[str] = None

    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "family_members"


class FamiliarSound(Document):
    """Comforting sound or familiar voice clip for a patient.
    Added from Care Plan & Customisation section.
    """

    id: str = Field(default_factory=lambda: f"sound_{uuid.uuid4().hex[:8]}")
    patient_id: Annotated[str, Indexed()]
    caption: str
    audio_url: str
    file_name: Optional[str] = None

    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "familiar_sounds"

