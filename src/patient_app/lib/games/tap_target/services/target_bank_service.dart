import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import '../models/target_config.dart';

/// Difficulty configuration for one Tap the Target session.
/// All values are hardcoded for v1 — no adaptive logic yet.
///
/// --- Stub thresholds (not wired, for future adaptive engine) ---
///   Step-down: falsePositiveRate > 0.40 OR omissionRate > 0.50
///   Step-up:   scoreNormalized > 0.85 sustained over 3 sessions
class TapDifficulty {
  /// Number of distractor items shown alongside the target each trial.
  final int distractorCount;

  /// Target-appearance interval in seconds. Patient sees blank/distractors
  /// for this duration before the target card appears.
  final double appearanceIntervalSeconds;

  /// Total number of target appearances in the session.
  final int trialCount;

  /// How tightly distractors are matched to the target visually.
  /// Used by [TargetBankService.selectDistractors] to rank candidates.
  final DistractorSimilarity similarity;

  /// Numeric level for analytics: 1 = easy, 2 = medium, 3 = hard.
  final int level;

  const TapDifficulty._({
    required this.distractorCount,
    required this.appearanceIntervalSeconds,
    required this.trialCount,
    required this.similarity,
    required this.level,
  });

  /// Easy: 2 distractors, 3.0 s interval, 8 trials, visually distinct.
  static const easy = TapDifficulty._(
    distractorCount: 2,
    appearanceIntervalSeconds: 3.0,
    trialCount: 8,
    similarity: DistractorSimilarity.distinct,
    level: 1,
  );

  /// Medium: 4 distractors, 2.0 s interval, 10 trials, some similar visuals.
  static const medium = TapDifficulty._(
    distractorCount: 4,
    appearanceIntervalSeconds: 2.0,
    trialCount: 10,
    similarity: DistractorSimilarity.similar,
    level: 2,
  );

  /// Hard: 6 distractors, 1.2 s interval, 12 trials, semantically similar.
  static const hard = TapDifficulty._(
    distractorCount: 6,
    appearanceIntervalSeconds: 1.2,
    trialCount: 12,
    similarity: DistractorSimilarity.verySimilar,
    level: 3,
  );
}

enum DistractorSimilarity { distinct, similar, verySimilar }

// ─────────────────────────────────────────────────────────────────────────────

class TargetBankService {
  final Random _random;

  TargetBankService({Random? random}) : _random = random ?? Random();

  static const String _fallback = '''
{
  "items": [
    {"id":"japi","category":"cultural","visual_group":"woven_hat","translations":{"en":"Traditional Japi","as":"জাপি"},"icon_name":"style"},
    {"id":"bamboo_shoot","category":"vegetable","visual_group":"green_stem","translations":{"en":"Bamboo Shoot","as":"বাঁহৰ গাজ"},"icon_name":"eco"},
    {"id":"orange","category":"fruit","visual_group":"round_fruit","translations":{"en":"Orange","as":"কমলা"},"icon_name":"circle"},
    {"id":"lotus","category":"flower","visual_group":"flower","translations":{"en":"Lotus Flower","as":"পদুম ফুল"},"icon_name":"local_florist"},
    {"id":"green_chili","category":"vegetable","visual_group":"green_stem","translations":{"en":"Green Chili","as":"সেউজীয়া জলকীয়া"},"icon_name":"spa"},
    {"id":"papaya","category":"fruit","visual_group":"round_fruit","translations":{"en":"Papaya","as":"অমিতা"},"icon_name":"nature"},
    {"id":"turmeric","category":"spice","visual_group":"root","translations":{"en":"Turmeric Root","as":"হালধি"},"icon_name":"grain"},
    {"id":"mustard_oil","category":"household","visual_group":"bottle","translations":{"en":"Mustard Oil","as":"সৰিয়হৰ তেল"},"icon_name":"opacity"}
  ]
}
''';

  /// Loads target bank from [assets/data/target_bank.json], falls back to
  /// embedded data if the asset is unavailable.
  Future<List<TargetConfig>> loadTargetBank() async {
    String raw;
    try {
      raw = await rootBundle.loadString('assets/data/target_bank.json');
    } catch (_) {
      raw = _fallback;
    }
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final list = decoded['items'] as List<dynamic>? ?? [];
    return list
        .map((e) => TargetConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns a shuffled list of [difficulty.distractorCount] items from [bank]
  /// that are NOT the [target], ranked by visual similarity per difficulty.
  ///
  /// • [DistractorSimilarity.distinct] → different visualGroup AND category
  /// • [DistractorSimilarity.similar]  → prefer same visualGroup
  /// • [DistractorSimilarity.verySimilar] → prefer same visualGroup AND category
  List<TargetConfig> selectDistractors({
    required List<TargetConfig> bank,
    required TargetConfig target,
    required TapDifficulty difficulty,
  }) {
    final pool = bank.where((e) => e.id != target.id).toList();

    List<TargetConfig> candidates;

    switch (difficulty.similarity) {
      case DistractorSimilarity.distinct:
        // Prefer items that look nothing like the target.
        candidates = pool
            .where((e) =>
                e.visualGroup != target.visualGroup &&
                e.category != target.category)
            .toList();
        if (candidates.length < difficulty.distractorCount) {
          candidates = pool; // fall back to full pool
        }

      case DistractorSimilarity.similar:
        // Prefer same visualGroup.
        final same = pool
            .where((e) => e.visualGroup == target.visualGroup)
            .toList();
        final rest = pool
            .where((e) => e.visualGroup != target.visualGroup)
            .toList()
          ..shuffle(_random);
        candidates = [...same, ...rest];

      case DistractorSimilarity.verySimilar:
        // Prefer same visualGroup AND same category first.
        final best = pool
            .where((e) =>
                e.visualGroup == target.visualGroup &&
                e.category == target.category)
            .toList();
        final good = pool
            .where((e) =>
                e.visualGroup == target.visualGroup ||
                e.category == target.category)
            .where((e) => !best.contains(e))
            .toList();
        final rest = pool
            .where((e) => !best.contains(e) && !good.contains(e))
            .toList()
          ..shuffle(_random);
        candidates = [...best, ...good, ...rest];
    }

    candidates.shuffle(_random);
    return candidates.take(difficulty.distractorCount).toList();
  }
}
