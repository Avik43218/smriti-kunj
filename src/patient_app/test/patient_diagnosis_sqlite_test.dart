import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:patient_app/models/patient_diagnosis.dart';
import 'package:patient_app/services/activity_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Patient Diagnosis SQLite Persistence Tests', () {
    late Database inMemoryDb;
    late ActivityDatabaseService activityDb;

    setUp(() async {
      inMemoryDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
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

    test('Saves and retrieves patient diagnosis from SQLite table', () async {
      final now = DateTime.now();
      final diag = PatientDiagnosisInfo(
        pairingCode: 'PAIR-652759',
        patientId: 'p101',
        patientName: 'Aarav Sharma',
        rawDiagnosis: 'Mild Cognitive Impairment',
        priority: DiagnosisPriority.mildCognitiveImpairment,
        fetchedAt: now,
      );

      await activityDb.savePatientDiagnosis(diag);

      final retrieved = await activityDb.getPatientDiagnosis(pairingCode: 'PAIR-652759');
      expect(retrieved, isNotNull);
      expect(retrieved!.pairingCode, 'PAIR-652759');
      expect(retrieved.patientId, 'p101');
      expect(retrieved.rawDiagnosis, 'Mild Cognitive Impairment');
      expect(retrieved.priorityNumber, 4);
      expect(retrieved.priority, DiagnosisPriority.mildCognitiveImpairment);
    });

    test('Retrieves diagnosis regardless of PAIR- prefix format', () async {
      final diag = PatientDiagnosisInfo(
        pairingCode: 'PAIR-891234',
        patientId: 'p102',
        patientName: 'Ramesh',
        rawDiagnosis: "Early Stage Alzheimer's",
        priority: DiagnosisPriority.earlyStageAlzheimers,
        fetchedAt: DateTime.now(),
      );

      await activityDb.savePatientDiagnosis(diag);

      // Query with code without prefix
      final retrievedWithoutPrefix = await activityDb.getPatientDiagnosis(pairingCode: '891234');
      expect(retrievedWithoutPrefix, isNotNull);
      expect(retrievedWithoutPrefix!.priorityNumber, 1);
      expect(retrievedWithoutPrefix.rawDiagnosis, "Early Stage Alzheimer's");

      // Query with code with prefix
      final retrievedWithPrefix = await activityDb.getPatientDiagnosis(pairingCode: 'PAIR-891234');
      expect(retrievedWithPrefix, isNotNull);
      expect(retrievedWithPrefix!.priorityNumber, 1);
    });

    test('Overwrites previous diagnosis when updated from MongoDB', () async {
      final initial = PatientDiagnosisInfo(
        pairingCode: 'PAIR-652759',
        patientId: 'p101',
        patientName: 'Aarav Sharma',
        rawDiagnosis: 'Other / Under Observation',
        priority: DiagnosisPriority.otherUnderObservation,
        fetchedAt: DateTime.now(),
      );
      await activityDb.savePatientDiagnosis(initial);

      var res = await activityDb.getPatientDiagnosis(pairingCode: 'PAIR-652759');
      expect(res!.priorityNumber, 7);

      // Update with clinical diagnosis
      final updated = PatientDiagnosisInfo(
        pairingCode: 'PAIR-652759',
        patientId: 'p101',
        patientName: 'Aarav Sharma',
        rawDiagnosis: 'Frontotemporal Dementia',
        priority: DiagnosisPriority.frontotemporalDementia,
        fetchedAt: DateTime.now(),
      );
      await activityDb.savePatientDiagnosis(updated);

      res = await activityDb.getPatientDiagnosis(pairingCode: 'PAIR-652759');
      expect(res!.priorityNumber, 3);
      expect(res.rawDiagnosis, 'Frontotemporal Dementia');
    });

    test('clearPatientDiagnosis removes diagnosis from SQLite', () async {
      final diag = PatientDiagnosisInfo(
        pairingCode: 'PAIR-652759',
        patientId: 'p101',
        patientName: 'Aarav Sharma',
        rawDiagnosis: 'Vascular Dementia',
        priority: DiagnosisPriority.vascularDementia,
        fetchedAt: DateTime.now(),
      );
      await activityDb.savePatientDiagnosis(diag);

      expect(await activityDb.getPatientDiagnosis(pairingCode: 'PAIR-652759'), isNotNull);

      await activityDb.clearPatientDiagnosis();
      expect(await activityDb.getPatientDiagnosis(pairingCode: 'PAIR-652759'), isNull);
    });
  });
}
