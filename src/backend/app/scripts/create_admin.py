"""CLI script to bootstrap or reset an administrator account in Smriti Kunj.

Usage:
    python -m app.scripts.create_admin --email admin@smritikunj.org --password MyPassword123! --name "System Administrator"

If --password is not provided on the command line, it will securely prompt for one.
"""
import argparse
import asyncio
import getpass
import sys
import uuid

from motor.motor_asyncio import AsyncIOMotorClient
from beanie import init_beanie

from app.config import settings
from app.core.security import hash_password
from app.models.analytics import Alert, BanditArmState, DriftMetric
from app.models.audit import AdminAuditLog
from app.models.auth import OtpCode, RevokedToken
from app.models.care_plan import FamilyMember
from app.models.reminder import PatientReminder
from app.models.session import GameSession, VoiceInteraction
from app.models.user import DevicePairingToken, RoleEnum, User


async def create_admin(email: str, password: str, name: str) -> None:
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

    clean_email = email.strip().lower()
    user = await User.find_one(User.email == clean_email)

    if user:
        user.role = RoleEnum.admin
        user.name = name.strip() or user.name
        user.hashed_password = hash_password(password)
        user.status = "active"
        user.must_change_password = False
        await user.save()
        print(f"[SUCCESS] Updated existing account '{clean_email}' to role=admin (status=active).")
    else:
        new_admin = User(
            id=uuid.uuid4(),
            role=RoleEnum.admin,
            name=name.strip() or "System Administrator",
            email=clean_email,
            hashed_password=hash_password(password),
            region_language="bn",
            status="active",
            must_change_password=False,
        )
        await new_admin.insert()
        print(f"[SUCCESS] Created new admin user '{clean_email}' with id {new_admin.id}.")

    # Record bootstrap audit log
    audit = AdminAuditLog(
        actor_id=user.id if user else new_admin.id,
        actor_name="CLI Bootstrap",
        actor_email=clean_email,
        action="bootstrap_admin",
        target_type="admin",
        target_id=str(user.id if user else new_admin.id),
        target_name=name,
        details={"email": clean_email, "method": "cli_script"},
    )
    await audit.insert()


def main():
    parser = argparse.ArgumentParser(description="Create or update an admin user.")
    parser.add_argument("--email", default="admin@smritikunj.org", help="Admin email address")
    parser.add_argument("--password", default=None, help="Admin password (prompts securely if omitted)")
    parser.add_argument("--name", default="System Administrator", help="Admin full name")

    args = parser.parse_args()

    password = args.password
    if not password:
        password = getpass.getpass(f"Enter password for admin ({args.email}): ")
        confirm = getpass.getpass("Confirm password: ")
        if password != confirm:
            print("[ERROR] Passwords do not match.", file=sys.stderr)
            sys.exit(1)

    if len(password) < 8:
        print("[ERROR] Password must be at least 8 characters long.", file=sys.stderr)
        sys.exit(1)

    asyncio.run(create_admin(args.email, password, args.name))


if __name__ == "__main__":
    main()
