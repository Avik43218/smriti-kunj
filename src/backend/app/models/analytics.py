import uuid
from datetime import datetime
from enum import Enum
from typing import Optional, Annotated

from beanie import Document, Indexed
from pydantic import Field
from pymongo import ASCENDING, IndexModel


class AlertSeverity(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"


class DriftMetric(Document):
    """Snapshot of the Pillar 3 linear-regression fit over a rolling window."""

    id: uuid.UUID = Field(default_factory=uuid.uuid4)
    patient_id: Annotated[uuid.UUID, Indexed()]
    window_days: int  # 7 or 30
    slope: float  # beta_1
    intercept: float  # beta_0
    r_squared: Optional[float] = None
    sample_count: int
    computed_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "drift_metrics"


class Alert(Document):
    """Caregiver-facing alert: drift trend or a same-day anomaly."""

    id: uuid.UUID = Field(default_factory=uuid.uuid4)
    patient_id: Annotated[uuid.UUID, Indexed()]
    alert_type: str  # cognitive_drift | anomaly
    severity: AlertSeverity = AlertSeverity.medium
    message: str
    resolved: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "alerts"


class BanditArmState(Document):
    """Per-patient, per-game UCB1 arm statistics for Pillar 1."""

    id: uuid.UUID = Field(default_factory=uuid.uuid4)
    patient_id: uuid.UUID
    game_type: str
    arm_key: str  # difficulty label, e.g. "3x2"
    pulls: int = 0
    total_reward: float = 0.0
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "bandit_arm_state"
        indexes = [
            IndexModel(
                [("patient_id", ASCENDING), ("game_type", ASCENDING), ("arm_key", ASCENDING)],
                unique=True,
            )
        ]
