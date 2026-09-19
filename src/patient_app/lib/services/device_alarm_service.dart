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

/// Service to interface with native mobile device alarm system via AlarmManager.
///
/// Converts patient daily reminders into native device alarms repeating everyday.
class DeviceAlarmService {
  static final DeviceAlarmService instance = DeviceAlarmService._internal();

  DeviceAlarmService._internal();
  factory DeviceAlarmService() => instance;

  static const String channelName = 'com.smritikunj.patient_app/alarm';
  static const MethodChannel _channel = MethodChannel(channelName);

  /// Generates a deterministic positive 31-bit integer hash code
  /// matching Java's String.hashCode() & 0x7FFFFFFF.
  static int computeRequestCode(String reminderId, [String? date]) {
    final key = (date != null && date.isNotEmpty) ? '$reminderId$date' : reminderId;
    var hash = 0;
    for (var i = 0; i < key.length; i++) {
      hash = (31 * hash + key.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return hash;
  }

  /// Formats date to 'yyyy-MM-dd' for request code hashing.
  static String formatDateKey(dynamic date) {
    if (date is DateTime) {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
    return date?.toString() ?? '';
  }

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

  /// Sets a single recurring everyday alarm on the mobile device via AlarmManager.
  Future<bool> setDeviceAlarm({
    required String label,
    required int hour,
    required int minute,
    String? reminderId,
    dynamic date,
    bool isRecurring = true,
    bool skipUi = true,
  }) async {
    final id = reminderId ?? label;
    final dateStr = date != null ? formatDateKey(date) : null;
    final requestCode = computeRequestCode(id, dateStr);
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('setDeviceAlarm', {
        'reminderId': id,
        'label': label,
        'hour': hour,
        'minute': minute,
        'date': dateStr,
        'requestCode': requestCode,
        'isRecurring': isRecurring,
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
  /// repeating everyday via AlarmManager.
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

      final requestCode = computeRequestCode(reminder.id);
      alarmsList.add({
        'id': reminder.id,
        'reminderId': reminder.id,
        'label': reminder.title,
        'hour': parsedTime.hour,
        'minute': parsedTime.minute,
        'requestCode': requestCode,
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

  /// Cancels an alarm for a specific single date.
  Future<bool> cancelOnce(String reminderId, dynamic date) async {
    final dateStr = formatDateKey(date);
    final requestCode = computeRequestCode(reminderId, dateStr);
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('cancelOnce', {
        'reminderId': reminderId,
        'date': dateStr,
        'requestCode': requestCode,
      });
      final success = res?['success'] == true;
      debugPrint('[DeviceAlarmService] cancelOnce("$reminderId", "$dateStr") -> $success');
      return success;
    } catch (e) {
      debugPrint('[DeviceAlarmService] cancelOnce failed: $e');
      return false;
    }
  }

  /// Cancels recurring device alarm schedule for a reminder.
  Future<bool> cancelRecurring(String reminderId) async {
    final requestCode = computeRequestCode(reminderId);
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('cancelRecurring', {
        'reminderId': reminderId,
        'requestCode': requestCode,
      });
      final success = res?['success'] == true;
      debugPrint('[DeviceAlarmService] cancelRecurring("$reminderId") -> $success');
      return success;
    } catch (e) {
      debugPrint('[DeviceAlarmService] cancelRecurring failed: $e');
      return false;
    }
  }

  /// Completely removes/deletes the alarm from device scheduling.
  Future<bool> deleteAlarm(String reminderId, {dynamic date}) async {
    final dateStr = date != null ? formatDateKey(date) : null;
    final requestCode = computeRequestCode(reminderId);
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('deleteAlarm', {
        'reminderId': reminderId,
        'date': dateStr,
        'requestCode': requestCode,
      });
      final success = res?['success'] == true;
      debugPrint('[DeviceAlarmService] deleteAlarm("$reminderId") -> $success');
      return success;
    } catch (e) {
      debugPrint('[DeviceAlarmService] deleteAlarm failed: $e');
      return false;
    }
  }

  /// Directly cancels an alarm by its numeric request code.
  Future<bool> cancelByRequestCode(int requestCode) async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('cancelByRequestCode', {
        'requestCode': requestCode,
      });
      final success = res?['success'] == true;
      debugPrint('[DeviceAlarmService] cancelByRequestCode($requestCode) -> $success');
      return success;
    } catch (e) {
      debugPrint('[DeviceAlarmService] cancelByRequestCode failed: $e');
      return false;
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
