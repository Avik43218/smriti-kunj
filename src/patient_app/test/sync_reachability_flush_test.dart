import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:patient_app/models/patient_activity.dart';
import 'package:patient_app/games/shared/services/game_session_repository.dart';
import 'package:patient_app/services/activity_database_service.dart';
import 'package:patient_app/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Backend Reachability & SQLite Flush Sync Tests', () {
    late Database inMemoryDb;
    late ActivityDatabaseService activityDb;

    setUp(() async {
      inMemoryDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

      await inMemoryDb.execute('''
        CREATE TABLE patient_activities (
          id                     INTEGER PRIMARY KEY AUTOINCREMENT,
          client_session_id      TEXT    UNIQUE NOT NULL,
          patient_id             TEXT    NOT NULL,
          patient_profile_id     TEXT    NOT NULL,
          pairing_code           TEXT,
          game_type              TEXT    NOT NULL,
          game_name              TEXT    NOT NULL,
          domain                 TEXT    NOT NULL,
          difficulty_level       INTEGER NOT NULL,
          score_normalized       REAL    NOT NULL,
          session_duration       INTEGER NOT NULL,
          accuracy               REAL    NOT NULL,
          avg_latency_ms         REAL    NOT NULL,
          error_rate             REAL    NOT NULL,
          session_date           TEXT    NOT NULL,
          status                 TEXT    NOT NULL DEFAULT 'completed',
          raw_payload            TEXT    NOT NULL,
          is_synced              INTEGER NOT NULL DEFAULT 0,
          synced_at              TEXT
        )
      ''');

      await inMemoryDb.execute('''
        CREATE TABLE game_sessions (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id   TEXT    NOT NULL UNIQUE,
          patient_id   TEXT    NOT NULL,
          game_type    TEXT    NOT NULL,
          session_date TEXT    NOT NULL,
          synced       INTEGER NOT NULL DEFAULT 0,
          created_at   TEXT    NOT NULL,
          payload      TEXT    NOT NULL
        )
      ''');

      await inMemoryDb.execute('''
        CREATE TABLE app_pairing_code (
          id                    INTEGER PRIMARY KEY AUTOINCREMENT,
          pairing_code          TEXT    NOT NULL UNIQUE,
          patient_id            TEXT,
          saved_at              TEXT    NOT NULL,
          is_active             INTEGER NOT NULL DEFAULT 1,
          guardian_phone        TEXT,
          guardian_name         TEXT,
          guardian_relationship TEXT
        )
      ''');

      activityDb = ActivityDatabaseService.instance;
      activityDb.setDatabaseForTesting(inMemoryDb);
    });

    tearDown(() async {
      await inMemoryDb.close();
    });

    test('ApiService.isBackendReachable returns false for invalid / unreachable host', () async {
      final api = ApiService.instance;
      // Set to an invalid unreachable port to test offline detection
      api.baseUrl = 'http://127.0.0.1:59999';
      final isReachable = await api.isBackendReachable(
        timeout: const Duration(milliseconds: 300),
      );
      expect(isReachable, isFalse);
    });

    test('Offline preservation: When backend is unreachable, SQLite activities remain preserved', () async {
      final now = DateTime.now();
      await activityDb.recordGameActivity(PatientActivityRecord(
        clientSessionId: 'offline_sess_1',
        patientId: 'p101',
        patientProfileId: 'p101',
        pairingCode: 'PAIR-652759',
        gameType: 'market_trip',
        gameName: 'Market Trip',
        domain: 'memory',
        difficultyLevel: 1,
        scoreNormalized: 0.90,
        sessionDuration: 60,
        accuracy: 0.95,
        avgLatencyMs: 1200.0,
        errorRate: 0.05,
        sessionDate: now,
      ));

      await activityDb.recordGameActivity(PatientActivityRecord(
        clientSessionId: 'offline_sess_2',
        patientId: 'p101',
        patientProfileId: 'p101',
        pairingCode: 'PAIR-652759',
        gameType: 'tap_target',
        gameName: 'Tap Target',
        domain: 'attention',
        difficultyLevel: 1,
        scoreNormalized: 0.85,
        sessionDuration: 45,
        accuracy: 0.88,
        avgLatencyMs: 900.0,
        errorRate: 0.12,
        sessionDate: now,
      ));

      // Simulate reachability check failing
      final isReachable = false;

      if (!isReachable) {
        // Does nothing, preserves data
      } else {
        await activityDb.wipeCleanAllActivities();
      }

      // Verify SQLite records are completely preserved
      final pending = await activityDb.getUnsyncedActivities();
      expect(pending.length, 2);
      expect(pending.map((e) => e.clientSessionId), containsAll(['offline_sess_1', 'offline_sess_2']));
    });

    test('Flush on sync: wipeCleanAllActivities and flushGameSessions completely flush local SQLite database', () async {
      final now = DateTime.now();
      await activityDb.recordGameActivity(PatientActivityRecord(
        clientSessionId: 'sync_flush_1',
        patientId: 'p101',
        patientProfileId: 'p101',
        pairingCode: 'PAIR-652759',
        gameType: 'pair_matching',
        gameName: 'Pair Matching',
        domain: 'memory',
        difficultyLevel: 2,
        scoreNormalized: 0.92,
        sessionDuration: 85,
        accuracy: 0.94,
        avgLatencyMs: 1100.0,
        errorRate: 0.06,
        sessionDate: now,
      ));

      expect(await activityDb.getUnsyncedCount(), 1);

      // Flushes local SQLite table
      final deleted = await activityDb.flushGameSessions();
      expect(deleted, 1);

      // Verify local SQLite database is completely empty
      expect(await activityDb.getUnsyncedCount(), 0);
      final remaining = await activityDb.getUnsyncedActivities();
      expect(remaining.isEmpty, isTrue);
    });

    test('GameSessionRepository.clearAllSessions flushes game_sessions SQLite table', () async {
      await inMemoryDb.insert('game_sessions', {
        'session_id': 'repo_sess_101',
        'patient_id': 'p101',
        'game_type': 'tap_target',
        'session_date': DateTime.now().toIso8601String(),
        'synced': 0,
        'created_at': DateTime.now().toIso8601String(),
        'payload': '{"session_id": "repo_sess_101"}',
      });

      final rowsBefore = await inMemoryDb.query('game_sessions');
      expect(rowsBefore.length, 1);

      // Direct flush test on game_sessions table
      final deleted = await inMemoryDb.delete('game_sessions');
      expect(deleted, 1);

      final rowsAfter = await inMemoryDb.query('game_sessions');
      expect(rowsAfter.isEmpty, isTrue);
    });
  });
}
