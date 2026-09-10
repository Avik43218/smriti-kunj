import unittest
from datetime import datetime
from unittest.mock import AsyncMock, MagicMock, patch
import uuid

from beanie import init_beanie

from app.api.routes import patients, sync
from app.models.auth import RevokedToken
from app.models.care_plan import FamilyMember
from app.models.reminder import PatientReminder
from app.models.session import GameSession, VoiceInteraction
from app.models.user import DevicePairingToken, RoleEnum, User
from app.schemas.sync import GameSessionIn, SyncBatchIn


class TestSyncPipelineAndPersistence(unittest.IsolatedAsyncioTestCase):
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
            document_models=[User, FamilyMember, PatientReminder, GameSession, VoiceInteraction, DevicePairingToken, RevokedToken],
        )

        self.patient_id = uuid.uuid4()
        self.patient_user = User(
            id=self.patient_id,
            role=RoleEnum.patient,
            name="Aarav Sharma",
            patient_code="p101",
            region_language="bn",
            device_status={"linked": False},
        )
        self.caregiver_user = User(
            id=uuid.uuid4(),
            role=RoleEnum.caregiver,
            name="Caregiver User",
            email="caregiver@example.com",
        )

    async def test_sync_batch_persists_game_sessions_and_updates_patient(self):
        sample_session = GameSessionIn(
            client_session_id="client_sess_abc123",
            game_type="market_trip",
            domain="memory",
            difficulty_level="2",
            accuracy=0.85,
            avg_latency_ms=1450.0,
            error_rate=0.15,
            score_normalized=0.88,
            session_duration=110,
            status="completed",
            client_timestamp=datetime.utcnow(),
            raw_payload={
                "items_prompted_count": 4,
                "items_recalled_correct": 3,
                "game_name": "Market Trip",
            },
        )

        payload = SyncBatchIn(
            patient_id="p101",
            patient_code="p101",
            game_sessions=[sample_session],
            voice_interactions=[],
        )

        # Mock MongoDB calls
        with patch("app.models.session.GameSession.find_one", new_callable=AsyncMock) as mock_find_one, \
             patch("app.models.session.GameSession.insert", new_callable=AsyncMock) as mock_insert, \
             patch("app.models.user.User.save", new_callable=AsyncMock) as mock_user_save, \
             patch("app.api.routes.sync.update_bandit", new_callable=AsyncMock) as mock_bandit, \
             patch("app.api.routes.sync.run_anomaly_check", new_callable=AsyncMock) as mock_anomaly:

            mock_find_one.return_value = None  # Not yet synced
            mock_anomaly.return_value = 0

            res = await sync.sync_batch(payload=payload, patient=self.patient_user)

            self.assertEqual(res.accepted_game_sessions, 1)
            self.assertEqual(res.accepted_voice_interactions, 0)
            mock_insert.assert_called_once()
            mock_bandit.assert_called_once()

            # Verify patient's MongoDB record was updated with sync timestamp
            mock_user_save.assert_called_once()
            self.assertEqual(self.patient_user.last_check_in, "Just now")
            self.assertTrue(self.patient_user.device_status.get("linked"))
            self.assertIn("lastSynced", self.patient_user.device_status)

    async def test_sync_batch_is_idempotent(self):
        sample_session = GameSessionIn(
            client_session_id="duplicate_sess_999",
            game_type="tap_target",
            difficulty_level="1",
            accuracy=0.90,
            avg_latency_ms=980.0,
            error_rate=0.10,
            client_timestamp=datetime.utcnow(),
        )
        payload = SyncBatchIn(
            patient_id="p101",
            game_sessions=[sample_session],
            voice_interactions=[],
        )

        with patch("app.models.session.GameSession.find_one", new_callable=AsyncMock) as mock_find_one, \
             patch("app.models.session.GameSession.insert", new_callable=AsyncMock) as mock_insert, \
             patch("app.models.user.User.save", new_callable=AsyncMock), \
             patch("app.api.routes.sync.run_anomaly_check", new_callable=AsyncMock) as mock_anomaly:

            # Return existing session document to simulate duplicate
            mock_find_one.return_value = MagicMock()
            mock_anomaly.return_value = 0

            res = await sync.sync_batch(payload=payload, patient=self.patient_user)

            self.assertEqual(res.accepted_game_sessions, 0)
            mock_insert.assert_not_called()

    async def test_caregiver_fetches_synced_sessions_newest_first(self):
        older_sess = GameSession(
            patient_id="p101",
            patient_profile_id="p101",
            client_session_id="sess_older",
            game_type="market_trip",
            domain="memory",
            difficulty_level="1",
            score_normalized=0.75,
            client_timestamp=datetime(2026, 9, 10, 10, 0, 0),
        )
        newer_sess = GameSession(
            patient_id="p101",
            patient_profile_id="p101",
            client_session_id="sess_newer",
            game_type="pair_matching",
            domain="memory",
            difficulty_level="2",
            score_normalized=0.95,
            client_timestamp=datetime(2026, 9, 11, 3, 30, 0),
        )

        with patch("app.api.routes.patients._verify_patient_access", new_callable=AsyncMock) as mock_access, \
             patch("app.api.routes.patients.GameSession.find") as mock_find:

            mock_access.return_value = "p101"
            mock_query = MagicMock()
            mock_query.sort.return_value.to_list = AsyncMock(return_value=[older_sess, newer_sess])
            mock_find.return_value = mock_query

            sessions = await patients.get_game_sessions(
                patientId="p101",
                caregiver=self.caregiver_user,
            )

            self.assertEqual(len(sessions), 2)
            # Must be sorted descending (newest first)
            self.assertEqual(sessions[0].session_id, "sess_newer")
            self.assertEqual(sessions[0].score_normalized, 0.95)
            self.assertEqual(sessions[1].session_id, "sess_older")

    def test_sync_batch_routes_registered(self):
        from app.main import app
        registered_paths = {r.path for r in app.routes}
        self.assertIn("/api/sync/batch", registered_paths)
        self.assertIn("/sync/batch", registered_paths)
        self.assertIn("/api/sync", registered_paths)
        self.assertIn("/sync", registered_paths)

    async def test_sync_batch_handles_fractional_metrics_and_duration(self):
        sample_session = GameSessionIn(
            client_session_id="fractional_sess_001",
            game_type="visual_search",
            domain="attention",
            difficulty_level="2",
            accuracy=0.88,
            avg_latency_ms=1391.111111111111,
            error_rate=0.12,
            score_normalized=0.85,
            session_duration=45.5,
            status="completed",
            client_timestamp=datetime.utcnow(),
            raw_payload={
                "reaction_time_avg": 1391.111111111111,
                "reaction_time_variability": 145.0198794376094,
                "completion_time": 45.5,
                "trial_count": 10.0,
                "omission_rate": 0.05,
                "false_positive_rate": 0.07,
            },
        )
        payload = SyncBatchIn(
            patient_id="p101",
            game_sessions=[sample_session],
            voice_interactions=[],
        )

        inserted_sessions = []

        async def mock_insert_capture(sess):
            inserted_sessions.append(sess)

        with patch("app.models.session.GameSession.find_one", new_callable=AsyncMock) as mock_find_one, \
             patch.object(GameSession, "insert", new=mock_insert_capture), \
             patch("app.models.user.User.save", new_callable=AsyncMock), \
             patch("app.api.routes.sync.update_bandit", new_callable=AsyncMock), \
             patch("app.api.routes.sync.run_anomaly_check", new_callable=AsyncMock) as mock_anomaly:

            mock_find_one.return_value = None
            mock_anomaly.return_value = 0

            res = await sync.sync_batch(payload=payload, patient=self.patient_user)

            self.assertEqual(res.accepted_game_sessions, 1)
            self.assertEqual(len(inserted_sessions), 1)
            doc = inserted_sessions[0]
            self.assertEqual(doc.reaction_time_avg, 1391.111111111111)
            self.assertEqual(doc.reaction_time_variability, 145.0198794376094)
            self.assertEqual(doc.completion_time, 45.5)
            self.assertEqual(doc.trial_count, 10)


if __name__ == "__main__":
    unittest.main()
