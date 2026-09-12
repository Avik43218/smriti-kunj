"""Unit tests for role-based authentication, terminal OTP verification, and admin seeding."""
import io
import sys
import unittest
import uuid
from datetime import datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

from beanie import init_beanie
from fastapi import HTTPException

from app.api.routes import auth
from app.core.security import hash_password, _create_token
from app.database import seed_initial_admin
from app.models.auth import OtpCode, RevokedToken
from app.models.user import RoleEnum, User
from app.schemas.auth import LoginRequest, OtpVerifyRequest


class TestAuthRolesAndOtp(unittest.IsolatedAsyncioTestCase):

    async def asyncSetUp(self):
        db = MagicMock()
        db.command = AsyncMock(return_value={"version": "6.0.0", "versionArray": [6, 0]})
        db.list_collection_names = AsyncMock(return_value=[])
        mock_coll = MagicMock()
        mock_coll.create_index = AsyncMock()
        mock_coll.create_indexes = AsyncMock()
        mock_coll.index_information = AsyncMock(return_value={})
        mock_coll.name = "mock"
        db.__getitem__.return_value = mock_coll
        await init_beanie(
            database=db,
            document_models=[User, OtpCode, RevokedToken],
        )

        self.caregiver_user = User(
            id=uuid.uuid4(),
            role=RoleEnum.caregiver,
            name="Caregiver Jane",
            email="caregiver@example.com",
            hashed_password=hash_password("caregiverPass123"),
            status="active",
            region_language="bn",
        )

        self.admin_user = User(
            id=uuid.uuid4(),
            role=RoleEnum.admin,
            name="Admin John",
            email="admin@smritikunj.org",
            hashed_password=hash_password("adminPass123"),
            status="active",
            region_language="bn",
        )

    async def test_caregiver_login_issues_otp_and_prints_to_terminal(self):
        with patch.object(User, "find_one", new_callable=AsyncMock) as mock_user_find, \
             patch.object(OtpCode, "find") as mock_otp_find, \
             patch.object(OtpCode, "insert", new_callable=AsyncMock) as mock_otp_insert:

            mock_user_find.return_value = self.caregiver_user
            mock_delete_query = MagicMock()
            mock_delete_query.delete = AsyncMock()
            mock_otp_find.return_value = mock_delete_query

            captured_out = io.StringIO()
            with patch("sys.stdout", captured_out):
                req = LoginRequest(
                    email="caregiver@example.com",
                    password="caregiverPass123",
                    role="caregiver",
                )
                res = await auth.login(req)

            self.assertEqual(res.email, "caregiver@example.com")
            output = captured_out.getvalue()
            self.assertIn("SMRITI KUNJ OTP VERIFICATION", output)
            self.assertIn("caregiver@example.com", output)
            self.assertIn("One-Time Password (OTP):", output)
            mock_otp_insert.assert_called_once()

    async def test_admin_login_issues_otp_and_prints_to_terminal(self):
        with patch.object(User, "find_one", new_callable=AsyncMock) as mock_user_find, \
             patch.object(OtpCode, "find") as mock_otp_find, \
             patch.object(OtpCode, "insert", new_callable=AsyncMock) as mock_otp_insert:

            mock_user_find.return_value = self.admin_user
            mock_delete_query = MagicMock()
            mock_delete_query.delete = AsyncMock()
            mock_otp_find.return_value = mock_delete_query

            captured_out = io.StringIO()
            with patch("sys.stdout", captured_out):
                req = LoginRequest(
                    email="admin@smritikunj.org",
                    password="adminPass123",
                    role="admin",
                )
                res = await auth.login(req)

            self.assertEqual(res.email, "admin@smritikunj.org")
            output = captured_out.getvalue()
            self.assertIn("SMRITI KUNJ OTP VERIFICATION", output)
            self.assertIn("admin@smritikunj.org", output)
            mock_otp_insert.assert_called_once()

    async def test_login_role_mismatch_raises_403(self):
        with patch.object(User, "find_one", new_callable=AsyncMock) as mock_user_find:
            mock_user_find.return_value = self.caregiver_user

            req = LoginRequest(
                email="caregiver@example.com",
                password="caregiverPass123",
                role="admin",  # Requesting admin, but account is caregiver
            )
            with self.assertRaises(HTTPException) as ctx:
                await auth.login(req)
            self.assertEqual(ctx.exception.status_code, 403)
            self.assertIn("registered as a caregiver", ctx.exception.detail)

    async def test_login_wrong_password_raises_401(self):
        with patch.object(User, "find_one", new_callable=AsyncMock) as mock_user_find:
            mock_user_find.return_value = self.caregiver_user

            req = LoginRequest(
                email="caregiver@example.com",
                password="wrongPassword",
            )
            with self.assertRaises(HTTPException) as ctx:
                await auth.login(req)
            self.assertEqual(ctx.exception.status_code, 401)

    async def test_verify_otp_caregiver_returns_caregiver_session(self):
        from app.core.otp import hash_otp
        mock_otp = OtpCode(
            email="caregiver@example.com",
            otp_hash=hash_otp("123456"),
            expires_at=datetime.utcnow() + timedelta(minutes=10),
            attempts=0,
        )

        with patch.object(User, "find_one", new_callable=AsyncMock) as mock_user_find, \
             patch.object(OtpCode, "find_one", new_callable=AsyncMock) as mock_otp_find, \
             patch.object(OtpCode, "delete", new_callable=AsyncMock):

            mock_user_find.return_value = self.caregiver_user
            mock_otp_find.return_value = mock_otp

            req = OtpVerifyRequest(email="caregiver@example.com", otp="123456")
            res = await auth.verify_otp(req)

            self.assertTrue(res.token)
            self.assertEqual(res.caregiver.role, "caregiver")
            self.assertEqual(res.caregiver.email, "caregiver@example.com")
            self.assertIsNotNone(res.user)
            self.assertEqual(res.user.role, "caregiver")

    async def test_verify_otp_admin_returns_admin_session(self):
        from app.core.otp import hash_otp
        mock_otp = OtpCode(
            email="admin@smritikunj.org",
            otp_hash=hash_otp("654321"),
            expires_at=datetime.utcnow() + timedelta(minutes=10),
            attempts=0,
        )

        with patch.object(User, "find_one", new_callable=AsyncMock) as mock_user_find, \
             patch.object(OtpCode, "find_one", new_callable=AsyncMock) as mock_otp_find, \
             patch.object(OtpCode, "delete", new_callable=AsyncMock):

            mock_user_find.return_value = self.admin_user
            mock_otp_find.return_value = mock_otp

            req = OtpVerifyRequest(email="admin@smritikunj.org", otp="654321")
            res = await auth.verify_otp(req)

            self.assertTrue(res.token)
            self.assertEqual(res.caregiver.role, "admin")
            self.assertEqual(res.caregiver.email, "admin@smritikunj.org")
            self.assertIsNotNone(res.user)
            self.assertEqual(res.user.role, "admin")

    async def test_seed_initial_admin_creates_admin_if_none_exists(self):
        with patch.object(User, "find_one", new_callable=AsyncMock) as mock_user_find, \
             patch.object(User, "insert", new_callable=AsyncMock) as mock_insert:

            mock_user_find.return_value = None

            await seed_initial_admin()
            mock_insert.assert_called_once()


if __name__ == "__main__":
    unittest.main()
