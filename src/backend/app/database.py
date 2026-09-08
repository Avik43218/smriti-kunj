from motor.motor_asyncio import AsyncIOMotorClient
from beanie import init_beanie

from app.config import settings
from app.models.analytics import Alert, BanditArmState, DriftMetric
from app.models.auth import OtpCode, RevokedToken
from app.models.care_plan import FamilyMember
from app.models.reminder import PatientReminder
from app.models.session import GameSession, VoiceInteraction
from app.models.user import DevicePairingToken, User

_client: AsyncIOMotorClient | None = None


async def init_db() -> None:
    """Called once from the FastAPI startup event. Registers every Document
    model with Beanie and builds their declared indexes on the target DB."""
    global _client
    _client = AsyncIOMotorClient(settings.MONGODB_URL)
    await init_beanie(
        database=_client[settings.MONGODB_DB_NAME],
        document_models=[
            User,
            DevicePairingToken,
            OtpCode,
            RevokedToken,
            GameSession,
            VoiceInteraction,
            DriftMetric,
            Alert,
            BanditArmState,
            FamilyMember,
            PatientReminder,
        ],
    )
