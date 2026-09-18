from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class DriftMetricOut(BaseModel):
    window_days: int
    slope: float
    intercept: float
    r_squared: Optional[float]
    sample_count: int
    computed_at: datetime

    class Config:
        from_attributes = True


class AlertOut(BaseModel):
    alert_type: str
    severity: str
    message: str
    resolved: bool
    created_at: datetime

    class Config:
        from_attributes = True
