"""Unit and integration tests for all API endpoints in API_ENDPOINTS_NEEDED.md:
- GET /api/caregiver/patients
- POST /api/caregiver/patients
- GET /api/caregiver/patients/{id}
- GET /api/patients/{patientId}/family-members
- POST /api/patients/{patientId}/family-members
- GET /api/patients/{patientId}/reminders
- PUT /api/patients/{patientId}/reminders/{category}
- POST /api/patients/{patientId}/reminders/custom
- GET /api/patients/{patientId}/game-sessions
"""
from datetime import datetime
import unittest
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

from fastapi import HTTPException
from beanie import init_beanie

from app.api.routes import auth, caregiver, patients
from app.models.care_plan import FamilyMember
from app.models.reminder import PatientReminder
from app.models.session import GameSession
from app.models.user import DevicePairingToken, RoleEnum, User
from app.schemas.auth import PatientPairCompleteRequest
from app.schemas.patient import (
    CustomReminderCreate,
    FamilyMemberCreate,
    PatientCreateRequest,
    PatientDetailOut,
    PatientSummaryOut,
)


class TestCaregiverAndPatientEndpoints(unittest.IsolatedAsyncioTestCase):

    async def asyncSetUp(self):
        db = MagicMock()
        db.command = AsyncMock(return_value={"version": "6.0.0", "versionArray": [6, 0]})
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

        self.caregiver_id = uuid.uuid4()
        self.caregiver_user = User(
            id=self.caregiver_id,
            role=RoleEnum.caregiver,
            name="Dr. Sarah Jenkins",
            email="caregiver@example.com",
        )
        self.patient_id = uuid.uuid4()
        self.patient_user = User(
            id=self.patient_id,
            role=RoleEnum.patient,
            name="Aarav Sharma",
            patient_code="p101",
            caregiver_id=self.caregiver_id,
            age=72,
            gender="Male",
            date_of_birth="March 14, 1954",
            diagnosis="Mild Cognitive Impairment",
            health_issue="Mild Cognitive Impairment (MCI)",
            status="stable",
            status_label="Active • Tablet synced",
            last_check_in="Today, 10:30 AM",
            emergency_contact={"name": "Priya Sharma", "relationship": "Daughter", "phone": "+91 98765 43210"},
            device_status={"linked": True, "deviceName": "Lenovo Tab M10", "deviceId": "DEV-101", "lastSynced": "Today, 10:30 AM"},
        )

    # ---- Caregiver Endpoints ------------------------------------------------

    async def test_list_patients_returns_roster(self):
        with patch.object(User, "find") as mock_find:
            mock_query = MagicMock()
            mock_query.to_list = AsyncMock(return_value=[self.patient_user])
            mock_find.return_value = mock_query

            results = await caregiver.list_patients(self.caregiver_user)
            self.assertEqual(len(results), 1)
            self.assertIsInstance(results[0], PatientSummaryOut)
            self.assertEqual(results[0].id, "p101")
            self.assertEqual(results[0].name, "Aarav Sharma")
            self.assertEqual(results[0].status, "stable")

    async def test_list_patients_empty_when_no_patients(self):
        with patch.object(User, "find") as mock_find:
            mock_query = MagicMock()
            mock_query.to_list = AsyncMock(return_value=[])
            mock_find.return_value = mock_query

            results = await caregiver.list_patients(self.caregiver_user)
            self.assertEqual(len(results), 0)

    async def test_register_patient_endpoint(self):
        with patch.object(User, "find_one", new_callable=AsyncMock) as mock_find_one:
            mock_find_one.return_value = None
            with patch.object(User, "insert", new_callable=AsyncMock) as mock_insert:
                payload = PatientCreateRequest(
                    id="p521",
                    name="Maya Sen",
                    age=68,
                    gender="Female",
                    diagnosis="Early Stage Alzheimer's",
                )
                res = await caregiver.register_patient(payload, self.caregiver_user)
                self.assertEqual(res.id, "p521")
                self.assertEqual(res.name, "Maya Sen")
                mock_insert.assert_called_once()

    async def test_get_patient_detail_success(self):
        with patch("app.api.routes.caregiver.find_patient_for_caregiver", new_callable=AsyncMock) as mock_find:
            mock_find.return_value = self.patient_user

            detail = await caregiver.get_patient_detail("p101", self.caregiver_user)
            self.assertIsInstance(detail, PatientDetailOut)
            self.assertEqual(detail.id, "p101")
            self.assertEqual(detail.name, "Aarav Sharma")
            self.assertIsNotNone(detail.emergencyContact)
            self.assertEqual(detail.emergencyContact.name, "Priya Sharma")
            self.assertIsNotNone(detail.deviceStatus)
            self.assertTrue(detail.deviceStatus.linked)

    async def test_get_patient_detail_not_found(self):
        with patch("app.api.routes.caregiver.find_patient_for_caregiver", new_callable=AsyncMock) as mock_find:
            mock_find.return_value = None
            with self.assertRaises(HTTPException) as ctx:
                await caregiver.get_patient_detail("unknown_id", self.caregiver_user)
            self.assertEqual(ctx.exception.status_code, 404)

    # ---- Memory Gallery Endpoints -------------------------------------------

    async def test_get_family_members(self):
        with patch("app.api.routes.patients._verify_patient_access", new_callable=AsyncMock) as mock_access:
            mock_access.return_value = "p101"
            with patch("app.api.routes.patients.FamilyMember.find") as mock_find:
                mock_query = MagicMock()
                mock_item = MagicMock()
                mock_item.id = "fam_1"
                mock_item.patient_id = "p101"
                mock_item.name = "Zara Begum"
                mock_item.relation = "Granddaughter"
                mock_item.photo_url = "data:image/svg+xml;utf8,<svg></svg>"
                mock_query.to_list = AsyncMock(return_value=[mock_item])
                mock_find.return_value = mock_query

                members = await patients.get_family_members("p101", self.caregiver_user)
                self.assertEqual(len(members), 1)
                self.assertEqual(members[0].name, "Zara Begum")
                self.assertEqual(members[0].relation, "Granddaughter")

    async def test_get_family_members_empty(self):
        with patch("app.api.routes.patients._verify_patient_access", new_callable=AsyncMock) as mock_access:
            mock_access.return_value = "p521"
            with patch("app.api.routes.patients.FamilyMember.find") as mock_find:
                mock_query = MagicMock()
                mock_query.to_list = AsyncMock(return_value=[])
                mock_find.return_value = mock_query

                members = await patients.get_family_members("p521", self.caregiver_user)
                self.assertEqual(len(members), 0)

    async def test_create_family_member_valid(self):
        with patch("app.api.routes.patients._verify_patient_access", new_callable=AsyncMock) as mock_access:
            mock_access.return_value = "p101"
            with patch("app.api.routes.patients.FamilyMember.insert", new_callable=AsyncMock):
                payload = FamilyMemberCreate(
                    name="Zara Begum",
                    relation="Granddaughter",
                    photoUrl="data:image/jpeg;base64,mock",
                )
                created = await patients.create_family_member("p101", payload, self.caregiver_user)
                self.assertEqual(created.name, "Zara Begum")
                self.assertEqual(created.relation, "Granddaughter")
                self.assertEqual(created.patientId, "p101")
                self.assertTrue(created.id.startswith("fam_"))

    # ---- Health & Wellness Reminders Endpoints -----------------------------

    async def test_get_reminders(self):
        with patch("app.api.routes.patients._verify_patient_access", new_callable=AsyncMock) as mock_access:
            mock_access.return_value = "p101"
            mock_reminder = MagicMock()
            mock_reminder.medication = [{"id": "med_1", "label": "Morning Dose", "time": "8:00 AM"}]
            mock_reminder.hydration = {"id": "hyd_1", "label": "Hourly Water Intake", "status": "Active"}
            mock_reminder.meals = [{"id": "meal_1", "label": "Breakfast", "time": "8:30 AM"}]
            mock_reminder.custom = [{"id": "cust_1", "label": "Evening Walk", "time": "5:00 PM"}]
            with patch("app.api.routes.patients._get_or_create_reminders", new_callable=AsyncMock) as mock_rem:
                mock_rem.return_value = mock_reminder

                res = await patients.get_reminders("p101", self.caregiver_user)
                self.assertEqual(len(res.medication), 1)
                self.assertEqual(res.hydration["label"], "Hourly Water Intake")
                self.assertEqual(len(res.meals), 1)
                self.assertEqual(len(res.custom), 1)

    async def test_update_category_reminders_valid(self):
        with patch("app.api.routes.patients._verify_patient_access", new_callable=AsyncMock) as mock_access:
            mock_access.return_value = "p101"
            mock_reminder = MagicMock()
            mock_reminder.medication = []
            mock_reminder.save = AsyncMock()
            with patch("app.api.routes.patients._get_or_create_reminders", new_callable=AsyncMock) as mock_rem:
                mock_rem.return_value = mock_reminder

                new_meds = [{"id": "med_1", "label": "Updated Dose", "time": "9:00 AM"}]
                updated = await patients.update_category_reminders("p101", "medication", new_meds, self.caregiver_user)
                self.assertEqual(updated, new_meds)
                mock_reminder.save.assert_called_once()

    async def test_update_category_reminders_invalid_category(self):
        with patch("app.api.routes.patients._verify_patient_access", new_callable=AsyncMock) as mock_access:
            mock_access.return_value = "p101"
            with self.assertRaises(HTTPException) as ctx:
                await patients.update_category_reminders("p101", "nonexistent_category", {}, self.caregiver_user)
            self.assertEqual(ctx.exception.status_code, 400)

    async def test_add_custom_reminder(self):
        with patch("app.api.routes.patients._verify_patient_access", new_callable=AsyncMock) as mock_access:
            mock_access.return_value = "p101"
            mock_reminder = MagicMock()
            mock_reminder.custom = []
            mock_reminder.save = AsyncMock()
            with patch("app.api.routes.patients._get_or_create_reminders", new_callable=AsyncMock) as mock_rem:
                mock_rem.return_value = mock_reminder

                payload = CustomReminderCreate(
                    label="Evening Walk & Stretch",
                    time="5:00 PM",
                    frequency="Daily",
                )
                res = await patients.add_custom_reminder("p101", payload, self.caregiver_user)
                self.assertEqual(res.label, "Evening Walk & Stretch")
                self.assertEqual(res.time, "5:00 PM")
                self.assertTrue(res.id.startswith("cust_"))
                self.assertEqual(len(mock_reminder.custom), 1)

    # ---- Cognitive Game Sessions & Analytics Endpoints ----------------------

    async def test_get_game_sessions_empty_when_none(self):
        with patch("app.api.routes.patients._verify_patient_access", new_callable=AsyncMock) as mock_access:
            mock_access.return_value = "p521"
            with patch("app.api.routes.patients.GameSession.find") as mock_find:
                mock_query = MagicMock()
                mock_query.sort.return_value.to_list = AsyncMock(return_value=[])
                mock_find.return_value = mock_query
                sessions = await patients.get_game_sessions("p521", caregiver=self.caregiver_user)
                self.assertEqual(len(sessions), 0)

    async def test_get_game_sessions_domain_filtering(self):
        with patch("app.api.routes.patients._verify_patient_access", new_callable=AsyncMock) as mock_access:
            mock_access.return_value = "p101"
            mock_session = GameSession(
                patient_id="p101",
                patient_profile_id="p101",
                client_session_id="sess_1",
                game_type="pair_matching",
                domain="memory",
                client_timestamp=datetime.utcnow(),
            )
            with patch("app.api.routes.patients.GameSession.find") as mock_find:
                mock_query = MagicMock()
                mock_query.sort.return_value.to_list = AsyncMock(return_value=[mock_session])
                mock_find.return_value = mock_query
                mem_sessions = await patients.get_game_sessions("p101", domain="memory", caregiver=self.caregiver_user)
                self.assertEqual(len(mem_sessions), 1)
                self.assertEqual(mem_sessions[0].domain, "memory")

                lang_sessions = await patients.get_game_sessions("p101", domain="language", caregiver=self.caregiver_user)
                self.assertEqual(len(lang_sessions), 0)

    async def test_register_patient_with_pairing_token(self):
        payload = PatientCreateRequest(
            id="p105",
            name="Ramesh Patel",
            age=75,
            diagnosis="Mild Cognitive Impairment (MCI)",
            pairingToken="PAIR-891234",
        )
        with patch("app.api.routes.caregiver.User.find_one", new_callable=AsyncMock) as mock_find_one, \
             patch("app.api.routes.caregiver.User.insert", new_callable=AsyncMock), \
             patch("app.api.routes.caregiver.DevicePairingToken.find_one", new_callable=AsyncMock) as mock_pair_find, \
             patch("app.api.routes.caregiver.DevicePairingToken.insert", new_callable=AsyncMock):
            mock_find_one.return_value = None
            mock_pair_find.return_value = None

            created = await caregiver.register_patient(payload, self.caregiver_user)
            self.assertEqual(created.id, "p105")
            self.assertEqual(created.name, "Ramesh Patel")
            self.assertEqual(created.pairingToken, "PAIR-891234")

    async def test_patient_pair_with_full_code(self):
        mock_patient = User(
            id=uuid.uuid4(),
            role=RoleEnum.patient,
            name="Ramesh Patel",
            patient_code="p105",
            pairing_token="PAIR-891234",
            caregiver_id=self.caregiver_id,
        )
        with patch("app.api.routes.auth.DevicePairingToken.find_one", new_callable=AsyncMock) as mock_find_token, \
             patch("app.api.routes.auth.User.find_one", new_callable=AsyncMock) as mock_find_user, \
             patch("app.models.user.User.save", new_callable=AsyncMock):
            mock_find_token.return_value = None
            # Return patient when searched by pairing_token
            mock_find_user.side_effect = lambda *args, **kwargs: mock_patient

            req = PatientPairCompleteRequest(
                pairing_code="PAIR-891234",
                device_id="DEV-PATIENT-01",
                device_name="Tablet unit 1",
            )
            res = await auth.complete_pairing(req)
            self.assertEqual(res.patient_name, "Ramesh Patel")
            self.assertEqual(res.patient_code, "p105")
            self.assertTrue(res.token.access_token)

    async def test_patient_pair_with_digits_only(self):
        mock_patient = User(
            id=uuid.uuid4(),
            role=RoleEnum.patient,
            name="Aarav Sharma",
            patient_code="p101",
            pairing_token="PAIR-652759",
            caregiver_id=self.caregiver_id,
        )
        with patch("app.api.routes.auth.DevicePairingToken.find_one", new_callable=AsyncMock) as mock_find_token, \
             patch("app.api.routes.auth.User.find_one", new_callable=AsyncMock) as mock_find_user, \
             patch("app.models.user.User.save", new_callable=AsyncMock):
            mock_find_token.return_value = None
            mock_find_user.side_effect = lambda *args, **kwargs: mock_patient

            # Patient enters only digits "652759"
            req = PatientPairCompleteRequest(
                pairing_code="652759",
                device_id="DEV-PATIENT-02",
            )
            res = await auth.complete_pairing(req)
            self.assertEqual(res.patient_name, "Aarav Sharma")
            self.assertEqual(res.patient_code, "p101")
            self.assertTrue(res.token.access_token)

    async def test_patient_pair_invalid_code_raises_404(self):
        with patch("app.api.routes.auth.DevicePairingToken.find_one", new_callable=AsyncMock) as mock_find_token, \
             patch("app.api.routes.auth.User.find_one", new_callable=AsyncMock) as mock_find_user:
            mock_find_token.return_value = None
            mock_find_user.return_value = None

            req = PatientPairCompleteRequest(pairing_code="INVALID-999999")
            with self.assertRaises(HTTPException) as ctx:
                await auth.complete_pairing(req)
            self.assertEqual(ctx.exception.status_code, 404)

    async def test_get_patient_me(self):
        mock_patient = User(
            id=uuid.uuid4(),
            role=RoleEnum.patient,
            name="Aarav Sharma",
            patient_code="p101",
            caregiver_id=self.caregiver_id,
            region_language="bn",
        )
        res = await auth.get_patient_me(mock_patient)
        self.assertEqual(res.patient_name, "Aarav Sharma")
        self.assertEqual(res.patient_code, "p101")
        self.assertEqual(res.region_language, "bn")


if __name__ == "__main__":
    unittest.main()
