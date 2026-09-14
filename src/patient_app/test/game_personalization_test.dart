import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:patient_app/models/game_recommendation.dart';
import 'package:patient_app/models/patient_activity.dart';
import 'package:patient_app/models/patient_diagnosis.dart';
import 'package:patient_app/services/activity_database_service.dart';
import 'package:patient_app/services/difficulty_database_service.dart';
import 'package:patient_app/services/game_personalization_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Diagnosis Priority & Mapping Tests', () {
    test('All 7 valid diagnosis strings map to their exact assigned priority numbers', () {
      final mci = DiagnosisPriority.fromString("Mild Cognitive Impairment");
      expect(mci.priorityNumber, 4);
      expect(mci.displayName, "Mild Cognitive Impairment");

      final alzheimers = DiagnosisPriority.fromString("Early Stage Alzheimer's");
      expect(alzheimers.priorityNumber, 1);
      expect(alzheimers.displayName, "Early Stage Alzheimer's");

      final vascular = DiagnosisPriority.fromString("Vascular Dementia");
      expect(vascular.priorityNumber, 2);
      expect(vascular.displayName, "Vascular Dementia");

      final ftd = DiagnosisPriority.fromString("Frontotemporal Dementia");
      expect(ftd.priorityNumber, 3);
      expect(ftd.displayName, "Frontotemporal Dementia");

      final scd = DiagnosisPriority.fromString("Subjective Cognitive Decline");
      expect(scd.priorityNumber, 5);
      expect(scd.displayName, "Subjective Cognitive Decline");

      final aami = DiagnosisPriority.fromString("Age-Associated Memory Impairment");
      expect(aami.priorityNumber, 6);
      expect(aami.displayName, "Age-Associated Memory Impairment");

      final other = DiagnosisPriority.fromString("Other / Under Observation");
      expect(other.priorityNumber, 7);
      expect(other.displayName, "Other / Under Observation");
    });

    test('Case-insensitive and fuzzy diagnosis string normalization works correctly', () {
      expect(DiagnosisPriority.fromString("early stage alzheimer's").priorityNumber, 1);
      expect(DiagnosisPriority.fromString("MCI").priorityNumber, 4);
      expect(DiagnosisPriority.fromString("Mild Cognitive Impairment (MCI)").priorityNumber, 4);
      expect(DiagnosisPriority.fromString("vascular dementia").priorityNumber, 2);
      expect(DiagnosisPriority.fromString("FTD").priorityNumber, 3);
      expect(DiagnosisPriority.fromString("SCD").priorityNumber, 5);
      expect(DiagnosisPriority.fromString("AAMI").priorityNumber, 6);
      expect(DiagnosisPriority.fromString(null).priorityNumber, 7);
      expect(DiagnosisPriority.fromString("").priorityNumber, 7);
    });

    test('Lookup by priority number retrieves correct diagnosis category', () {
      expect(DiagnosisPriority.fromPriorityNumber(1), DiagnosisPriority.earlyStageAlzheimers);
      expect(DiagnosisPriority.fromPriorityNumber(2), DiagnosisPriority.vascularDementia);
      expect(DiagnosisPriority.fromPriorityNumber(3), DiagnosisPriority.frontotemporalDementia);
      expect(DiagnosisPriority.fromPriorityNumber(4), DiagnosisPriority.mildCognitiveImpairment);
      expect(DiagnosisPriority.fromPriorityNumber(5), DiagnosisPriority.subjectiveCognitiveDecline);
      expect(DiagnosisPriority.fromPriorityNumber(6), DiagnosisPriority.ageAssociatedMemoryImpairment);
      expect(DiagnosisPriority.fromPriorityNumber(7), DiagnosisPriority.otherUnderObservation);
    });
  });

  group('Personalization Recommendation Engine Tests', () {
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

      await inMemoryDb.execute('''
        CREATE TABLE patient_diagnosis (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          pairing_code TEXT    NOT NULL UNIQUE,
          patient_id   TEXT,
          patient_name TEXT,
          diagnosis    TEXT    NOT NULL,
          priority     INTEGER NOT NULL,
          fetched_at   TEXT    NOT NULL
        )
      ''');

      activityDb = ActivityDatabaseService.instance;
      activityDb.setDatabaseForTesting(inMemoryDb);
    });

    tearDown(() async {
      await inMemoryDb.close();
    });

    test('Recommends episodic memory game for Early Stage Alzheimer patient', () async {
      final diag = PatientDiagnosisInfo(
        pairingCode: 'PAIR-111111',
        patientId: 'p101',
        patientName: 'Aarav',
        rawDiagnosis: "Early Stage Alzheimer's",
        priority: DiagnosisPriority.earlyStageAlzheimers,
        fetchedAt: DateTime.now(),
      );
      await activityDb.savePatientDiagnosis(diag);

      final rec = await GamePersonalizationService.instance.getNextRecommendedGame(
        diagnosisInfo: diag,
        pairingCode: 'PAIR-111111',
      );

      expect(rec.priorityNumber, 1);
      expect(rec.diagnosisName, "Early Stage Alzheimer's");
      // For Alzheimer's priority 1, pair_matching or market_trip are preferred memory targets
      expect(rec.gameType, anyOf('pair_matching', 'market_trip'));
      expect(rec.clinicalRationale, contains("Early Stage Alzheimer's"));
    });

    test('Recommends attention game for Vascular Dementia patient', () async {
      final diag = PatientDiagnosisInfo(
        pairingCode: 'PAIR-222222',
        patientId: 'p102',
        patientName: 'Ramesh',
        rawDiagnosis: "Vascular Dementia",
        priority: DiagnosisPriority.vascularDementia,
        fetchedAt: DateTime.now(),
      );
      await activityDb.savePatientDiagnosis(diag);

      final rec = await GamePersonalizationService.instance.getNextRecommendedGame(
        diagnosisInfo: diag,
        pairingCode: 'PAIR-222222',
      );

      expect(rec.priorityNumber, 2);
      expect(rec.gameType, 'tap_target');
      expect(rec.domain, 'Attention & Speed');
    });

    test('Telemetry with high hesitation and errors shifts recommendation towards needed reinforcement', () async {
      // Simulate patient with MCI (Priority 4) struggling heavily in Market Trip (working memory)
      final now = DateTime.now();
      await activityDb.recordGameActivity(PatientActivityRecord(
        clientSessionId: 'sess_struggle_1',
        patientId: 'p101',
        patientProfileId: 'p101',
        pairingCode: 'PAIR-652759',
        gameType: 'market_trip',
        gameName: 'Market Trip',
        domain: 'memory',
        difficultyLevel: 1,
        scoreNormalized: 0.40,
        sessionDuration: 120,
        accuracy: 0.45,
        avgLatencyMs: 2400.0,
        errorRate: 0.55,
        sessionDate: now,
        rawPayload: {
          'telemetry': {
            'hesitation': {'hesitation_ratio': 0.65, 'is_hesitation': true},
          }
        },
      ));

      // And doing well in Tap Target (attention)
      await activityDb.recordGameActivity(PatientActivityRecord(
        clientSessionId: 'sess_good_1',
        patientId: 'p101',
        patientProfileId: 'p101',
        pairingCode: 'PAIR-652759',
        gameType: 'tap_target',
        gameName: 'Tap Target',
        domain: 'attention',
        difficultyLevel: 1,
        scoreNormalized: 0.95,
        sessionDuration: 60,
        accuracy: 0.96,
        avgLatencyMs: 650.0,
        errorRate: 0.04,
        sessionDate: now.subtract(const Duration(minutes: 5)),
        rawPayload: {
          'telemetry': {
            'hesitation': {'hesitation_ratio': 0.08, 'is_hesitation': false},
          }
        },
      ));

      final diag = PatientDiagnosisInfo(
        pairingCode: 'PAIR-652759',
        patientId: 'p101',
        patientName: 'Aarav',
        rawDiagnosis: "Mild Cognitive Impairment",
        priority: DiagnosisPriority.mildCognitiveImpairment,
        fetchedAt: now,
      );

      final rec = await GamePersonalizationService.instance.getNextRecommendedGame(
        diagnosisInfo: diag,
        pairingCode: 'PAIR-652759',
      );

      // The performance need in market_trip (high hesitation 65%, low accuracy 45%)
      // combined with MCI priority should recommend market_trip!
      expect(rec.gameType, 'market_trip');
      expect(rec.clinicalRationale, contains('targeted practice'));
      // Raw telemetry scores/percentages are omitted so as not to overwhelm elderly cognitive patients:
      expect(rec.clinicalRationale.contains('45%'), false);
      expect(rec.clinicalRationale.contains('65%'), false);
      expect(rec.clinicalRationale.contains('2400'), false);
      expect(rec.performanceSnapshot.roundsPlayed, 1);
      expect(rec.performanceSnapshot.hesitationRatio, closeTo(0.65, 0.01));
    });

    test('Personalization recommendation DOES NOT alter difficulty settings', () async {
      final diffDb = DifficultyDatabaseService.instance;
      final diffInMemoryDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await diffInMemoryDb.execute('''
        CREATE TABLE game_current_levels (
          game_type TEXT PRIMARY KEY,
          level     INTEGER NOT NULL
        )
      ''');
      await diffInMemoryDb.execute('''
        CREATE TABLE pending_difficulty_settings (
          id                     INTEGER PRIMARY KEY AUTOINCREMENT,
          game_type              TEXT    NOT NULL,
          action                 TEXT    NOT NULL,
          difficulty_delta       INTEGER NOT NULL,
          previous_difficulty    INTEGER NOT NULL,
          recommended_difficulty INTEGER NOT NULL,
          confidence             REAL    NOT NULL,
          raw_json               TEXT    NOT NULL,
          created_at             TEXT    NOT NULL
        )
      ''');
      diffDb.setDatabaseForTesting(diffInMemoryDb);

      // Set current level of market_trip to 3 (hard)
      await diffDb.setCurrentLevel('market_trip', 3);
      expect(await diffDb.getCurrentLevel('market_trip'), 3);

      // Run recommendation engine
      final diag = PatientDiagnosisInfo(
        pairingCode: 'PAIR-652759',
        patientId: 'p101',
        patientName: 'Aarav',
        rawDiagnosis: "Mild Cognitive Impairment",
        priority: DiagnosisPriority.mildCognitiveImpairment,
        fetchedAt: DateTime.now(),
      );
      await GamePersonalizationService.instance.getNextRecommendedGame(diagnosisInfo: diag);

      // Difficulty level in SQLite remains completely unchanged
      expect(await diffDb.getCurrentLevel('market_trip'), 3);
      await diffInMemoryDb.close();
    });
  });
}
