import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'difficulty_service.dart';

/// Local SQLite database persistence for pending difficulty settings across games.
///
/// Workflow:
/// 1. A game round finishes and the TFLite model generates a [DifficultyDecision].
/// 2. [DifficultyDatabaseService.saveDifficultySettingsForAllGames] calculates and stores the
///    next difficulty setting for each game ('market_trip', 'tap_target', 'pair_matching') in SQLite.
/// 3. Once any game is selected, [DifficultyDatabaseService.consumeAndClearForSelectedGame]
///    applies that game's difficulty setting and automatically deletes all pending settings from SQLite.
class DifficultyDatabaseService {
  static final DifficultyDatabaseService instance =
      DifficultyDatabaseService._internal();

  DifficultyDatabaseService._internal();
  factory DifficultyDatabaseService() => instance;

  static const _dbName = 'smriti_kunj_sessions.db';
  static const _table = 'pending_difficulty_settings';
  static const _levelsTable = 'game_current_levels';

  static const List<String> supportedGames = [
    'market_trip',
    'tap_target',
    'pair_matching',
  ];

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
      version: 3,
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_levelsTable (
        game_type TEXT PRIMARY KEY,
        level     INTEGER NOT NULL
      )
    ''');
  }

  /// Returns current baseline difficulty level (1 = easy, 2 = medium, 3 = hard) for a game.
  Future<int> getCurrentLevel(String gameType) async {
    try {
      final db = await database;
      final rows = await db.query(
        _levelsTable,
        where: 'game_type = ?',
        whereArgs: [gameType],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return (rows.first['level'] as num).toInt();
      }
    } catch (e) {
      debugPrint('[DifficultyDatabaseService] Error fetching current level for $gameType: $e');
    }
    return 1; // Default to Easy
  }

  /// Persists the active difficulty level for a game.
  Future<void> setCurrentLevel(String gameType, int level) async {
    try {
      final db = await database;
      await db.insert(
        _levelsTable,
        {
          'game_type': gameType,
          'level': level.clamp(1, 3),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[DifficultyDatabaseService] Error updating level for $gameType: $e');
    }
  }

  /// Saves next difficulty settings for EACH supported game in SQLite after one round completes.
  Future<void> saveDifficultySettingsForAllGames(
    DifficultyDecision decision, {
    String rawJson = '',
  }) async {
    try {
      final db = await database;

      // Clear any prior unconsumed settings first so only the freshest round recommendations exist
      await db.delete(_table);

      for (final game in supportedGames) {
        final currentLevel = await getCurrentLevel(game);
        final nextLevel = (currentLevel + decision.difficultyDelta).clamp(1, 3);

        await db.insert(
          _table,
          {
            'game_type': game,
            'action': decision.action,
            'difficulty_delta': decision.difficultyDelta,
            'previous_difficulty': currentLevel,
            'recommended_difficulty': nextLevel,
            'confidence': decision.confidence,
            'raw_json': rawJson.isNotEmpty ? rawJson : jsonEncode(decision.toJson()),
            'created_at': decision.createdAt.toIso8601String(),
          },
        );

        // Keep baseline level updated
        await setCurrentLevel(game, nextLevel);

        debugPrint(
            '[DifficultyDatabaseService] Stored next difficulty for $game: '
            'Level $nextLevel (${decision.action}, delta: ${decision.difficultyDelta})');
      }
    } catch (e) {
      debugPrint('[DifficultyDatabaseService] Error saving settings for all games: $e');
    }
  }

  /// Inserts a single evaluated [DifficultyDecision] into the SQLite database.
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

      await setCurrentLevel(decision.gameType, decision.recommendedDifficulty);

      debugPrint(
          '[DifficultyDatabaseService] Stored difficulty decision ID=$id in SQLite: '
          '${decision.action} (next level: ${decision.recommendedDifficulty}) for ${decision.gameType}');
      return id;
    } catch (e) {
      debugPrint('[DifficultyDatabaseService] Error saving difficulty setting: $e');
      return -1;
    }
  }

  /// Retrieves the difficulty setting for [selectedGameType] and AUTOMATICALLY REMOVES
  /// all pending difficulty entries from the database once that game is selected.
  Future<DifficultyDecision?> consumeAndClearForSelectedGame(
    String selectedGameType,
  ) async {
    try {
      final db = await database;

      // 1. Find the setting queued for this game (or newest record)
      final List<Map<String, dynamic>> rows = await db.query(
        _table,
        where: 'game_type = ?',
        whereArgs: [selectedGameType],
        orderBy: 'id DESC',
        limit: 1,
      );

      Map<String, dynamic>? selectedRow;
      if (rows.isNotEmpty) {
        selectedRow = rows.first;
      } else {
        // Fallback: check any pending record
        final anyRows = await db.query(_table, orderBy: 'id DESC', limit: 1);
        if (anyRows.isNotEmpty) {
          selectedRow = anyRows.first;
        }
      }

      // 2. AUTOMATICALLY REMOVE all pending difficulty settings from the database
      final deletedCount = await db.delete(_table);
      debugPrint(
          '[DifficultyDatabaseService] Game "$selectedGameType" selected. '
          'Automatically removed $deletedCount pending difficulty entries from SQLite.');

      if (selectedRow != null) {
        final decision = DifficultyDecision(
          action: selectedRow['action'] as String,
          difficultyDelta: (selectedRow['difficulty_delta'] as num).toInt(),
          previousDifficulty: (selectedRow['previous_difficulty'] as num).toInt(),
          recommendedDifficulty: (selectedRow['recommended_difficulty'] as num).toInt(),
          confidence: (selectedRow['confidence'] as num).toDouble(),
          distribution: {},
          gameType: selectedGameType,
          featureVector: const [],
          createdAt: DateTime.tryParse(selectedRow['created_at'].toString()) ?? DateTime.now(),
        );

        await setCurrentLevel(selectedGameType, decision.recommendedDifficulty);
        return decision;
      }

      // If no pending row was found, return a decision matching current baseline level
      final currentLevel = await getCurrentLevel(selectedGameType);
      return DifficultyDecision(
        action: 'Maintain (0)',
        difficultyDelta: 0,
        previousDifficulty: currentLevel,
        recommendedDifficulty: currentLevel,
        confidence: 1.0,
        distribution: {},
        gameType: selectedGameType,
        featureVector: const [],
      );
    } catch (e) {
      debugPrint('[DifficultyDatabaseService] Error consuming and clearing for $selectedGameType: $e');
      return null;
    }
  }

  /// Retrieves the latest pending difficulty setting and deletes it.
  Future<DifficultyDecision?> consumeLatestDifficultySetting({
    String? gameType,
  }) async {
    if (gameType != null) {
      return consumeAndClearForSelectedGame(gameType);
    }
    try {
      final db = await database;
      final List<Map<String, dynamic>> rows = await db.query(
        _table,
        orderBy: 'id DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      await db.delete(_table);
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
      debugPrint('[DifficultyDatabaseService] Error consuming difficulty setting: $e');
      return null;
    }
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
