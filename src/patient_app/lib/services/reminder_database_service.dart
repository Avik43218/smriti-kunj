import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/reminder_item.dart';

/// SQLite persistence service for local patient app Daily Reminders.
///
/// Workflow:
/// 1. Reminders fetched from MongoDB backend are persisted into [table] (`patient_reminders`).
/// 2. Reminders are queried by the "Daily Reminders" screen from local SQLite storage.
/// 3. The "Clear Reminders" button flushes this local SQLite table.
class ReminderDatabaseService {
  static final ReminderDatabaseService instance = ReminderDatabaseService._internal();

  ReminderDatabaseService._internal();
  factory ReminderDatabaseService() => instance;

  static const _dbName = 'smriti_kunj_sessions.db';
  static const table = 'patient_reminders';

  Database? _db;

  @visibleForTesting
  void setDatabaseForTesting(Database db) {
    _db = db;
  }

  Future<Database> get database async {
    if (_db != null) {
      await createTableIfNotExists(_db!);
      return _db!;
    }
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);

    _db = await openDatabase(
      fullPath,
      version: 6,
      onCreate: (db, version) async {
        await createTableIfNotExists(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await createTableIfNotExists(db);
      },
    );
    await createTableIfNotExists(_db!);
    return _db!;
  }

  /// Creates the [patient_reminders] table if it does not already exist.
  Future<void> createTableIfNotExists(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id           TEXT PRIMARY KEY,
        title        TEXT NOT NULL,
        time         TEXT NOT NULL,
        category     TEXT NOT NULL,
        dosage       TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        pairing_code TEXT,
        created_at   TEXT NOT NULL
      )
    ''');
  }

  /// Persists a batch of [ReminderItem]s into local SQLite.
  /// Preserves already completed state locally if the backend item is not completed.
  Future<void> saveReminders(List<ReminderItem> items, {String? pairingCode}) async {
    if (items.isEmpty) return;
    final db = await database;

    await db.transaction((txn) async {
      for (final item in items) {
        final code = pairingCode ?? item.pairingCode;

        // Check if item already exists locally to preserve user completion status
        final existing = await txn.query(
          table,
          where: 'id = ?',
          whereArgs: [item.id],
          limit: 1,
        );

        int isCompletedInt = item.isCompleted ? 1 : 0;
        if (existing.isNotEmpty && !item.isCompleted) {
          final localCompleted = existing.first['is_completed'] as int?;
          if (localCompleted == 1) {
            isCompletedInt = 1;
          }
        }

        final map = item.toMap();
        map['is_completed'] = isCompletedInt;
        if (code != null && code.isNotEmpty) {
          map['pairing_code'] = code.toUpperCase();
        }

        await txn.insert(
          table,
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    debugPrint('[ReminderDatabaseService] Saved ${items.length} reminders to SQLite.');
  }

  /// Retrieves all reminders from SQLite. Optionally filtered by [pairingCode].
  Future<List<ReminderItem>> getReminders({String? pairingCode}) async {
    final db = await database;
    List<Map<String, dynamic>> rows;

    if (pairingCode != null && pairingCode.trim().isNotEmpty) {
      final clean = pairingCode.trim().toUpperCase();
      rows = await db.query(
        table,
        where: 'pairing_code = ? OR pairing_code IS NULL',
        whereArgs: [clean],
        orderBy: 'created_at ASC',
      );
    } else {
      rows = await db.query(
        table,
        orderBy: 'created_at ASC',
      );
    }

    return rows.map((r) => ReminderItem.fromMap(r)).toList();
  }

  /// Marks a specific reminder as completed or pending in SQLite.
  Future<void> toggleReminderCompleted(String id, bool isCompleted) async {
    final db = await database;
    await db.update(
      table,
      {'is_completed': isCompleted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('[ReminderDatabaseService] Toggled reminder $id completed: $isCompleted');
  }

  /// Flushes the local SQLite table containing those reminders.
  /// If [pairingCode] is provided, removes reminders for that pairing code;
  /// otherwise wipes the entire [patient_reminders] table.
  Future<int> clearReminders({String? pairingCode}) async {
    final db = await database;
    int deletedCount = 0;

    if (pairingCode != null && pairingCode.trim().isNotEmpty) {
      final clean = pairingCode.trim().toUpperCase();
      deletedCount = await db.delete(
        table,
        where: 'pairing_code = ? OR pairing_code IS NULL',
        whereArgs: [clean],
      );
    } else {
      deletedCount = await db.delete(table);
    }

    debugPrint('[ReminderDatabaseService] Flushed $deletedCount reminders from SQLite.');
    return deletedCount;
  }

  /// Returns total count of reminders stored in SQLite.
  Future<int> countReminders() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
    if (result.isNotEmpty) {
      return (result.first['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }
}
