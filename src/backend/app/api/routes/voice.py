"""Pillar 2 direct-test endpoint. Production traffic normally arrives
bundled in POST /sync/batch alongside game session logs; this route exists
for debugging the NLU classifier in isolation."""
from fastapi import APIRouter, Depends

from app.core.nlu import classify
from app.core.security import get_current_user

router = APIRouter(prefix="/voice", tags=["voice"])


@router.post("/classify")
async def classify_transcript(transcript: str, user=Depends(get_current_user)):
    return classify(transcript)
