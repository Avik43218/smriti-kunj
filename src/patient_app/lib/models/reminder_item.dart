import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// Represents a single Daily Reminder in the patient app.
class ReminderItem {
  final String id;
  final String title;
  final String time;
  final String category;
  final String? dosage;
  final IconData icon;
  final Color categoryColor;
  bool isCompleted;
  final String? pairingCode;
  final String? createdAt;

  ReminderItem({
    required this.id,
    required this.title,
    required this.time,
    this.category = 'custom',
    this.dosage,
    IconData? icon,
    Color? categoryColor,
    this.isCompleted = false,
    this.pairingCode,
    this.createdAt,
  })  : icon = icon ?? _resolveIcon(category, title),
        categoryColor = categoryColor ?? _resolveColor(category);

  static IconData _resolveIcon(String category, String title) {
    final cat = category.toLowerCase().trim();
    final lowerTitle = title.toLowerCase();

    if (cat.contains('med') || lowerTitle.contains('medicine') || lowerTitle.contains('pill') || lowerTitle.contains('dose')) {
      return Icons.medication_rounded;
    }
    if (cat.contains('hydrat') || cat.contains('water') || lowerTitle.contains('water') || lowerTitle.contains('drink')) {
      return Icons.water_drop_rounded;
    }
    if (cat.contains('meal') || lowerTitle.contains('lunch') || lowerTitle.contains('breakfast') || lowerTitle.contains('dinner') || lowerTitle.contains('food')) {
      return Icons.restaurant_rounded;
    }
    if (lowerTitle.contains('walk') || lowerTitle.contains('stretch') || lowerTitle.contains('exercise')) {
      return Icons.directions_walk_rounded;
    }
    return Icons.notifications_active_rounded;
  }

  static Color _resolveColor(String category) {
    final cat = category.toLowerCase().trim();
    if (cat.contains('med')) {
      return AppColors.terracotta;
    }
    if (cat.contains('hydrat') || cat.contains('water')) {
      return AppColors.mugaGold;
    }
    if (cat.contains('meal')) {
      return AppColors.sageGreen;
    }
    return AppColors.terracotta;
  }

  /// Converts this [ReminderItem] into a Map for SQLite storage.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'time': time,
      'category': category,
      'dosage': dosage,
      'is_completed': isCompleted ? 1 : 0,
      'pairing_code': pairingCode,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  /// Recreates a [ReminderItem] from a SQLite row Map.
  factory ReminderItem.fromMap(Map<String, dynamic> map) {
    final cat = (map['category'] as String?) ?? 'custom';
    final titleStr = (map['title'] as String?) ?? 'Daily Reminder';
    return ReminderItem(
      id: map['id'] as String,
      title: titleStr,
      time: (map['time'] as String?) ?? '12:00 PM',
      category: cat,
      dosage: map['dosage'] as String?,
      isCompleted: (map['is_completed'] as int?) == 1,
      pairingCode: map['pairing_code'] as String?,
      createdAt: map['created_at'] as String?,
      icon: _resolveIcon(cat, titleStr),
      categoryColor: _resolveColor(cat),
    );
  }

  /// Recreates a [ReminderItem] from backend JSON.
  factory ReminderItem.fromJson(Map<String, dynamic> json, {String? pairingCode}) {
    final cat = (json['category'] as String?) ?? (json['type'] as String?) ?? 'custom';
    final titleStr = (json['title'] as String?) ??
        (json['label'] as String?) ??
        (json['name'] as String?) ??
        'Daily Reminder';
    final idStr = (json['id'] != null) ? json['id'].toString() : 'rem_${DateTime.now().millisecondsSinceEpoch}';
    final isDone = json['is_completed'] == true ||
        json['isCompleted'] == true ||
        json['status'] == 'completed';

    return ReminderItem(
      id: idStr,
      title: titleStr,
      time: (json['time'] as String?) ?? '12:00 PM',
      category: cat,
      dosage: json['dosage'] as String?,
      isCompleted: isDone,
      pairingCode: pairingCode ?? (json['pairing_code'] as String?),
      createdAt: DateTime.now().toIso8601String(),
      icon: _resolveIcon(cat, titleStr),
      categoryColor: _resolveColor(cat),
    );
  }

  ReminderItem copyWith({
    String? id,
    String? title,
    String? time,
    String? category,
    String? dosage,
    IconData? icon,
    Color? categoryColor,
    bool? isCompleted,
    String? pairingCode,
    String? createdAt,
  }) {
    return ReminderItem(
      id: id ?? this.id,
      title: title ?? this.title,
      time: time ?? this.time,
      category: category ?? this.category,
      dosage: dosage ?? this.dosage,
      icon: icon ?? this.icon,
      categoryColor: categoryColor ?? this.categoryColor,
      isCompleted: isCompleted ?? this.isCompleted,
      pairingCode: pairingCode ?? this.pairingCode,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
