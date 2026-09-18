"""Pillar 2 (server-side half): intent + entity extraction.

Edge devices run VAD + STT locally (Whisper.cpp or a cloud STT API) and send
the resulting transcript here. This module extracts the {Task, Time, Status}
entities described in ARCHITECTURE.md. The keyword matcher below is a
placeholder — swap it for a fine-tuned intent classifier without touching
the API shape (callers only depend on `classify()`'s return dict).
"""
import re
from typing import Any, Dict

TASK_KEYWORDS = {
    "medication": ["medicine", "medication", "pill", "ওষুধ", "দৱা"],
    "meal": ["lunch", "dinner", "breakfast", "meal", "খাবার"],
    "exercise": ["walk", "exercise", "yoga", "ব্যায়াম"],
}

STATUS_KEYWORDS = {
    "complete": ["done", "finished", "took", "complete", "হয়ে গেছে"],
    "pending": ["not yet", "later", "forgot", "haven't"],
}

TIME_PATTERN = re.compile(r"\b([01]?\d|2[0-3]):([0-5]\d)\b")


def classify(transcript: str) -> Dict[str, Any]:
    text = (transcript or "").lower()

    task = next((t for t, kws in TASK_KEYWORDS.items() if any(k in text for k in kws)), None)
    status = next((s for s, kws in STATUS_KEYWORDS.items() if any(k in text for k in kws)), None)
    time_match = TIME_PATTERN.search(text)

    intent = "daily_check_in" if task else "reminiscence"
    confidence = 0.9 if task and status else 0.5

    return {
        "intent": intent,
        "entities": {
            "Task": task,
            "Time": time_match.group(0) if time_match else None,
            "Status": status,
        },
        "confidence": confidence,
    }
