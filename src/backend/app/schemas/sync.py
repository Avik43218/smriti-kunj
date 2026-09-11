from datetime import datetime
from typing import Any, Dict, List, Optional, Union

from pydantic import BaseModel


class GameSessionIn(BaseModel):
    client_session_id: str
    game_type: str
    difficulty_level: Union[str, int] = "1"
    accuracy: float
    avg_latency_ms: float
    error_rate: float
    client_timestamp: datetime
    domain: Optional[str] = None
    score_normalized: Optional[float] = None
    session_duration: Optional[Union[float, int]] = None
    status: Optional[str] = "completed"
    raw_payload: Optional[Dict[str, Any]] = None


class VoiceInteractionIn(BaseModel):
    client_session_id: str
    transcript: Optional[str] = None
    language: Optional[str] = "bn"
    client_timestamp: datetime


class SyncBatchIn(BaseModel):
    """The compressed, batched JSON payload array the edge app's background
    sync manager pushes once connectivity is restored."""

    patient_id: Optional[str] = None
    patient_code: Optional[str] = None
    game_sessions: List[GameSessionIn] = []
    voice_interactions: List[VoiceInteractionIn] = []


class SyncBatchOut(BaseModel):
    accepted_game_sessions: int
    accepted_voice_interactions: int
    alerts_triggered: int
