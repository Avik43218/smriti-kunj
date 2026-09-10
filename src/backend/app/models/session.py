import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional, Union, Annotated

from beanie import Document, Indexed
from pydantic import Field


class GameSession(Document):
    """One document per completed cognitive-game round, synced up from the
    edge app's SQLite/IndexedDB queue. Feeds Pillar 1 (difficulty) and
    Pillar 3 (drift / anomaly detection)."""

    id: uuid.UUID = Field(default_factory=uuid.uuid4)
    patient_id: Annotated[Union[uuid.UUID, str], Indexed()]
    patient_profile_id: Optional[str] = None  # e.g. "p101"
    client_session_id: Annotated[str, Indexed(unique=True)]  # idempotency key for sync

    game_type: str  # pattern_matcher | pair_matching | word_association | visual_search
    domain: Optional[str] = None  # memory | language | attention
    difficulty_level: Union[str, int] = "1"

    accuracy: float = 0.0
    avg_latency_ms: float = 0.0
    error_rate: float = 0.0
    performance_score: Optional[float] = None  # computed S

    # Domain analytics parameters (GAMES_ANALYTICS_README.md)
    session_duration: Optional[Union[float, int]] = None
    status: str = "completed"  # completed | abandoned
    score_normalized: Optional[float] = None

    # Memory: Pair Matching
    correct_match_rate: Optional[float] = None
    total_flips: Optional[int] = None
    time_to_first_correct_match: Optional[float] = None
    repeat_error_rate: Optional[float] = None
    completion_time: Optional[Union[float, int]] = None
    pairs_count: Optional[int] = None
    used_face_name_variant: Optional[bool] = None

    # Language: Word Association
    words_recalled_count: Optional[int] = None
    response_latency_per_word: Optional[List[float]] = None
    category_switch_errors: Optional[int] = None
    language_used: Optional[str] = None
    category_prompt: Optional[str] = None
    round_duration: Optional[Union[float, int]] = None

    # Attention: Visual Search
    reaction_time_avg: Optional[Union[float, int]] = None
    reaction_time_variability: Optional[Union[float, int]] = None
    omission_rate: Optional[float] = None
    false_positive_rate: Optional[float] = None
    within_session_drift: Optional[float] = None
    trial_count: Optional[int] = None

    raw_trials: Optional[List[Dict[str, Any]]] = Field(default_factory=list)

    client_timestamp: datetime = Field(default_factory=datetime.utcnow)
    synced_at: datetime = Field(default_factory=datetime.utcnow)
    raw_payload: Optional[Dict[str, Any]] = None

    class Settings:
        name = "game_sessions"


class VoiceInteraction(Document):
    """One document per voice check-in / reminiscence exchange. transcript
    arrives from edge-side STT; intent/entities are filled in server-side
    by Pillar 2's NLU classifier at sync time."""

    id: uuid.UUID = Field(default_factory=uuid.uuid4)
    patient_id: Annotated[uuid.UUID, Indexed()]
    client_session_id: Annotated[str, Indexed(unique=True)]

    transcript: Optional[str] = None
    language: str = "bn"
    intent: Optional[str] = None
    entities: Optional[Dict[str, Any]] = None  # {Task, Time, Status}
    confidence: Optional[float] = None

    client_timestamp: datetime
    synced_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "voice_interactions"
