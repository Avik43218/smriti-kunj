import uuid
from datetime import datetime
from typing import Any, Dict, Optional

from beanie import Document, Indexed
from pydantic import Field


class AdminAuditLog(Document):
    """Immutable audit trail for all administrative actions:
    caregiver creation, deactivation, password reset, and patient assignment changes.
    """

    id: uuid.UUID = Field(default_factory=uuid.uuid4)
    actor_id: uuid.UUID
    actor_name: str
    actor_email: Optional[str] = None
    action: str  # e.g., "create_caregiver", "deactivate_caregiver", "reset_password", "assign_patients"
    target_type: str  # e.g., "caregiver", "patient"
    target_id: str
    target_name: Optional[str] = None
    details: Optional[Dict[str, Any]] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "admin_audit_logs"
        indexes = [
            "actor_id",
            "action",
            "target_id",
            [("timestamp", -1)],
        ]
