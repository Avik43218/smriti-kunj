import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'difficulty_service.dart';

/// Local SQLite database persistence for pending difficulty settings.
///
/// Workflow:
/// 1. A game round finishes and the TFLite model generates a [DifficultyDecision].
/// 2. [DifficultyDatabaseService.saveDifficultySetting] inserts the record into SQLite.
/// 3. When the next game is launched, [DifficultyDatabaseService.consumeLatestDifficultySetting]
///    fetches the setting, applies it to the next game, and deletes the row from the database.
class DifficultyDatabaseService {
  static final DifficultyDatabaseService instance =
      DifficultyDatabaseService._internal();

  DifficultyDatabaseService._internal();
  factory DifficultyDatabaseService() => instance;

  static const _dbName = 'smriti_kunj_sessions.db';
  static const _table = 'pending_difficulty_settings';

  Database? _db;

  /// Visible for testing: inject custom or in-memory database.
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
      version: 2,
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
  }

  /// Inserts a newly evaluated [DifficultyDecision] into the SQLite database.
  Future<int> saveDifficultySetting(
    DifficultyDecision decision, {
    String rawJson = '',
  }) async {
    try {
      final db = await database;
      final id = await db.insert(
        _table,
        {
          'game_type': decision.gameType,
          'action': decision.action,
          'difficulty_delta': decision.difficultyDelta,
          'previous_difficulty': decision.previousDifficulty,
          'recommended_difficulty': decision.recommendedDifficulty,
          'confidence': decision.confidence,
          'raw_json': rawJson.isNotEmpty ? rawJson : jsonEncode(decision.toJson()),
          'created_at': decision.createdAt.toIso8601String(),
        },
      );

      debugPrint(
          '[DifficultyDatabaseService] Stored difficulty decision ID=$id in SQLite: '
          '${decision.action} (next level: ${decision.recommendedDifficulty}) for ${decision.gameType}');
      return id;
    } catch (e) {
      debugPrint('[DifficultyDatabaseService] Error saving difficulty setting: $e');
      return -1;
    }
  }

  /// Retrieves the latest pending difficulty setting and IMMEDIATELY deletes it
  /// from the SQLite database so it is only applied once.
  Future<DifficultyDecision?> consumeLatestDifficultySetting({
    String? gameType,
  }) async {
    try {
      final db = await database;

      // Query latest record
      final List<Map<String, dynamic>> rows = await db.query(
        _table,
        where: gameType != null ? 'game_type = ?' : null,
        whereArgs: gameType != null ? [gameType] : null,
        orderBy: 'id DESC',
        limit: 1,
      );

      if (rows.isEmpty) {
        // Fallback: If no game-specific record, check for any global/cross-game pending record
        if (gameType != null) {
          final List<Map<String, dynamic>> anyRows = await db.query(
            _table,
            orderBy: 'id DESC',
            limit: 1,
          );
          if (anyRows.isNotEmpty) {
            return await _consumeRow(db, anyRows.first);
          }
        }
        return null;
      }

      return await _consumeRow(db, rows.first);
    } catch (e) {
      debugPrint(
          '[DifficultyDatabaseService] Error consuming difficulty setting: $e');
      return null;
    }
  }

  Future<DifficultyDecision> _consumeRow(
    Database db,
    Map<String, dynamic> row,
  ) async {
    final int id = row['id'] as int;

    // Remove entry from SQLite database
    await db.delete(
      _table,
      where: 'id = ?',
      whereArgs: [id],
    );

    final decision = DifficultyDecision(
      action: row['action'] as String,
      difficultyDelta: (row['difficulty_delta'] as num).toInt(),
      previousDifficulty: (row['previous_difficulty'] as num).toInt(),
      recommendedDifficulty: (row['recommended_difficulty'] as num).toInt(),
      confidence: (row['confidence'] as num).toDouble(),
      distribution: {},
      gameType: row['game_type'] as String,
      featureVector: const [],
      createdAt: DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now(),
    );

    debugPrint(
        '[DifficultyDatabaseService] Consumed & removed setting ID=$id from SQLite -> '
        'Next game difficulty set to ${decision.recommendedDifficulty} (${decision.action})');

    return decision;
  }

  /// Peeks at the latest difficulty recommendation without removing it.
  Future<DifficultyDecision?> peekLatestDifficultySetting({
    String? gameType,
  }) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> rows = await db.query(
        _table,
        where: gameType != null ? 'game_type = ?' : null,
        whereArgs: gameType != null ? [gameType] : null,
        orderBy: 'id DESC',
        limit: 1,
      );

      if (rows.isEmpty) return null;
      final row = rows.first;
      return DifficultyDecision(
        action: row['action'] as String,
        difficultyDelta: (row['difficulty_delta'] as num).toInt(),
        previousDifficulty: (row['previous_difficulty'] as num).toInt(),
        recommendedDifficulty: (row['recommended_difficulty'] as num).toInt(),
        confidence: (row['confidence'] as num).toDouble(),
        distribution: {},
        gameType: row['game_type'] as String,
        featureVector: const [],
        createdAt: DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('[DifficultyDatabaseService] Error peeking setting: $e');
      return null;
    }
  }

  /// Returns the total count of pending difficulty settings in the queue.
  Future<int> getPendingCount() async {
    try {
      final db = await database;
      final result =
          await db.rawQuery('SELECT COUNT(*) as cnt FROM $_table');
      return (result.first['cnt'] as int?) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Deletes all pending difficulty settings (useful for reset/cleanup).
  Future<void> clearAll() async {
    try {
      final db = await database;
      await db.delete(_table);
    } catch (e) {
      debugPrint('[DifficultyDatabaseService] Error clearing table: $e');
    }
  }
}
