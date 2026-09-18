"""Pillar 1 read endpoint: what should the patient play next."""
from fastapi import APIRouter, Depends

from app.core.bandit import next_difficulty
from app.core.security import require_patient
from app.models.session import GameSession
from app.models.user import User
from app.services.difficulty_service import recommend_difficulty

router = APIRouter(prefix="/difficulty", tags=["difficulty"])


@router.get("/next/{game_type}")
async def get_next_difficulty(game_type: str, patient: User = Depends(require_patient)):
    """Combines the UCB1 arm recommendation with the threshold rules (grid
    scaling, timer, distractors) from ARCHITECTURE.md Pillar 1."""
    recommended_arm = await recommend_difficulty(patient.id, game_type)

    last = (
        await GameSession.find(
            GameSession.patient_id == patient.id, GameSession.game_type == game_type
        )
        .sort("-client_timestamp")
        .first_or_none()
    )
    last_score = last.performance_score if last and last.performance_score is not None else 0.5

    return next_difficulty(current_grid=recommended_arm, score=last_score, distractors_on=False)
