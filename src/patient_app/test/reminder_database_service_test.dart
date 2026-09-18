import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:patient_app/models/reminder_item.dart';
import 'package:patient_app/services/reminder_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('ReminderItem Model Tests', () {
    test('ReminderItem correctly serializes toMap and deserializes fromMap for SQLite', () {
      final item = ReminderItem(
        id: 'med_101',
        title: 'Morning Medicine',
        time: '8:00 AM',
        category: 'medication',
        dosage: '1 Tablet',
        isCompleted: false,
        pairingCode: 'PAIR-652759',
      );

      final map = item.toMap();
      expect(map['id'], 'med_101');
      expect(map['title'], 'Morning Medicine');
      expect(map['time'], '8:00 AM');
      expect(map['category'], 'medication');
      expect(map['dosage'], '1 Tablet');
      expect(map['is_completed'], 0);
      expect(map['pairing_code'], 'PAIR-652759');

      final restored = ReminderItem.fromMap(map);
      expect(restored.id, 'med_101');
      expect(restored.title, 'Morning Medicine');
      expect(restored.time, '8:00 AM');
      expect(restored.category, 'medication');
      expect(restored.dosage, '1 Tablet');
      expect(restored.isCompleted, false);
      expect(restored.pairingCode, 'PAIR-652759');
    });

    test('ReminderItem parses backend MongoDB JSON format correctly', () {
      final json = {
        'id': 'hyd_1',
        'title': 'Glass of Warm Water',
        'time': '10:30 AM',
        'type': 'hydration',
        'is_completed': true,
      };

      final item = ReminderItem.fromJson(json, pairingCode: 'PAIR-652759');
      expect(item.id, 'hyd_1');
      expect(item.title, 'Glass of Warm Water');
      expect(item.time, '10:30 AM');
      expect(item.category, 'hydration');
      expect(item.isCompleted, true);
      expect(item.pairingCode, 'PAIR-652759');
    });
  });

  group('ReminderDatabaseService SQLite Tests', () {
    late Database inMemoryDb;
    late ReminderDatabaseService dbService;

    setUp(() async {
      dbService = ReminderDatabaseService.instance;
      databaseFactory = databaseFactoryFfi;
      inMemoryDb = await databaseFactory.openDatabase(inMemoryDatabasePath);

      await dbService.createTableIfNotExists(inMemoryDb);
      dbService.setDatabaseForTesting(inMemoryDb);
    });

    tearDown(() async {
      await inMemoryDb.close();
    });

    test('saveReminders stores reminders into SQLite and getReminders retrieves them', () async {
      final items = [
        ReminderItem(
          id: 'med_1',
          title: 'Morning Medicine',
          time: '8:00 AM',
          category: 'medication',
          pairingCode: 'PAIR-652759',
        ),
        ReminderItem(
          id: 'hyd_1',
          title: 'Glass of Warm Water',
          time: '10:30 AM',
          category: 'hydration',
          pairingCode: 'PAIR-652759',
        ),
      ];

      await dbService.saveReminders(items, pairingCode: 'PAIR-652759');

      final count = await dbService.countReminders();
      expect(count, 2);

      final fetched = await dbService.getReminders(pairingCode: 'PAIR-652759');
      expect(fetched.length, 2);
      expect(fetched[0].id, 'med_1');
      expect(fetched[0].title, 'Morning Medicine');
      expect(fetched[1].id, 'hyd_1');
      expect(fetched[1].title, 'Glass of Warm Water');
    });

    test('toggleReminderCompleted updates is_completed status in SQLite', () async {
      final items = [
        ReminderItem(
          id: 'meal_1',
          title: 'Lunch',
          time: '1:00 PM',
          category: 'meals',
          isCompleted: false,
        ),
      ];

      await dbService.saveReminders(items);
      expect((await dbService.getReminders()).first.isCompleted, false);

      await dbService.toggleReminderCompleted('meal_1', true);
      expect((await dbService.getReminders()).first.isCompleted, true);

      await dbService.toggleReminderCompleted('meal_1', false);
      expect((await dbService.getReminders()).first.isCompleted, false);
    });

    test('clearReminders flushes all reminders from local SQLite table', () async {
      final items = [
        ReminderItem(
          id: 'rem_1',
          title: 'Medicine',
          time: '8:00 AM',
          pairingCode: 'PAIR-652759',
        ),
        ReminderItem(
          id: 'rem_2',
          title: 'Water',
          time: '10:00 AM',
          pairingCode: 'PAIR-652759',
        ),
        ReminderItem(
          id: 'rem_3',
          title: 'Walk',
          time: '5:00 PM',
          pairingCode: 'PAIR-652759',
        ),
      ];

      await dbService.saveReminders(items, pairingCode: 'PAIR-652759');
      expect(await dbService.countReminders(), 3);

      final deleted = await dbService.clearReminders(pairingCode: 'PAIR-652759');
      expect(deleted, 3);

      final remaining = await dbService.getReminders(pairingCode: 'PAIR-652759');
      expect(remaining.isEmpty, true);
      expect(await dbService.countReminders(), 0);
    });
  });
}
