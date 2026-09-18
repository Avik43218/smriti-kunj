import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import '../models/pair_card.dart';

/// Difficulty configuration for one Pair Matching session.
/// Hardcoded 3 fixed levels for v1 — no adaptive logic yet.
class PairDifficulty {
  /// Number of unique pairs (4, 6, or 8).
  final int pairCount;

  /// Numeric level for analytics: 1 = easy, 2 = medium, 3 = hard.
  final int level;

  /// Grid column count recommendation.
  final int gridColumns;

  const PairDifficulty._({
    required this.pairCount,
    required this.level,
    required this.gridColumns,
  });

  /// Easy: 4 pairs (8 cards, 2x4 grid)
  static const easy = PairDifficulty._(pairCount: 4, level: 1, gridColumns: 2);

  /// Medium: 6 pairs (12 cards, 3x4 grid)
  static const medium = PairDifficulty._(pairCount: 6, level: 2, gridColumns: 3);

  /// Hard: 8 pairs (16 cards, 4x4 grid)
  static const hard = PairDifficulty._(pairCount: 8, level: 3, gridColumns: 4);
}

// ─────────────────────────────────────────────────────────────────────────────
// Abstract PairCardSource & Implementations
// ─────────────────────────────────────────────────────────────────────────────

/// Abstract contract for providing pair matching card content.
abstract class PairCardSource {
  /// Returns whether caregiver-uploaded photo pairs exist for this patient profile.
  Future<bool> hasCaregiverPhotos(String patientProfileId);

  /// Loads available base card definitions.
  Future<List<PairCard>> loadCards(String patientProfileId);

  /// Denotes whether this source provides face-name / photo content.
  bool get isPhotoVariant;
}

/// Active default source loading culturally-relevant icon pairs from JSON asset.
class GenericIconSource implements PairCardSource {
  static const String fallbackJson = '''
{
  "items": [
    {"id":"japi","category":"cultural","icon_name":"style","translations":{"en":"Traditional Japi","as":"জাপি"}},
    {"id":"gamusa","category":"cultural","icon_name":"texture","translations":{"en":"Gamosa","as":"গামোচা"}},
    {"id":"tea_leaf","category":"nature","icon_name":"eco","translations":{"en":"Tea Leaves","as":"চাহ পাত"}},
    {"id":"rhino","category":"nature","icon_name":"pets","translations":{"en":"Rhino","as":"গঁড়"}},
    {"id":"dhol","category":"music","icon_name":"music_note","translations":{"en":"Bihu Dhol","as":"ঢোল"}},
    {"id":"lotus","category":"flower","icon_name":"local_florist","translations":{"en":"Lotus Flower","as":"পদুম ফুল"}},
    {"id":"bamboo_shoot","category":"food","icon_name":"grass","translations":{"en":"Bamboo Shoot","as":"বাঁহৰ গাজ"}},
    {"id":"earthen_lamp","category":"household","icon_name":"wb_incandescent","translations":{"en":"Earthen Lamp","as":"মাটিৰ চাকি"}},
    {"id":"orange","category":"fruit","icon_name":"circle","translations":{"en":"Orange","as":"কমলা"}},
    {"id":"mustard_oil","category":"household","icon_name":"opacity","translations":{"en":"Mustard Oil","as":"সৰিয়হৰ তেল"}}
  ]
}
''';

  @override
  bool get isPhotoVariant => false;

  @override
  Future<bool> hasCaregiverPhotos(String patientProfileId) async => false;

  @override
  Future<List<PairCard>> loadCards(String patientProfileId) async {
    String raw;
    try {
      raw = await rootBundle.loadString('assets/data/pair_bank.json');
    } catch (_) {
      raw = fallbackJson;
    }

    final decoded = json.decode(raw) as Map<String, dynamic>;
    final list = decoded['items'] as List<dynamic>? ?? [];
    return list
        .map((e) => PairCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// Interface seam for future caregiver photo uploads.
///
/// TODO: Wire to Caregiver API / local photo cache when photo upload module is connected.
class CaregiverPhotoSource implements PairCardSource {
  @override
  bool get isPhotoVariant => true;

  @override
  Future<bool> hasCaregiverPhotos(String patientProfileId) async {
    // Caregiver-side photo upload isn't connected yet.
    // When connected, check local SQLite / backend API for this patientProfileId.
    return false;
  }

  @override
  Future<List<PairCard>> loadCards(String patientProfileId) async {
    // When connected, map caregiver photos to PairCard instances with imagePath and isPhoto: true.
    return [];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Deck Result & Service
// ─────────────────────────────────────────────────────────────────────────────

class PairDeckResult {
  final List<PairCard> cards;
  final bool usedFaceNameVariant;

  const PairDeckResult({
    required this.cards,
    required this.usedFaceNameVariant,
  });
}

class PairBankService {
  final PairCardSource _photoSource;
  final PairCardSource _genericSource;
  final Random _random;

  PairBankService({
    PairCardSource? photoSource,
    PairCardSource? genericSource,
    Random? random,
  })  : _photoSource = photoSource ?? CaregiverPhotoSource(),
        _genericSource = genericSource ?? GenericIconSource(),
        _random = random ?? Random();

  /// Checks for caregiver photos first; if sufficient pairs exist, uses them.
  /// Otherwise, falls back to the generic icon bank.
  Future<PairDeckResult> loadDeck({
    required String patientProfileId,
    required PairDifficulty difficulty,
  }) async {
    // 1. Check caregiver photos first
    try {
      if (await _photoSource.hasCaregiverPhotos(patientProfileId)) {
        final photoCards = await _photoSource.loadCards(patientProfileId);
        if (photoCards.length >= difficulty.pairCount) {
          final deck = _prepareDeck(photoCards, difficulty.pairCount);
          return PairDeckResult(cards: deck, usedFaceNameVariant: true);
        }
      }
    } catch (_) {
      // On error, seamlessly fallback to generic
    }

    // 2. Fallback to generic icon bank
    final genericCards = await _genericSource.loadCards(patientProfileId);
    final deck = _prepareDeck(genericCards, difficulty.pairCount);
    return PairDeckResult(cards: deck, usedFaceNameVariant: false);
  }

  /// Selects [pairCount] unique cards from [pool], generates 2 instances of each, and shuffles.
  List<PairCard> _prepareDeck(List<PairCard> pool, int pairCount) {
    final shuffledPool = List<PairCard>.from(pool)..shuffle(_random);
    final selected = shuffledPool.take(pairCount).toList();

    final List<PairCard> deck = [];
    for (final base in selected) {
      deck.add(base.copyWithInstanceId('${base.pairId}_a'));
      deck.add(base.copyWithInstanceId('${base.pairId}_b'));
    }

    deck.shuffle(_random);
    return deck;
  }
}
