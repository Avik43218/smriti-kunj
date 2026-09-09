import 'package:flutter/material.dart';

/// Represents a single card on the pair matching grid.
class PairCard {
  /// Unique instance id on the board (e.g., 'japi_1', 'japi_2').
  final String id;

  /// Logical pair group id (e.g., 'japi'). Two cards match if their [pairId] is equal.
  final String pairId;

  /// Category or grouping for analytics / semantic relevance.
  final String category;

  /// Multilingual translations for accessibility / captioning (e.g. {'en': 'Japi', 'as': 'জাপি'}).
  final Map<String, String> translations;

  /// Icon identifier string for generic icon cards.
  final String iconName;

  /// Local path or remote URL for caregiver-uploaded photos (nullable).
  final String? imagePath;

  /// Whether this card is rendered as a photo rather than a generic icon.
  final bool isPhoto;

  const PairCard({
    required this.id,
    required this.pairId,
    required this.category,
    required this.translations,
    this.iconName = 'help_outline',
    this.imagePath,
    this.isPhoto = false,
  });

  /// Retrieves translated name for [languageCode] ('as', 'en', etc.).
  String getName(String languageCode) {
    final translation = translations[languageCode];
    if (translation != null && translation.trim().isNotEmpty) {
      return translation;
    }
    final fallbackEn = translations['en'];
    if (fallbackEn != null && fallbackEn.trim().isNotEmpty) {
      return fallbackEn;
    }
    return pairId;
  }

  factory PairCard.fromJson(Map<String, dynamic> json) {
    final rawTranslations =
        json['translations'] as Map<String, dynamic>? ?? {};
    final mapTranslations = rawTranslations.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );

    return PairCard(
      id: json['id'] as String? ?? 'unknown',
      pairId: json['pair_id'] as String? ?? (json['id'] as String? ?? 'unknown'),
      category: json['category'] as String? ?? 'general',
      translations: mapTranslations,
      iconName: json['icon_name'] as String? ?? 'help_outline',
      imagePath: json['image_path'] as String?,
      isPhoto: json['is_photo'] as bool? ?? (json['image_path'] != null),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pair_id': pairId,
        'category': category,
        'translations': translations,
        'icon_name': iconName,
        if (imagePath != null) 'image_path': imagePath,
        'is_photo': isPhoto,
      };

  /// Material icon mapping for generic icon pairs.
  IconData get iconData {
    switch (iconName) {
      case 'style':
        return Icons.style;
      case 'texture':
        return Icons.texture;
      case 'eco':
        return Icons.eco;
      case 'pets':
        return Icons.pets;
      case 'music_note':
        return Icons.music_note;
      case 'local_florist':
        return Icons.local_florist;
      case 'grass':
        return Icons.grass;
      case 'wb_incandescent':
        return Icons.wb_incandescent;
      case 'circle':
        return Icons.circle;
      case 'opacity':
        return Icons.opacity;
      case 'face':
        return Icons.face;
      case 'person':
        return Icons.person;
      case 'spa':
        return Icons.spa;
      case 'grain':
        return Icons.grain;
      default:
        return Icons.auto_awesome;
    }
  }

  PairCard copyWithInstanceId(String newId) {
    return PairCard(
      id: newId,
      pairId: pairId,
      category: category,
      translations: translations,
      iconName: iconName,
      imagePath: imagePath,
      isPhoto: isPhoto,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PairCard && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
