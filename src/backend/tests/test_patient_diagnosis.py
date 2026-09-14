import unittest
import uuid
from unittest.mock import AsyncMock, MagicMock, patch
from beanie import init_beanie
from fastapi import HTTPException
from app.api.routes import patients
from app.models.care_plan import FamilyMember
from app.models.reminder import PatientReminder
from app.models.session import GameSession
from app.models.user import DevicePairingToken, RoleEnum, User


class TestPatientDiagnosis(unittest.IsolatedAsyncioTestCase):
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

        self.patient_id = uuid.uuid4()
        self.patient_user = User(
            id=self.patient_id,
            role=RoleEnum.patient,
            name="Aarav Sharma",
            patient_code="p101",
            pairing_token="PAIR-652759",
            diagnosis="Mild Cognitive Impairment",
            status="active",
        )

    async def test_missing_pairing_code_raises_400(self):
        with self.assertRaises(HTTPException) as ctx:
            await patients.get_patient_diagnosis_endpoint(
                pairing_code="",
                x_pairing_code=None,
                payload=None,
            )
        self.assertEqual(ctx.exception.status_code, 400)
        self.assertIn("Pairing code is required", ctx.exception.detail)

    async def test_nonexistent_pairing_code_raises_404(self):
        with patch("app.api.routes.patients.find_patient_by_pairing_code", new_callable=AsyncMock) as mock_find:
            mock_find.return_value = None
            with self.assertRaises(HTTPException) as ctx:
                await patients.get_patient_diagnosis_endpoint(
                    pairing_code="INVALID_CODE_999",
                    x_pairing_code=None,
                    payload=None,
                )
            self.assertEqual(ctx.exception.status_code, 404)
            self.assertIn("was not found", ctx.exception.detail)

    async def test_valid_pairing_code_fetches_diagnosis(self):
        with patch("app.api.routes.patients.find_patient_by_pairing_code", new_callable=AsyncMock) as mock_find:
            mock_find.return_value = self.patient_user

            res = await patients.get_patient_diagnosis_endpoint(
                pairing_code="PAIR-652759",
                x_pairing_code=None,
                payload=None,
            )

            self.assertEqual(res.pairing_code, "PAIR-652759")
            self.assertEqual(res.patient_id, "p101")
            self.assertEqual(res.patient_name, "Aarav Sharma")
            self.assertEqual(res.diagnosis, "Mild Cognitive Impairment")

    async def test_alias_endpoint_fetches_diagnosis(self):
        with patch("app.api.routes.patients.find_patient_by_pairing_code", new_callable=AsyncMock) as mock_find:
            mock_find.return_value = self.patient_user

            res = await patients.get_patient_alias_diagnosis_endpoint(
                pairing_code=None,
                x_pairing_code="652759",
                payload=None,
            )

            self.assertEqual(res.pairing_code, "652759")
            self.assertEqual(res.diagnosis, "Mild Cognitive Impairment")
