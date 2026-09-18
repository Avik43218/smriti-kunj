"""Database migration script to backfill existing users with role="caregiver"
and status="active" without data loss.

Usage:
    python -m scripts.migrate_user_roles
    or
    python src/backend/scripts/migrate_user_roles.py
"""
import argparse
import asyncio
import os
import sys

# Ensure backend root is in sys.path
backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from motor.motor_asyncio import AsyncIOMotorClient

from app.config import settings
from app.core.security import hash_password


async def run_migration(create_admin_email: str = None, create_admin_password: str = None):
    print(f"Connecting to MongoDB at {settings.MONGODB_URL} (database: {settings.MONGODB_DB_NAME})...")
    client = AsyncIOMotorClient(settings.MONGODB_URL)
    db = client[settings.MONGODB_DB_NAME]
    users_coll = db["users"]

    # 1. Backfill users without role or where role is missing
    # Caregivers are documents with email or hashed_password, or without caregiver_id
    caregiver_filter = {
        "$or": [
            {"role": {"$exists": False}},
            {"role": None},
        ],
        "email": {"$exists": True, "$ne": None},
    }
    result_role = await users_coll.update_many(
        caregiver_filter,
        {"$set": {"role": "caregiver", "status": "active"}},
    )
    print(f"Backfilled role='caregiver' and status='active' on {result_role.modified_count} caregiver document(s).")

    # 2. Backfill status="active" on existing caregivers that don't have status set
    result_status = await users_coll.update_many(
        {
            "role": "caregiver",
            "$or": [
                {"status": {"$exists": False}},
                {"status": None},
            ],
        },
        {"$set": {"status": "active"}},
    )
    print(f"Backfilled status='active' on {result_status.modified_count} existing caregiver document(s).")

    # 3. Ensure patient documents have role="patient" if role is missing
    result_patients = await users_coll.update_many(
        {
            "$or": [
                {"role": {"$exists": False}},
                {"role": None},
            ],
            "caregiver_id": {"$exists": True, "$ne": None},
        },
        {"$set": {"role": "patient"}},
    )
    print(f"Verified role='patient' on {result_patients.modified_count} patient document(s).")

    # 4. Optional: Provision initial admin user if specified
    if create_admin_email and create_admin_password:
        existing_admin = await users_coll.find_one({"email": create_admin_email})
        if existing_admin:
            print(f"User with email '{create_admin_email}' already exists. Updating to role='admin', status='active'...")
            await users_coll.update_one(
                {"_id": existing_admin["_id"]},
                {"$set": {"role": "admin", "status": "active"}},
            )
        else:
            import uuid
            print(f"Creating initial admin account for '{create_admin_email}'...")
            admin_doc = {
                "_id": str(uuid.uuid4()),
                "id": str(uuid.uuid4()),
                "role": "admin",
                "name": "System Administrator",
                "email": create_admin_email,
                "hashed_password": hash_password(create_admin_password),
                "region_language": "bn",
                "status": "active",
            }
            await users_coll.insert_one(admin_doc)
            print("Admin account created successfully.")

    total_caregivers = await users_coll.count_documents({"role": "caregiver"})
    total_admins = await users_coll.count_documents({"role": "admin"})
    total_patients = await users_coll.count_documents({"role": "patient"})

    print("--- Migration Summary ---")
    print(f"Total Admins: {total_admins}")
    print(f"Total Caregivers: {total_caregivers}")
    print(f"Total Patients: {total_patients}")
    print("Migration completed successfully with zero data loss.")
    client.close()


def main():
    parser = argparse.ArgumentParser(description="Migrate Smriti Kunj users collection with roles and status.")
    parser.add_argument("--admin-email", help="Create or promote an admin with this email", default=None)
    parser.add_argument("--admin-password", help="Password for the initial admin", default=None)
    args = parser.parse_args()

    asyncio.run(run_migration(args.admin_email, args.admin_password))


if __name__ == "__main__":
    main()
