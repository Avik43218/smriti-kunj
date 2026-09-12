import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/reminder_item.dart';

/// Represents parsed 24-hour time components for alarm scheduling.
class AlarmTime {
  final int hour; // 0 - 23
  final int minute; // 0 - 59

  const AlarmTime({
    required this.hour,
    required this.minute,
  });

  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlarmTime &&
          runtimeType == other.runtimeType &&
          hour == other.hour &&
          minute == other.minute;

  @override
  int get hashCode => hour.hashCode ^ minute.hashCode;
}

/// Service to interface with native mobile device alarm system (Android Clock / AlarmClock).
///
/// Converts patient daily reminders into native device alarms repeating everyday.
class DeviceAlarmService {
  static final DeviceAlarmService instance = DeviceAlarmService._internal();

  DeviceAlarmService._internal();
  factory DeviceAlarmService() => instance;

  static const String channelName = 'com.smritikunj.patient_app/alarm';
  static const MethodChannel _channel = MethodChannel(channelName);

  /// Checks if the native alarm provider is supported on the current device.
  Future<bool> isAlarmSupported() async {
    try {
      final supported = await _channel.invokeMethod<bool>('isAlarmSupported');
      return supported ?? false;
    } catch (e) {
      debugPrint('[DeviceAlarmService] isAlarmSupported error or unsupported platform: $e');
      return false;
    }
  }

  /// Sets a single recurring everyday alarm on the mobile device.
  Future<bool> setDeviceAlarm({
    required String label,
    required int hour,
    required int minute,
    bool skipUi = true,
  }) async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('setDeviceAlarm', {
        'label': label,
        'hour': hour,
        'minute': minute,
        'skipUi': skipUi,
      });
      final success = res?['success'] == true;
      debugPrint('[DeviceAlarmService] setDeviceAlarm("$label", $hour:$minute) -> $success');
      return success;
    } catch (e) {
      debugPrint('[DeviceAlarmService] setDeviceAlarm failed: $e');
      return false;
    }
  }

  /// Converts and schedules a list of [ReminderItem]s as native device alarms
  /// repeating everyday.
  ///
  /// Returns the number of successfully parsed and scheduled alarms.
  Future<int> syncRemindersToDeviceAlarms(
    List<ReminderItem> reminders, {
    bool skipUi = true,
  }) async {
    if (reminders.isEmpty) return 0;

    final List<Map<String, dynamic>> alarmsList = [];

    for (final reminder in reminders) {
      final parsedTime = parseTimeString(reminder.time);
      if (parsedTime == null) {
        debugPrint('[DeviceAlarmService] Could not parse time "${reminder.time}" for reminder "${reminder.title}"');
        continue;
      }

      alarmsList.add({
        'label': reminder.title,
        'hour': parsedTime.hour,
        'minute': parsedTime.minute,
        'skipUi': skipUi,
      });
    }

    if (alarmsList.isEmpty) return 0;

    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('setDailyAlarms', {
        'alarms': alarmsList,
        'skipUi': skipUi,
      });

      final scheduledCount = (res?['scheduledCount'] as num?)?.toInt() ?? alarmsList.length;
      debugPrint('[DeviceAlarmService] Successfully dispatched $scheduledCount everyday alarms to device.');
      return scheduledCount;
    } catch (e) {
      debugPrint('[DeviceAlarmService] setDailyAlarms failed: $e');
      // Graceful fallback for non-Android environments / tests
      return 0;
    }
  }

  /// Parses 12-hour AM/PM and 24-hour time strings into [AlarmTime].
  ///
  /// Examples:
  /// - "8:00 AM" -> AlarmTime(hour: 8, minute: 0)
  /// - "12:00 PM" -> AlarmTime(hour: 12, minute: 0)
  /// - "12:00 AM" -> AlarmTime(hour: 0, minute: 0)
  /// - "1:30 PM" -> AlarmTime(hour: 13, minute: 30)
  /// - "17:45" -> AlarmTime(hour: 17, minute: 45)
  /// - "9:15" -> AlarmTime(hour: 9, minute: 15)
  static AlarmTime? parseTimeString(String raw) {
    final cleaned = raw.trim().toUpperCase();
    if (cleaned.isEmpty) return null;

    final isPm = cleaned.contains('PM');
    final isAm = cleaned.contains('AM');

    // Remove AM / PM labels to isolate numeric portions
    final numPart = cleaned
        .replaceAll('AM', '')
        .replaceAll('PM', '')
        .replaceAll(RegExp(r'[^0-9:]'), '')
        .trim();

    final parts = numPart.split(':');
    if (parts.isEmpty) return null;

    final parsedHour = int.tryParse(parts[0]);
    if (parsedHour == null) return null;

    int parsedMinute = 0;
    if (parts.length > 1) {
      parsedMinute = int.tryParse(parts[1]) ?? 0;
    }

    int hour24 = parsedHour;

    if (isPm || isAm) {
      // 12-hour logic
      if (isPm && parsedHour < 12) {
        hour24 = parsedHour + 12;
      } else if (isAm && parsedHour == 12) {
        hour24 = 0;
      }
    }

    // Clamp / validate ranges
    if (hour24 < 0 || hour24 > 23 || parsedMinute < 0 || parsedMinute > 59) {
      return null;
    }

    return AlarmTime(hour: hour24, minute: parsedMinute);
  }
}
