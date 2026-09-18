import 'package:flutter/material.dart';

/// MarketItem represents a single item in the Market Trip game bank.
class MarketItem {
  final String id;
  final String category;
  final String visualGroup;
  final Map<String, String> translations;
  final String iconName;
  final String? assetPath;

  const MarketItem({
    required this.id,
    required this.category,
    required this.visualGroup,
    required this.translations,
    required this.iconName,
    this.assetPath,
  });

  /// Get the translated name for a given language code (e.g. 'as', 'en').
  /// Falls back to English ('en') if translation is missing or empty.
  String getName(String languageCode) {
    final translation = translations[languageCode];
    if (translation != null && translation.trim().isNotEmpty) {
      return translation;
    }
    final fallbackEn = translations['en'];
    if (fallbackEn != null && fallbackEn.trim().isNotEmpty) {
      return fallbackEn;
    }
    return id;
  }

  factory MarketItem.fromJson(Map<String, dynamic> json) {
    final rawTranslations = json['translations'] as Map<String, dynamic>? ?? {};
    final mapTranslations = rawTranslations.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );

    return MarketItem(
      id: json['id'] as String? ?? 'unknown',
      category: json['category'] as String? ?? 'general',
      visualGroup: json['visual_group'] as String? ?? 'default',
      translations: mapTranslations,
      iconName: json['icon_name'] as String? ?? 'shopping_basket',
      assetPath: json['asset_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'visual_group': visualGroup,
      'translations': translations,
      'icon_name': iconName,
      if (assetPath != null) 'asset_path': assetPath,
    };
  }

  /// Maps iconName string to Material IconData for dementia-safe visual rendering.
  IconData get iconData {
    switch (iconName) {
      case 'eco':
        return Icons.eco;
      case 'opacity':
        return Icons.opacity;
      case 'spa':
        return Icons.spa;
      case 'emoji_food_beverage':
        return Icons.emoji_food_beverage;
      case 'grain':
        return Icons.grain;
      case 'style':
        return Icons.style;
      case 'nature':
        return Icons.nature;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'brightness_low':
        return Icons.brightness_low;
      case 'park':
        return Icons.park;
      case 'local_florist':
        return Icons.local_florist;
      case 'circle':
        return Icons.circle;
      case 'water_drop':
        return Icons.water_drop;
      case 'shopping_basket':
        return Icons.shopping_basket;
      case 'lightbulb':
        return Icons.lightbulb;
      case 'checkroom':
        return Icons.checkroom;
      default:
        return Icons.shopping_bag;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarketItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
