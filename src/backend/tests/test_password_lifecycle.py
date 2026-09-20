"""Unit tests for complete caregiver & admin password lifecycle:
1. Initial password setting (typed with min length validation vs auto-generated)
2. Forced change at first login (must_change_password blocks platform access)
3. Change password anytime (increments token_version, issues fresh JWT, revokes old token)
4. Forgot password flow (request OTP -> reset password with new token_version)
"""
import unittest
import uuid
from datetime import datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

from beanie import init_beanie
from fastapi import HTTPException
from jose import jwt

from app.api.routes import admin, auth
from app.config import settings
from app.core.otp import hash_otp
from app.core.security import (
    _create_token,
    create_caregiver_token,
    get_current_user,
    hash_password,
    require_admin,
    require_caregiver,
    verify_password,
)
from app.models.audit import AdminAuditLog
from app.models.auth import OtpCode, RevokedToken
from app.models.user import RoleEnum, User
from app.schemas.admin import CaregiverCreateAdminRequest, CaregiverResetPasswordRequest
from app.schemas.auth import (
    ChangePasswordRequest,
    ForgotPasswordRequest,
    ResetPasswordRequest,
)


class DummyCredentials:
    def __init__(self, token: str):
        self.credentials = token


class TestPasswordLifecycle(unittest.IsolatedAsyncioTestCase):

    async def asyncSetUp(self):
        db = MagicMock()
        db.command = AsyncMock(return_value={"version": "6.0.0", "versionArray": [6, 0]})
        db.list_collection_names = AsyncMock(return_value=[])
        mock_coll = MagicMock()
        mock_coll.create_index = AsyncMock()
        mock_coll.create_indexes = AsyncMock()
        mock_coll.index_information = AsyncMock(return_value={})
        mock_coll.insert_one = AsyncMock(side_effect=lambda doc, session=None: MagicMock(inserted_id=uuid.uuid4()))
        mock_coll.name = "mock"
        db.__getitem__.return_value = mock_coll
        await init_beanie(
            database=db,
            document_models=[User, OtpCode, RevokedToken, AdminAuditLog],
        )

        self.admin = User(
            id=uuid.uuid4(),
            role=RoleEnum.admin,
            name="Admin System",
            email="admin@smritikunj.org",
            hashed_password=hash_password("admin123!A"),
            status="active",
            token_version=1,
            must_change_password=False,
        )

        self.caregiver = User(
            id=uuid.uuid4(),
            role=RoleEnum.caregiver,
            name="Nurse Keya",
            email="keya@example.com",
            hashed_password=hash_password("TempPass123!"),
            status="active",
            token_version=1,
            must_change_password=True,
        )

    # ---- 1. Initial Password Setting & Admin Validation ----

    async def test_admin_create_caregiver_typed_password_validation(self):
        """Typing a password less than 8 characters must fail validation."""
        with self.assertRaises(ValueError):
            CaregiverCreateAdminRequest(
                name="Test Caregiver",
                email="short@example.com",
                password="short",  # < 8 chars
            )

    @patch("app.models.user.User.find_one", new_callable=AsyncMock)
    @patch("app.models.user.User.insert", new_callable=AsyncMock)
    @patch("app.models.audit.AdminAuditLog.insert", new_callable=AsyncMock)
    async def test_admin_create_caregiver_auto_generated(self, mock_audit, mock_insert, mock_find_one):
        """Leaving password blank generates secure temp password and sets must_change_password=True."""
        mock_find_one.return_value = None  # no existing email
        req = CaregiverCreateAdminRequest(
            name="Auto Generated Caregiver",
            email="auto@example.com",
            password=None,
        )
        res = await admin.create_caregiver(req, admin_user=self.admin)
        self.assertTrue(res.must_change_password)
        self.assertIsNotNone(res.temporary_password)
        self.assertGreaterEqual(len(res.temporary_password), 12)

    # ---- 2. Forced Change at First Login ----

    async def test_must_change_password_blocks_platform_access(self):
        """Caregivers with must_change_password=True are blocked from protected routes."""
        with self.assertRaises(HTTPException) as ctx:
            await require_caregiver(self.caregiver)
        self.assertEqual(ctx.exception.status_code, 403)
        self.assertIn("Password change required", ctx.exception.detail)

    async def test_must_change_password_blocks_admin_routes(self):
        """Admins with must_change_password=True are blocked from require_admin."""
        self.admin.must_change_password = True
        with self.assertRaises(HTTPException) as ctx:
            await require_admin(self.admin)
        self.assertEqual(ctx.exception.status_code, 403)
        self.assertIn("Password change required", ctx.exception.detail)

    # ---- 3. Change Password, Token Versioning & Invalidation ----

    @patch("app.models.user.User.save", new_callable=AsyncMock)
    async def test_change_password_increments_token_version_and_returns_fresh_jwt(self, mock_save):
        """change_password updates hash, unsets must_change_password, increments token_version, and returns new JWT."""
        req = ChangePasswordRequest(
            current_password="TempPass123!",
            new_password="NewSecurePassword2026!",
        )
        res = await auth.change_password(req, user=self.caregiver)

        self.assertFalse(res.must_change_password)
        self.assertEqual(self.caregiver.token_version, 2)
        self.assertFalse(self.caregiver.must_change_password)
        self.assertTrue(verify_password("NewSecurePassword2026!", self.caregiver.hashed_password))
        self.assertIsNotNone(res.token)

        # Decode fresh token and check token_version claim
        payload = jwt.decode(res.token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        self.assertEqual(payload.get("ver"), 2)
        self.assertFalse(payload.get("must_change_password"))

    @patch("app.models.user.User.get", new_callable=AsyncMock)
    @patch("app.models.user.User.find_one", new_callable=AsyncMock)
    @patch("app.models.auth.RevokedToken.find_one", new_callable=AsyncMock)
    async def test_old_token_version_is_rejected_on_get_current_user(self, mock_revoked, mock_find, mock_get):
        """An older token with ver=1 is rejected if user's token_version is now 2."""
        mock_revoked.return_value = None
        mock_get.return_value = self.caregiver
        mock_find.return_value = self.caregiver

        # Set user's database version to 2
        self.caregiver.token_version = 2

        # Create token with older version 1
        old_token = _create_token(
            user_id=self.caregiver.id,
            role=self.caregiver.role,
            expires_delta=timedelta(minutes=30),
            token_version=1,
        )

        with self.assertRaises(HTTPException) as ctx:
            await get_current_user(DummyCredentials(old_token))
        self.assertEqual(ctx.exception.status_code, 401)
        self.assertIn("Session expired due to password change", ctx.exception.detail)

    # ---- 4. Forgot Password & Reset Password Flow ----

    @patch("app.models.user.User.find_one", new_callable=AsyncMock)
    @patch("app.models.auth.OtpCode.find", new_callable=MagicMock)
    @patch("app.models.auth.OtpCode.insert", new_callable=AsyncMock)
    @patch("app.services.email_service.send_otp_email", new_callable=AsyncMock)
    async def test_forgot_password_issues_otp(self, mock_email, mock_otp_insert, mock_otp_find, mock_find_user):
        """forgot_password issues OTP for active registered caregiver."""
        mock_find_user.return_value = self.caregiver
        mock_delete = AsyncMock()
        mock_otp_find.return_value.delete = mock_delete

        req = ForgotPasswordRequest(email="keya@example.com")
        res = await auth.forgot_password(req)

        self.assertIn("verification code has been sent", res.message)
        mock_otp_insert.assert_called_once()

    @patch("app.models.user.User.find_one", new_callable=AsyncMock)
    @patch("app.models.auth.OtpCode.find_one", new_callable=AsyncMock)
    @patch("app.models.auth.OtpCode.delete", new_callable=AsyncMock)
    @patch("app.models.user.User.save", new_callable=AsyncMock)
    async def test_reset_password_with_valid_otp(self, mock_save, mock_delete_otp, mock_find_otp, mock_find_user):
        """reset_password validates OTP, sets new password, increments token_version, unsets must_change_password."""
        otp_code = "654321"
        otp_doc = OtpCode(
            email="keya@example.com",
            otp_hash=hash_otp(otp_code),
            expires_at=datetime.utcnow() + timedelta(minutes=10),
            attempts=0,
        )
        mock_find_user.return_value = self.caregiver
        mock_find_otp.return_value = otp_doc

        req = ResetPasswordRequest(
            email="keya@example.com",
            otp=otp_code,
            new_password="NewlyResetPassword999!",
        )
        res = await auth.reset_password(req)

        self.assertIn("Password has been reset successfully", res.message)
        self.assertEqual(self.caregiver.token_version, 2)
        self.assertFalse(self.caregiver.must_change_password)
        self.assertTrue(verify_password("NewlyResetPassword999!", self.caregiver.hashed_password))
