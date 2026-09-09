import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Stored session envelope — every game writes this shape.
// ─────────────────────────────────────────────────────────────────────────────

/// Immutable record of a completed (or abandoned) game session as stored on
/// the device.  Shared fields are top-level; game-specific analytics are
/// nested under [gameData].  [synced] flips to true once the record has been
/// successfully POSTed to the backend by [GameSyncService].
class StoredGameSession {
  final String sessionId;
  final String patientProfileId;

  /// `"market_trip"` | `"tap_target"` | `"pair_matching"` | `"object_recognition"`
  final String gameType;

  /// `"working_memory"` | `"episodic_memory"` | `"semantic_memory"` | `"attention"`
  final String domain;

  final DateTime sessionDate;
  final double sessionDuration; // seconds
  final String status; // "completed" | "abandoned"
  final int difficultyLevel; // 1 = easy, 2 = medium, 3 = hard
  final double scoreNormalized; // 0.0–1.0

  /// Game-specific analytics fields (keys vary by [gameType]).
  /// See GAMES_ANALYTICS_README.md for field definitions per game.
  final Map<String, dynamic> gameData;

  /// Per-event log.  Kept top-level because the schema is uniform across games.
  final List<Map<String, dynamic>> rawTrials;

  /// False until this record has been successfully POSTed to the backend.
  final bool synced;

  /// Device-local creation timestamp (UTC).  Used for ordering when
  /// [sessionDate] may drift across timezones.
  final DateTime createdAt;

  const StoredGameSession({
    required this.sessionId,
    required this.patientProfileId,
    required this.gameType,
    required this.domain,
    required this.sessionDate,
    required this.sessionDuration,
    required this.status,
    required this.difficultyLevel,
    required this.scoreNormalized,
    required this.gameData,
    required this.rawTrials,
    this.synced = false,
    required this.createdAt,
  });

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'patient_profile_id': patientProfileId,
        'game_type': gameType,
        'domain': domain,
        'session_date': sessionDate.toIso8601String(),
        'session_duration': sessionDuration,
        'status': status,
        'difficulty_level': difficultyLevel,
        'score_normalized': scoreNormalized,
        'game_data': gameData,
        'raw_trials': rawTrials,
        'synced': synced,
        'created_at': createdAt.toIso8601String(),
      };

  factory StoredGameSession.fromJson(Map<String, dynamic> json) {
    final rawList = json['raw_trials'] as List<dynamic>? ?? [];
    return StoredGameSession(
      sessionId: json['session_id'] as String,
      patientProfileId: json['patient_profile_id'] as String,
      gameType: json['game_type'] as String,
      domain: json['domain'] as String,
      sessionDate: DateTime.parse(json['session_date'] as String),
      sessionDuration: (json['session_duration'] as num).toDouble(),
      status: json['status'] as String,
      difficultyLevel: (json['difficulty_level'] as num).toInt(),
      scoreNormalized: (json['score_normalized'] as num).toDouble(),
      gameData: Map<String, dynamic>.from(json['game_data'] as Map),
      rawTrials:
          rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      synced: json['synced'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  StoredGameSession copyWith({bool? synced}) => StoredGameSession(
        sessionId: sessionId,
        patientProfileId: patientProfileId,
        gameType: gameType,
        domain: domain,
        sessionDate: sessionDate,
        sessionDuration: sessionDuration,
        status: status,
        difficultyLevel: difficultyLevel,
        scoreNormalized: scoreNormalized,
        gameData: gameData,
        rawTrials: rawTrials,
        synced: synced ?? this.synced,
        createdAt: createdAt,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Repository
// ─────────────────────────────────────────────────────────────────────────────

/// Single point every game calls to persist a completed session.
///
/// Backed by SQLite (via sqflite).  A single `game_sessions` table holds one
/// row per session; the full envelope is stored as a JSON TEXT blob in the
/// `payload` column to avoid column-schema churn as games evolve.
///
/// Usage:
/// ```dart
/// await GameSessionRepository.instance.saveSession(stored);
/// ```
class GameSessionRepository {
  GameSessionRepository._();
  static final GameSessionRepository instance = GameSessionRepository._();

  static const _dbName = 'smriti_kunj_sessions.db';
  static const _dbVersion = 1;
  static const _table = 'game_sessions';

  Database? _db;

  Future<Database> _getDb() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);
    _db = await openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE $_table (
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
        // Index for the sync query (unsynced rows, ordered for upload).
        await db.execute('''
          CREATE INDEX idx_unsynced
          ON $_table (synced, created_at)
        ''');
      },
    );
    return _db!;
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Persists [session] to local storage.  Safe to call multiple times with
  /// the same [sessionId] — subsequent calls are no-ops (INSERT OR IGNORE).
  Future<void> saveSession(StoredGameSession session) async {
    try {
      final db = await _getDb();
      await db.insert(
        _table,
        {
          'session_id': session.sessionId,
          'patient_id': session.patientProfileId,
          'game_type': session.gameType,
          'session_date': session.sessionDate.toIso8601String(),
          'synced': session.synced ? 1 : 0,
          'created_at': session.createdAt.toIso8601String(),
          'payload': json.encode(session.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      debugPrint(
          '[GameSessionRepository] saved: ${session.sessionId} (${session.gameType})');
    } catch (e) {
      debugPrint('[GameSessionRepository] saveSession error: $e');
    }
  }

  // ── Mark synced ───────────────────────────────────────────────────────────

  /// Called by [GameSyncService] after a successful backend POST.
  Future<void> markSynced(String sessionId) async {
    try {
      final db = await _getDb();
      await db.update(
        _table,
        {'synced': 1},
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
    } catch (e) {
      debugPrint('[GameSessionRepository] markSynced error: $e');
    }
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Returns all unsynced sessions, oldest-first, up to [limit].
  Future<List<StoredGameSession>> getUnsyncedSessions({int limit = 50}) async {
    try {
      final db = await _getDb();
      final rows = await db.query(
        _table,
        where: 'synced = ?',
        whereArgs: [0],
        orderBy: 'created_at ASC',
        limit: limit,
      );
      return rows
          .map((r) => StoredGameSession.fromJson(
              json.decode(r['payload'] as String) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[GameSessionRepository] getUnsyncedSessions error: $e');
      return [];
    }
  }

  /// Returns all sessions for [patientId], newest-first.
  Future<List<StoredGameSession>> getSessionsForPatient(
    String patientId, {
    String? gameType,
    int limit = 100,
  }) async {
    try {
      final db = await _getDb();
      final where = gameType != null
          ? 'patient_id = ? AND game_type = ?'
          : 'patient_id = ?';
      final whereArgs =
          gameType != null ? [patientId, gameType] : [patientId];
      final rows = await db.query(
        _table,
        where: where,
        whereArgs: whereArgs,
        orderBy: 'created_at DESC',
        limit: limit,
      );
      return rows
          .map((r) => StoredGameSession.fromJson(
              json.decode(r['payload'] as String) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[GameSessionRepository] getSessionsForPatient error: $e');
      return [];
    }
  }

  /// Total unsynced session count — useful for a background sync badge.
  Future<int> unsyncedCount() async {
    try {
      final db = await _getDb();
      final result = await db.rawQuery(
          'SELECT COUNT(*) as c FROM $_table WHERE synced = 0');
      return (result.first['c'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
