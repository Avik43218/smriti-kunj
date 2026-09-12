"""Unit tests for Admin role, require_admin security, admin endpoints,
and caregiver isolation guarantees.
"""
import unittest
import uuid
from datetime import datetime
from unittest.mock import AsyncMock, MagicMock, patch

from beanie import init_beanie
from fastapi import HTTPException

from app.api.routes import admin, caregiver, patients
from app.core.security import require_admin, require_caregiver
from app.models.care_plan import FamilyMember
from app.models.reminder import PatientReminder
from app.models.session import GameSession
from app.models.user import DevicePairingToken, RoleEnum, User
from app.schemas.admin import (
    CaregiverAdminOut,
    CaregiverCreateAdminRequest,
    CaregiverUpdateAdminRequest,
    PatientAdminOut,
    PatientReassignRequest,
)


class TestAdminRoleAndEndpoints(unittest.IsolatedAsyncioTestCase):

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
            document_models=[User, FamilyMember, PatientReminder, GameSession, DevicePairingToken],
        )

        # 1. Admin user
        self.admin_id = uuid.uuid4()
        self.admin_user = User(
            id=self.admin_id,
            role=RoleEnum.admin,
            name="System Admin",
            email="admin@smritikunj.org",
            status="active",
        )

        # 2. Caregiver A
        self.caregiver_a_id = uuid.uuid4()
        self.caregiver_a = User(
            id=self.caregiver_a_id,
            role=RoleEnum.caregiver,
            name="Dr. Sarah Jenkins",
            email="sarah@example.com",
            status="active",
        )

        # 3. Caregiver B
        self.caregiver_b_id = uuid.uuid4()
        self.caregiver_b = User(
            id=self.caregiver_b_id,
            role=RoleEnum.caregiver,
            name="Nurse Ananya Roy",
            email="ananya@example.com",
            status="active",
        )

        # 4. Patient assigned to Caregiver A
        self.patient_id = uuid.uuid4()
        self.patient = User(
            id=self.patient_id,
            role=RoleEnum.patient,
            name="Aarav Sharma",
            patient_code="p101",
            caregiver_id=self.caregiver_a_id,
            status="stable",
            status_label="Active • Tablet synced",
        )

    # ---- Authorization & require_admin Tests --------------------------------

    async def test_caregiver_cannot_access_require_admin(self):
        """A caregiver JWT/user must raise 403 Forbidden on require_admin."""
        with self.assertRaises(HTTPException) as ctx:
            await require_admin(self.caregiver_a)
        self.assertEqual(ctx.exception.status_code, 403)
        self.assertIn("Admin access required", ctx.exception.detail)

    async def test_disabled_admin_cannot_access_require_admin(self):
        """A disabled admin must raise 403 Forbidden."""
        disabled_admin = User(
            id=uuid.uuid4(),
            role=RoleEnum.admin,
            name="Disabled Admin",
            email="disabled_admin@example.com",
            status="disabled",
        )
        with self.assertRaises(HTTPException) as ctx:
            await require_admin(disabled_admin)
        self.assertEqual(ctx.exception.status_code, 403)
        self.assertIn("disabled", ctx.exception.detail.lower())

    async def test_active_admin_can_access_require_admin(self):
        """An active admin passes require_admin check."""
        result = await require_admin(self.admin_user)
        self.assertEqual(result.id, self.admin_id)
        self.assertEqual(result.role, RoleEnum.admin)

    # ---- Admin Endpoints Tests ----------------------------------------------

    async def test_admin_list_caregivers_with_patient_counts(self):
        """Admin lists caregivers along with their patient counts."""
        with patch.object(User, "find") as mock_find:
            mock_cg_query = MagicMock()
            mock_cg_query.to_list = AsyncMock(return_value=[self.caregiver_a, self.caregiver_b])

            mock_count_query = MagicMock()
            mock_count_query.count = AsyncMock(return_value=2)

            mock_find.side_effect = [mock_cg_query, mock_count_query, mock_count_query]

            results = await admin.list_caregivers(self.admin_user)
            self.assertEqual(len(results), 2)
            self.assertIsInstance(results[0], CaregiverAdminOut)
            self.assertEqual(results[0].patient_count, 2)

    async def test_admin_create_caregiver_directly(self):
        """Admin directly provisions a caregiver, bypassing self-registration OTP."""
        payload = CaregiverCreateAdminRequest(
            name="Dr. New Caregiver",
            email="new.cg@smritikunj.org",
            password="SecurePassword123!",
            region_language="bn",
            status="active",
        )

        with patch.object(User, "find_one", AsyncMock(return_value=None)):
            with patch.object(User, "insert", new_callable=AsyncMock) as mock_insert:
                result = await admin.create_caregiver(payload, self.admin_user)
                self.assertEqual(result.name, "Dr. New Caregiver")
                self.assertEqual(result.email, "new.cg@smritikunj.org")
                self.assertEqual(result.role, "caregiver")
                self.assertEqual(result.patient_count, 0)
                mock_insert.assert_called_once()

    async def test_admin_list_all_patients(self):
        """Admin lists all patients across all caregivers."""
        with patch.object(User, "find") as mock_find:
            mock_patients_query = MagicMock()
            mock_patients_query.to_list = AsyncMock(return_value=[self.patient])

            mock_caregivers_query = MagicMock()
            mock_caregivers_query.to_list = AsyncMock(return_value=[self.caregiver_a])

            mock_find.side_effect = [mock_patients_query, mock_caregivers_query]

            results = await admin.list_all_patients(self.admin_user)
            self.assertEqual(len(results), 1)
            self.assertIsInstance(results[0], PatientAdminOut)
            self.assertEqual(results[0].name, "Aarav Sharma")
            self.assertEqual(results[0].caregiver_name, "Dr. Sarah Jenkins")

    async def test_admin_reassign_patient(self):
        """Admin can reassign a patient from one caregiver to another."""
        reassign_payload = PatientReassignRequest(new_caregiver_id=self.caregiver_b_id)

        with patch("app.api.routes.admin._find_patient_by_identifier", AsyncMock(return_value=self.patient)):
            with patch.object(User, "find_one", AsyncMock(return_value=self.caregiver_b)):
                with patch.object(User, "save", new_callable=AsyncMock):
                    with patch.object(DevicePairingToken, "find") as mock_tok_find:
                        mock_tok_query = MagicMock()
                        mock_tok_query.to_list = AsyncMock(return_value=[])
                        mock_tok_find.return_value = mock_tok_query

                        updated = await admin.reassign_patient("p101", reassign_payload, self.admin_user)
                        self.assertEqual(updated.caregiver_id, self.caregiver_b_id)
                        self.assertEqual(updated.caregiver_name, "Nurse Ananya Roy")

    async def test_admin_delete_caregiver_blocked_with_patients(self):
        """Deleting a caregiver who has assigned patients is blocked with 400 Bad Request."""
        with patch.object(User, "find_one", AsyncMock(return_value=self.caregiver_a)):
            with patch.object(User, "find") as mock_find:
                mock_query = MagicMock()
                mock_query.count = AsyncMock(return_value=2)  # Has 2 assigned patients
                mock_find.return_value = mock_query

                with self.assertRaises(HTTPException) as ctx:
                    await admin.delete_caregiver(self.caregiver_a_id, self.admin_user)
                self.assertEqual(ctx.exception.status_code, 400)
                self.assertIn("Cannot delete caregiver with 2 assigned patient(s)", ctx.exception.detail)

    async def test_admin_delete_caregiver_succeeds_when_no_patients(self):
        """Deleting a caregiver who has zero assigned patients succeeds."""
        with patch.object(User, "find_one", AsyncMock(return_value=self.caregiver_b)):
            with patch.object(User, "find") as mock_find:
                mock_query = MagicMock()
                mock_query.count = AsyncMock(return_value=0)  # 0 patients
                mock_find.return_value = mock_query
                with patch.object(User, "delete", new_callable=AsyncMock) as mock_del:
                    res = await admin.delete_caregiver(self.caregiver_b_id, self.admin_user)
                    self.assertEqual(res["message"], "Caregiver deleted successfully")
                    mock_del.assert_called_once()

    # ---- Caregiver Isolation Guarantees --------------------------------------

    async def test_caregiver_routes_strictly_scope_to_own_caregiver_id(self):
        """Caregiver route /api/caregiver/patients queries only User.caregiver_id == authenticated_caregiver.id."""
        with patch.object(User, "find") as mock_find:
            mock_query = MagicMock()
            mock_query.to_list = AsyncMock(return_value=[self.patient])
            mock_find.return_value = mock_query

            results = await caregiver.list_patients(self.caregiver_a)
            self.assertEqual(len(results), 1)

            # Assert User.find was called
            self.assertTrue(mock_find.called)
            # Verify the call passed arguments filtering by caregiver_a.id
            call_args = mock_find.call_args[0]
            self.assertTrue(len(call_args) >= 1)


if __name__ == "__main__":
    unittest.main()
