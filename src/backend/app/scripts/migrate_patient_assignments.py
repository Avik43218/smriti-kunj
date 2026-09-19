"""One-off / idempotent migration script:
Copies patient `caregiver_id` into `assigned_caregiver_ids` so no existing caregivers
lose access when transitioning to the many-to-many model.

Usage:
    python -m app.scripts.migrate_patient_assignments
"""
import asyncio

from motor.motor_asyncio import AsyncIOMotorClient
from beanie import init_beanie

from app.config import settings
from app.models.analytics import Alert, BanditArmState, DriftMetric
from app.models.audit import AdminAuditLog
from app.models.auth import OtpCode, RevokedToken
from app.models.care_plan import FamilyMember
from app.models.reminder import PatientReminder
from app.models.session import GameSession, VoiceInteraction
from app.models.user import DevicePairingToken, RoleEnum, User


async def migrate() -> None:
    client = AsyncIOMotorClient(settings.MONGODB_URL)
    await init_beanie(
        database=client[settings.MONGODB_DB_NAME],
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
            AdminAuditLog,
        ],
    )

    patients = await User.find(User.role == RoleEnum.patient).to_list()
    print(f"Found {len(patients)} patient record(s) to inspect...")

    migrated_count = 0
    for p in patients:
        changed = False
        current_assigned = list(p.assigned_caregiver_ids or [])

        # If caregiver_id is populated and not yet in assigned_caregiver_ids, append it
        if p.caregiver_id and p.caregiver_id not in current_assigned:
            current_assigned.append(p.caregiver_id)
            p.assigned_caregiver_ids = current_assigned
            changed = True

        if getattr(p, "status", None) is None:
            p.status = "stable"
            changed = True

        if changed:
            await p.save()
            migrated_count += 1
            print(f"  -> Migrated patient '{p.name}' ({p.patient_code or p.id}) with {len(current_assigned)} assigned caregiver(s).")

    print(f"[SUCCESS] Finished patient assignments migration: {migrated_count} patient(s) updated.")


if __name__ == "__main__":
    asyncio.run(migrate())
