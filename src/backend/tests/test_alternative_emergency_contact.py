import unittest
import uuid
from unittest.mock import AsyncMock, MagicMock, patch
from pydantic import ValidationError
from beanie import init_beanie

from app.api.routes import caregiver
from app.models.care_plan import FamilyMember
from app.models.reminder import PatientReminder
from app.models.session import GameSession
from app.models.user import DevicePairingToken, RoleEnum, User
from app.schemas.patient import (
    PatientCreateRequest,
    PatientDetailOut,
    EmergencyContact,
)


class TestAlternativeEmergencyContact(unittest.IsolatedAsyncioTestCase):

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

        self.caregiver_id = uuid.uuid4()
        self.caregiver_user = User(
            id=self.caregiver_id,
            role=RoleEnum.caregiver,
            name="Caregiver User",
            email="caregiver@test.com",
        )

    def test_schema_allows_optional_alternative_contact(self):
        # Primary only
        req1 = PatientCreateRequest(
            name="Rajesh Sharma",
            emergencyContact={"name": "Priya Sharma", "relationship": "Daughter", "phone": "+91 98765 43210"},
        )
        self.assertIsNone(req1.alternativeEmergencyContact)

        # Both primary and alternative
        req2 = PatientCreateRequest(
            name="Rajesh Sharma",
            emergencyContact={"name": "Priya Sharma", "relationship": "Daughter", "phone": "+91 98765 43210"},
            alternativeEmergencyContact={"name": "Amit Sharma", "relationship": "Son", "phone": "+91 91234 56789"},
        )
        self.assertIsNotNone(req2.alternativeEmergencyContact)
        self.assertEqual(req2.alternativeEmergencyContact["name"], "Amit Sharma")
        self.assertEqual(req2.alternativeEmergencyContact["phone"], "+91 91234 56789")

    def test_schema_normalizes_empty_alternative_contact_to_none(self):
        # Empty dict
        req = PatientCreateRequest(
            name="Rajesh Sharma",
            emergencyContact={"name": "Priya Sharma", "relationship": "Daughter", "phone": "+91 98765 43210"},
            alternativeEmergencyContact={"name": "", "relationship": "", "phone": ""},
        )
        self.assertIsNone(req.alternativeEmergencyContact)

    def test_schema_rejects_incomplete_alternative_contact(self):
        # Name provided without phone
        with self.assertRaises(ValidationError) as ctx:
            PatientCreateRequest(
                name="Rajesh Sharma",
                emergencyContact={"name": "Priya Sharma", "relationship": "Daughter", "phone": "+91 98765 43210"},
                alternativeEmergencyContact={"name": "Amit Sharma", "relationship": "Son", "phone": ""},
            )
        self.assertIn("phone is required", str(ctx.exception))

        # Phone provided without name
        with self.assertRaises(ValidationError) as ctx:
            PatientCreateRequest(
                name="Rajesh Sharma",
                emergencyContact={"name": "Priya Sharma", "relationship": "Daughter", "phone": "+91 98765 43210"},
                alternativeEmergencyContact={"name": "", "relationship": "Son", "phone": "+91 91234 56789"},
            )
        self.assertIn("name is required", str(ctx.exception))

    def test_schema_rejects_duplicate_phone_number(self):
        with self.assertRaises(ValidationError) as ctx:
            PatientCreateRequest(
                name="Rajesh Sharma",
                emergencyContact={"name": "Priya Sharma", "relationship": "Daughter", "phone": "+91 98765 43210"},
                alternativeEmergencyContact={"name": "Priya (Work)", "relationship": "Daughter", "phone": "9876543210"},
            )
        self.assertIn("cannot have the same phone number", str(ctx.exception))

    @patch.object(User, "insert", new_callable=AsyncMock)
    @patch.object(DevicePairingToken, "find_one", new_callable=AsyncMock)
    @patch.object(caregiver, "find_patient_for_caregiver", new_callable=AsyncMock)
    async def test_create_patient_persists_alternative_contact(self, mock_find, mock_dpt_find, mock_insert):
        mock_find.return_value = None
        mock_dpt_find.return_value = None
        payload = PatientCreateRequest(
            name="Anjali Sen",
            emergencyContact={"name": "Debabrata Sen", "relationship": "Spouse", "phone": "+91 98765 11111"},
            alternativeEmergencyContact={"name": "Rupa Sen", "relationship": "Sister", "phone": "+91 98765 22222"},
        )

        created = await caregiver.register_patient(payload, caregiver=self.caregiver_user)
        self.assertEqual(created.name, "Anjali Sen")
        mock_insert.assert_called_once()
        self.assertIsNotNone(created.alternativeEmergencyContact)
        self.assertEqual(created.alternativeEmergencyContact.name, "Rupa Sen")
        self.assertEqual(created.alternativeEmergencyContact.phone, "+91 98765 22222")

    def test_user_to_patient_detail_tolerates_missing_alternative_contact(self):
        old_user = User(
            id=uuid.uuid4(),
            patient_code="p101",
            name="Old Patient",
            role=RoleEnum.patient,
            emergency_contact={"name": "Primary Contact", "relationship": "Spouse", "phone": "+91 90000 11111"},
            alternative_emergency_contact=None,
        )

        detail = caregiver._user_to_patient_detail(old_user)
        self.assertIsNotNone(detail.emergencyContact)
        self.assertEqual(detail.emergencyContact.name, "Primary Contact")
        self.assertIsNone(detail.alternativeEmergencyContact)

    def test_user_to_patient_detail_maps_alternative_contact_properly(self):
        user_with_alt = User(
            id=uuid.uuid4(),
            patient_code="p102",
            name="New Patient",
            role=RoleEnum.patient,
            emergency_contact={"name": "Primary Contact", "relationship": "Spouse", "phone": "+91 90000 11111"},
            alternative_emergency_contact={"name": "Secondary Contact", "relationship": "Daughter", "phone": "+91 90000 22222"},
        )

        detail = caregiver._user_to_patient_detail(user_with_alt)
        self.assertIsNotNone(detail.emergencyContact)
        self.assertIsNotNone(detail.alternativeEmergencyContact)
        self.assertEqual(detail.emergencyContact.name, "Primary Contact")
        self.assertEqual(detail.alternativeEmergencyContact.name, "Secondary Contact")
        self.assertEqual(detail.alternativeEmergencyContact.relationship, "Daughter")
        self.assertEqual(detail.alternativeEmergencyContact.phone, "+91 90000 22222")

    @patch.object(User, "save", new_callable=AsyncMock)
    @patch.object(caregiver, "find_patient_for_caregiver", new_callable=AsyncMock)
    async def test_update_patient_adds_and_removes_alternative_contact(self, mock_find, mock_save):
        existing_patient = User(
            id=uuid.uuid4(),
            patient_code="p103",
            name="Patient Update Test",
            role=RoleEnum.patient,
            caregiver_id=self.caregiver_id,
            emergency_contact={"name": "Primary", "relationship": "Spouse", "phone": "+91 90000 11111"},
            alternative_emergency_contact=None,
        )
        mock_find.return_value = existing_patient

        # 1. Add alternative contact
        add_payload = PatientCreateRequest(
            id="p103",
            name="Patient Update Test",
            emergencyContact={"name": "Primary", "relationship": "Spouse", "phone": "+91 90000 11111"},
            alternativeEmergencyContact={"name": "New Alt", "relationship": "Son", "phone": "+91 90000 33333"},
        )
        await caregiver.register_patient(add_payload, caregiver=self.caregiver_user)
        self.assertIsNotNone(existing_patient.alternative_emergency_contact)
        self.assertEqual(existing_patient.alternative_emergency_contact["name"], "New Alt")

        # 2. Remove alternative contact by passing None
        remove_payload = PatientCreateRequest(
            id="p103",
            name="Patient Update Test",
            emergencyContact={"name": "Primary", "relationship": "Spouse", "phone": "+91 90000 11111"},
            alternativeEmergencyContact=None,
        )
        await caregiver.register_patient(remove_payload, caregiver=self.caregiver_user)
        self.assertIsNone(existing_patient.alternative_emergency_contact)
