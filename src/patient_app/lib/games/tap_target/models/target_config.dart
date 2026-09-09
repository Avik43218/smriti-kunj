import 'package:flutter/material.dart';

/// A single target or distractor item in the Tap the Target game.
class TargetConfig {
  final String id;
  final String category;

  /// Visual grouping used for distractor similarity selection.
  /// Items in the same [visualGroup] look similar — used for medium/hard decoys.
  final String visualGroup;

  final Map<String, String> translations;
  final String iconName;

  const TargetConfig({
    required this.id,
    required this.category,
    required this.visualGroup,
    required this.translations,
    required this.iconName,
  });

  /// Resolved display name for the given language code. Falls back to English.
  String getName(String languageCode) {
    final t = translations[languageCode];
    if (t != null && t.trim().isNotEmpty) return t;
    final en = translations['en'];
    if (en != null && en.trim().isNotEmpty) return en;
    return id;
  }

  factory TargetConfig.fromJson(Map<String, dynamic> json) {
    final raw = json['translations'] as Map<String, dynamic>? ?? {};
    return TargetConfig(
      id: json['id'] as String? ?? 'unknown',
      category: json['category'] as String? ?? 'general',
      visualGroup: json['visual_group'] as String? ?? 'default',
      translations: raw.map((k, v) => MapEntry(k.toString(), v.toString())),
      iconName: json['icon_name'] as String? ?? 'circle',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'visual_group': visualGroup,
        'translations': translations,
        'icon_name': iconName,
      };

  /// Maps iconName string to MaterialIconData for dementia-safe rendering.
  IconData get iconData {
    switch (iconName) {
      case 'style':
        return Icons.style;
      case 'park':
        return Icons.park;
      case 'eco':
        return Icons.eco;
      case 'circle':
        return Icons.circle;
      case 'local_florist':
        return Icons.local_florist;
      case 'nature':
        return Icons.nature;
      case 'grain':
        return Icons.grain;
      case 'spa':
        return Icons.spa;
      case 'opacity':
        return Icons.opacity;
      case 'water_drop':
        return Icons.water_drop;
      case 'emoji_food_beverage':
        return Icons.emoji_food_beverage;
      default:
        return Icons.help_outline;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TargetConfig &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
