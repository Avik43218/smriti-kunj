from motor.motor_asyncio import AsyncIOMotorClient
from beanie import init_beanie

from app.config import settings
from app.core.security import hash_password
from app.models.analytics import Alert, BanditArmState, DriftMetric
from app.models.auth import OtpCode, RevokedToken
from app.models.care_plan import FamilyMember
from app.models.reminder import PatientReminder
from app.models.session import GameSession, VoiceInteraction
from app.models.user import DevicePairingToken, RoleEnum, User

_client: AsyncIOMotorClient | None = None


async def seed_initial_admin() -> None:
    """Ensure at least one admin account exists on startup.
    Creates default admin: admin@smritikunj.org / admin123 if not present."""
    try:
        admin = await User.find_one(User.role == RoleEnum.admin)
        if not admin:
            existing = await User.find_one(User.email == "admin@smritikunj.org")
            if existing:
                existing.role = RoleEnum.admin
                existing.status = "active"
                if not existing.hashed_password:
                    existing.hashed_password = hash_password("admin123")
                await existing.save()
            else:
                admin_user = User(
                    role=RoleEnum.admin,
                    name="System Administrator",
                    email="admin@smritikunj.org",
                    hashed_password=hash_password("admin123"),
                    region_language="bn",
                    status="active",
                )
                await admin_user.insert()

            print("\n" + "=" * 60, flush=True)
            print(" [ADMIN INITIALIZATION] Seeded default administrator account:", flush=True)
            print(" Email: admin@smritikunj.org | Password: admin123", flush=True)
            print("=" * 60 + "\n", flush=True)
    except Exception as err:
        print(f"[warning] could not seed admin user: {err}", flush=True)


async def init_db() -> None:
    """Called once from the FastAPI startup event. Registers every Document
    model with Beanie and builds their declared indexes on the target DB."""
    global _client
    _client = AsyncIOMotorClient(settings.MONGODB_URL)

    # Clean up legacy indexes on users collection that index null values
    try:
        db = _client[settings.MONGODB_DB_NAME]
        users_coll = db["users"]
        indexes = await users_coll.index_information()
        for idx_name, idx_info in indexes.items():
            if idx_name == "_id_":
                continue
            key_fields = [k for k, _ in idx_info.get("key", [])]
            if any(f in ["device_id", "email", "patient_code", "pairing_token"] for f in key_fields):
                # If it lacks partialFilterExpression, it indexes nulls and must be dropped
                if "partialFilterExpression" not in idx_info:
                    print(f"[DB migration] Dropping legacy index '{idx_name}' on users collection...", flush=True)
                    await users_coll.drop_index(idx_name)
    except Exception as err:
        print(f"[warning] could not check or drop legacy indexes: {err}", flush=True)

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
    await seed_initial_admin()
