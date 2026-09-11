import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/patient_activity.dart';

/// SQLite persistence service for local patient app activity.
///
/// Workflow:
/// 1. When a game completes, it is saved into `patient_activities` with [is_synced = 0].
/// 2. When the patient taps "Sync", all pending activities are transferred to MongoDB.
/// 3. Upon verified transfer, the transferred records are wiped clean from SQLite.
class ActivityDatabaseService extends ChangeNotifier {
  static final ActivityDatabaseService instance = ActivityDatabaseService._internal();

  ActivityDatabaseService._internal();
  factory ActivityDatabaseService() => instance;

  static const _dbName = 'smriti_kunj_sessions.db';
  static const _table = 'patient_activities';

  Database? _db;

  @visibleForTesting
  void setDatabaseForTesting(Database db) {
    _db = db;
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);

    _db = await openDatabase(
      fullPath,
      version: 4,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createTables(db);
      },
    );
    return _db!;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_table (
        id                     INTEGER PRIMARY KEY AUTOINCREMENT,
        client_session_id      TEXT    UNIQUE NOT NULL,
        patient_id             TEXT    NOT NULL,
        patient_profile_id     TEXT    NOT NULL,
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
  }

  /// Inserts a game activity record into local SQLite database.
  Future<int> recordGameActivity(PatientActivityRecord record) async {
    try {
      final db = await database;
      final id = await db.insert(
        _table,
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('[ActivityDatabaseService] Recorded game ${record.gameName} (ID: $id, session: ${record.clientSessionId})');
      notifyListeners();
      return id;
    } catch (e) {
      debugPrint('[ActivityDatabaseService] Error recording game activity: $e');
      return -1;
    }
  }

  /// Retrieves recent activities stored in SQLite, ordered by newest first.
  Future<List<PatientActivityRecord>> getRecentActivities({int limit = 20}) async {
    try {
      final db = await database;
      final rows = await db.query(
        _table,
        orderBy: 'session_date DESC',
        limit: limit,
      );
      return rows.map((r) => PatientActivityRecord.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[ActivityDatabaseService] Error fetching recent activities: $e');
      return [];
    }
  }

  /// Retrieves all unsynced activities waiting to be uploaded to MongoDB.
  Future<List<PatientActivityRecord>> getUnsyncedActivities() async {
    try {
      final db = await database;
      final rows = await db.query(
        _table,
        where: 'is_synced = 0',
        orderBy: 'session_date ASC',
      );
      return rows.map((r) => PatientActivityRecord.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[ActivityDatabaseService] Error fetching unsynced activities: $e');
      return [];
    }
  }

  /// Returns the count of pending activities waiting for sync.
  Future<int> getUnsyncedCount() async {
    try {
      final db = await database;
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_table WHERE is_synced = 0'),
      );
      return count ?? 0;
    } catch (e) {
      debugPrint('[ActivityDatabaseService] Error getting unsynced count: $e');
      return 0;
    }
  }

  /// Wipes clean specific activities from SQLite after they are confirmed transferred to MongoDB.
  Future<int> deleteActivities(List<String> clientSessionIds) async {
    if (clientSessionIds.isEmpty) return 0;
    try {
      final db = await database;
      final placeholders = List.filled(clientSessionIds.length, '?').join(',');
      final deleted = await db.delete(
        _table,
        where: 'client_session_id IN ($placeholders)',
        whereArgs: clientSessionIds,
      );
      debugPrint('[ActivityDatabaseService] Wiped clean $deleted transferred activities from SQLite.');
      notifyListeners();
      return deleted;
    } catch (e) {
      debugPrint('[ActivityDatabaseService] Error wiping clean activities: $e');
      return 0;
    }
  }

  /// Wipes clean all activities from SQLite database.
  Future<int> wipeCleanAllActivities() async {
    try {
      final db = await database;
      final deleted = await db.delete(_table);
      debugPrint('[ActivityDatabaseService] Wiped clean all ($deleted) activities from SQLite.');
      notifyListeners();
      return deleted;
    } catch (e) {
      debugPrint('[ActivityDatabaseService] Error wiping clean all activities: $e');
      return 0;
    }
  }

  /// Seed sample activity if local database has no activities yet,
  /// allowing quick testing of sync button functionality.
  Future<void> seedSampleActivityIfEmpty(String patientId) async {
    try {
      final db = await database;
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_table'),
      );
      if (count == null || count == 0) {
        final rand = Random();
        final now = DateTime.now();

        await recordGameActivity(PatientActivityRecord(
          clientSessionId: 'seed_${now.millisecondsSinceEpoch}_1',
          patientId: patientId,
          patientProfileId: patientId,
          gameType: 'market_trip',
          gameName: 'Market Trip',
          domain: 'memory',
          difficultyLevel: 1,
          scoreNormalized: 0.85,
          sessionDuration: 95,
          accuracy: 0.88,
          avgLatencyMs: 1420.0,
          errorRate: 0.12,
          sessionDate: now.subtract(const Duration(minutes: 15)),
          status: 'completed',
          rawPayload: {
            'items_prompted_count': 4,
            'items_recalled_correct': 3,
            'recall_accuracy': 0.75,
            'false_selection_count': 1,
            'time_to_complete_recall': 42.5,
          },
        ));

        await recordGameActivity(PatientActivityRecord(
          clientSessionId: 'seed_${now.millisecondsSinceEpoch}_2',
          patientId: patientId,
          patientProfileId: patientId,
          gameType: 'pair_matching',
          gameName: 'Pair Matching',
          domain: 'memory',
          difficultyLevel: 1,
          scoreNormalized: 0.90,
          sessionDuration: 120,
          accuracy: 0.92,
          avgLatencyMs: 1850.0,
          errorRate: 0.08,
          sessionDate: now.subtract(const Duration(minutes: 5)),
          status: 'completed',
          rawPayload: {
            'total_flips': 14,
            'correct_match_rate': 0.86,
            'pairs_count': 4,
            'used_face_name_variant': false,
          },
        ));
      }
    } catch (e) {
      debugPrint('[ActivityDatabaseService] Error seeding sample activity: $e');
    }
  }
}
