"""Shared authentication and authorization dependencies."""
from app.core.security import (
    bearer_scheme,
    get_current_user,
    require_admin,
    require_caregiver,
    require_patient,
)

__all__ = [
    "bearer_scheme",
    "get_current_user",
    "require_admin",
    "require_caregiver",
    "require_patient",
]
