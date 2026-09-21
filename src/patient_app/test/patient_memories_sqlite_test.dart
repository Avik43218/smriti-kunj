import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:patient_app/models/memory_item.dart';
import 'package:patient_app/services/activity_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Patient ID & Memories SQLite Persistence Tests', () {
    late Database inMemoryDb;
    late ActivityDatabaseService activityDb;

    setUp(() async {
      inMemoryDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
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
        CREATE TABLE patient_memories (
          id               TEXT PRIMARY KEY,
          patient_id       TEXT NOT NULL,
          title            TEXT NOT NULL,
          subtitle         TEXT,
          relationship     TEXT,
          type             TEXT NOT NULL,
          photo_url        TEXT,
          audio_url        TEXT,
          duration         TEXT,
          audio_duration   TEXT,
          placeholder_icon TEXT,
          accent_color     INTEGER,
          created_at       TEXT
        )
      ''');
      await inMemoryDb.execute('''
        CREATE TABLE IF NOT EXISTS patient_diagnosis (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          pairing_code TEXT NOT NULL UNIQUE,
          patient_id   TEXT,
          patient_name TEXT,
          diagnosis    TEXT NOT NULL,
          priority     INTEGER NOT NULL,
          fetched_at   TEXT NOT NULL
        )
      ''');
      await inMemoryDb.execute('''
        CREATE TABLE IF NOT EXISTS patient_profile_status (
          id              INTEGER PRIMARY KEY AUTOINCREMENT,
          patient_id      TEXT,
          pairing_code    TEXT,
          patient_name    TEXT,
          caregivers_json TEXT,
          contacts_json   TEXT,
          last_updated    TEXT
        )
      ''');

      activityDb = ActivityDatabaseService.instance;
      activityDb.setDatabaseForTesting(inMemoryDb);
    });

    tearDown(() async {
      await inMemoryDb.close();
    });

    test('Saves patient ID in app_pairing_code and retrieves it via getActivePatientId', () async {
      expect(await activityDb.getActivePatientId(), isNull);

      await activityDb.savePairingCode(
        'PAIR-998877',
        patientId: 'patient_uuid_123',
        guardianPhone: '+919876543210',
        guardianName: 'Priya Sharma',
        guardianRelationship: 'Daughter',
      );

      final retrievedId = await activityDb.getActivePatientId();
      expect(retrievedId, 'patient_uuid_123');

      // Update patientId specifically
      await activityDb.savePatientId('p101');
      expect(await activityDb.getActivePatientId(), 'p101');
    });

    test('Saves and retrieves photo and audio memory items from SQLite', () async {
      final memories = [
        const MemoryItem(
          id: 'mem-photo-1',
          title: 'Aarav (Grandson)',
          subtitle: 'College graduation ceremony',
          relationship: 'Grandson',
          type: MemoryType.photo,
          photoUrl: 'data:image/jpeg;base64,/9j/testdata',
          placeholderIcon: Icons.family_restroom_rounded,
          accentColor: Color(0xFF2E6B4F),
        ),
        const MemoryItem(
          id: 'mem-audio-2',
          title: 'Morning Birds in Balcony',
          subtitle: 'Calming morning tea sound',
          relationship: 'Familiar Sound',
          type: MemoryType.audio,
          audioUrl: 'https://example.com/audio/birds.mp3',
          audioDuration: '0:45',
          placeholderIcon: Icons.volume_up_rounded,
          accentColor: Color(0xFFC47B2B),
        ),
      ];

      await activityDb.savePatientMemories('p101', memories);

      final retrieved = await activityDb.getPatientMemories('p101');
      expect(retrieved.length, 2);

      final photoItem = retrieved.firstWhere((m) => m.id == 'mem-photo-1');
      expect(photoItem.title, 'Aarav (Grandson)');
      expect(photoItem.type, MemoryType.photo);
      expect(photoItem.photoUrl, 'data:image/jpeg;base64,/9j/testdata');
      expect(photoItem.relationship, 'Grandson');

      final audioItem = retrieved.firstWhere((m) => m.id == 'mem-audio-2');
      expect(audioItem.title, 'Morning Birds in Balcony');
      expect(audioItem.type, MemoryType.audio);
      expect(audioItem.audioUrl, 'https://example.com/audio/birds.mp3');
      expect(audioItem.relationship, 'Familiar Sound');
    });

    test('Overwrites previous memories on new savePatientMemories call', () async {
      final initial = [
        const MemoryItem(
          id: 'mem-1',
          title: 'Old Photo',
          subtitle: 'Old caption',
          relationship: 'Friend',
          type: MemoryType.photo,
          placeholderIcon: Icons.photo,
          accentColor: Color(0xFF112233),
        ),
      ];
      await activityDb.savePatientMemories('p101', initial);
      expect((await activityDb.getPatientMemories('p101')).length, 1);

      final updated = [
        const MemoryItem(
          id: 'mem-2',
          title: 'New Photo',
          subtitle: 'New caption',
          relationship: 'Daughter',
          type: MemoryType.photo,
          placeholderIcon: Icons.photo,
          accentColor: Color(0xFF112233),
        ),
      ];
      await activityDb.savePatientMemories('p101', updated);

      final retrieved = await activityDb.getPatientMemories('p101');
      expect(retrieved.length, 1);
      expect(retrieved.first.id, 'mem-2');
      expect(retrieved.first.title, 'New Photo');
    });

    test('clearSavedPairingCode clears both pairing code and cached memories', () async {
      await activityDb.savePairingCode('PAIR-123456', patientId: 'p101');
      await activityDb.savePatientMemories('p101', [
        const MemoryItem(
          id: 'mem-1',
          title: 'Photo',
          subtitle: 'Caption',
          relationship: 'Son',
          type: MemoryType.photo,
          placeholderIcon: Icons.person,
          accentColor: Color(0xFF223344),
        ),
      ]);

      expect(await activityDb.getActivePatientId(), 'p101');
      expect((await activityDb.getPatientMemories('p101')).length, 1);

      await activityDb.clearSavedPairingCode();

      expect(await activityDb.getActivePatientId(), isNull);
      expect((await activityDb.getPatientMemories('p101')).length, 0);
    });
  });
}
