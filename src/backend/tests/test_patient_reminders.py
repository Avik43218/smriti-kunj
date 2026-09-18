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


class TestPatientReminders(unittest.IsolatedAsyncioTestCase):
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
        )

    async def test_missing_pairing_code_raises_400(self):
        with self.assertRaises(HTTPException) as ctx:
            await patients.get_patient_reminders_endpoint(
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
                await patients.get_patient_reminders_endpoint(
                    pairing_code="INVALID_CODE_999",
                    x_pairing_code=None,
                    payload=None,
                )
            self.assertEqual(ctx.exception.status_code, 404)
            self.assertIn("was not found", ctx.exception.detail)

    async def test_valid_pairing_code_fetches_existing_reminders(self):
        with patch("app.api.routes.patients.find_patient_by_pairing_code", new_callable=AsyncMock) as mock_find:
            mock_find.return_value = self.patient_user

            mock_rem = MagicMock(spec=PatientReminder)
            mock_rem.medication = [
                {"id": "med_1", "label": "Morning Blood Pressure Tablet", "time": "8:00 AM", "dosage": "1 tablet"}
            ]
            mock_rem.hydration = {"id": "hyd_1", "label": "Warm Water Intake", "time": "10:30 AM"}
            mock_rem.meals = [{"id": "meal_1", "label": "Nutritious Lunch", "time": "1:00 PM"}]
            mock_rem.custom = [{"id": "cust_1", "label": "Evening Garden Walk", "time": "5:00 PM"}]

            with patch("app.models.reminder.PatientReminder.find_one", new_callable=AsyncMock) as mock_find_rem:
                mock_find_rem.return_value = mock_rem

                res = await patients.get_patient_reminders_endpoint(
                    pairing_code="PAIR-652759",
                    x_pairing_code=None,
                    payload=None,
                )

                self.assertEqual(res.patient_id, "p101")
                self.assertEqual(res.pairing_code, "PAIR-652759")
                self.assertEqual(len(res.medication), 1)
                self.assertEqual(len(res.reminders), 4)
                # Verify unified reminders list contains expected fields
                titles = [r["title"] for r in res.reminders]
                self.assertIn("Morning Blood Pressure Tablet", titles)
                self.assertIn("Warm Water Intake", titles)
                self.assertIn("Nutritious Lunch", titles)
                self.assertIn("Evening Garden Walk", titles)

    async def test_valid_pairing_code_initializes_default_reminders_when_none_exist(self):
        with patch("app.api.routes.patients.find_patient_by_pairing_code", new_callable=AsyncMock) as mock_find:
            mock_find.return_value = self.patient_user

            with patch("app.models.reminder.PatientReminder.find_one", new_callable=AsyncMock) as mock_find_rem:
                mock_find_rem.return_value = None

                with patch("app.models.reminder.PatientReminder.save", new_callable=AsyncMock) as mock_save:
                    res = await patients.get_patient_reminders_endpoint(
                        pairing_code="PAIR-652759",
                        x_pairing_code=None,
                        payload=None,
                    )

                    self.assertEqual(res.patient_id, "p101")
                    self.assertGreaterEqual(len(res.reminders), 4)
                    mock_save.assert_called_once()


if __name__ == "__main__":
    unittest.main()
