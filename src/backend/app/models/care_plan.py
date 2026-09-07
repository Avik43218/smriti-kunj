import uuid
from datetime import datetime
from typing import Annotated

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

    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "family_members"
