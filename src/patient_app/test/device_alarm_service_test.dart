import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/models/reminder_item.dart';
import 'package:patient_app/services/device_alarm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceAlarmService Time Parsing Tests', () {
    test('parses 12-hour AM times correctly', () {
      final t1 = DeviceAlarmService.parseTimeString('8:00 AM');
      expect(t1, equals(const AlarmTime(hour: 8, minute: 0)));

      final t2 = DeviceAlarmService.parseTimeString('08:30 AM');
      expect(t2, equals(const AlarmTime(hour: 8, minute: 30)));

      final t3 = DeviceAlarmService.parseTimeString('10:45 am');
      expect(t3, equals(const AlarmTime(hour: 10, minute: 45)));
    });

    test('parses 12-hour PM times correctly', () {
      final t1 = DeviceAlarmService.parseTimeString('1:00 PM');
      expect(t1, equals(const AlarmTime(hour: 13, minute: 0)));

      final t2 = DeviceAlarmService.parseTimeString('5:30 PM');
      expect(t2, equals(const AlarmTime(hour: 17, minute: 30)));

      final t3 = DeviceAlarmService.parseTimeString('11:59 pm');
      expect(t3, equals(const AlarmTime(hour: 23, minute: 59)));
    });

    test('parses midnight (12:00 AM) and noon (12:00 PM) correctly', () {
      final midnight = DeviceAlarmService.parseTimeString('12:00 AM');
      expect(midnight, equals(const AlarmTime(hour: 0, minute: 0)));

      final midnightHalf = DeviceAlarmService.parseTimeString('12:30 AM');
      expect(midnightHalf, equals(const AlarmTime(hour: 0, minute: 30)));

      final noon = DeviceAlarmService.parseTimeString('12:00 PM');
      expect(noon, equals(const AlarmTime(hour: 12, minute: 0)));

      final noonHalf = DeviceAlarmService.parseTimeString('12:45 PM');
      expect(noonHalf, equals(const AlarmTime(hour: 12, minute: 45)));
    });

    test('parses 24-hour time strings correctly', () {
      final t1 = DeviceAlarmService.parseTimeString('13:30');
      expect(t1, equals(const AlarmTime(hour: 13, minute: 30)));

      final t2 = DeviceAlarmService.parseTimeString('08:00');
      expect(t2, equals(const AlarmTime(hour: 8, minute: 0)));

      final t3 = DeviceAlarmService.parseTimeString('00:00');
      expect(t3, equals(const AlarmTime(hour: 0, minute: 0)));

      final t4 = DeviceAlarmService.parseTimeString('23:45');
      expect(t4, equals(const AlarmTime(hour: 23, minute: 45)));
    });

    test('returns null for invalid time inputs', () {
      expect(DeviceAlarmService.parseTimeString(''), isNull);
      expect(DeviceAlarmService.parseTimeString('invalid_time'), isNull);
      expect(DeviceAlarmService.parseTimeString('25:00'), isNull);
      expect(DeviceAlarmService.parseTimeString('12:65 AM'), isNull);
    });
  });

  group('DeviceAlarmService MethodChannel Mock Tests', () {
    const channel = MethodChannel(DeviceAlarmService.channelName);
    final List<MethodCall> methodCalls = [];

    setUp(() {
      methodCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        switch (methodCall.method) {
          case 'isAlarmSupported':
            return true;
          case 'setDeviceAlarm':
            final args = methodCall.arguments as Map<dynamic, dynamic>? ?? {};
            return {
              'success': true,
              'label': args['label'],
              'hour': args['hour'],
              'minute': args['minute'],
              'everyday': true,
            };
          case 'setDailyAlarms':
            final args = methodCall.arguments as Map<dynamic, dynamic>? ?? {};
            final alarms = (args['alarms'] as List<dynamic>?) ?? [];
            return {
              'success': true,
              'scheduledCount': alarms.length,
              'everyday': true,
            };
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('setDeviceAlarm sends correct payload with everyday alarm contract', () async {
      final success = await DeviceAlarmService.instance.setDeviceAlarm(
        label: 'Morning Blood Pressure Tablet',
        hour: 8,
        minute: 30,
        skipUi: true,
      );

      expect(success, isTrue);
      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'setDeviceAlarm');
      expect(methodCalls.first.arguments['label'], 'Morning Blood Pressure Tablet');
      expect(methodCalls.first.arguments['hour'], 8);
      expect(methodCalls.first.arguments['minute'], 30);
      expect(methodCalls.first.arguments['skipUi'], isTrue);
    });

    test('syncRemindersToDeviceAlarms converts reminders into everyday alarms', () async {
      final items = [
        ReminderItem(
          id: 'med_1',
          title: 'Morning Blood Pressure Tablet',
          time: '8:00 AM',
          category: 'medication',
        ),
        ReminderItem(
          id: 'hyd_1',
          title: 'Warm Water Intake',
          time: '10:30 AM',
          category: 'hydration',
        ),
        ReminderItem(
          id: 'meal_1',
          title: 'Nutritious Lunch',
          time: '1:00 PM',
          category: 'meals',
        ),
        ReminderItem(
          id: 'cust_1',
          title: 'Evening Garden Walk',
          time: '5:00 PM',
          category: 'custom',
        ),
      ];

      final count = await DeviceAlarmService.instance.syncRemindersToDeviceAlarms(items);

      expect(count, 4);
      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'setDailyAlarms');

      final passedAlarms = methodCalls.first.arguments['alarms'] as List;
      expect(passedAlarms.length, 4);

      expect(passedAlarms[0]['label'], 'Morning Blood Pressure Tablet');
      expect(passedAlarms[0]['hour'], 8);
      expect(passedAlarms[0]['minute'], 0);

      expect(passedAlarms[1]['label'], 'Warm Water Intake');
      expect(passedAlarms[1]['hour'], 10);
      expect(passedAlarms[1]['minute'], 30);

      expect(passedAlarms[2]['label'], 'Nutritious Lunch');
      expect(passedAlarms[2]['hour'], 13);
      expect(passedAlarms[2]['minute'], 0);

      expect(passedAlarms[3]['label'], 'Evening Garden Walk');
      expect(passedAlarms[3]['hour'], 17);
      expect(passedAlarms[3]['minute'], 0);
    });
  });
}
