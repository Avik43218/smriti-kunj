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
  /// Number of distractor items in the candidate pool.
  final int distractorCount;

  /// Display interval in seconds per card before cycling to the next.
  final double appearanceIntervalSeconds;

  /// Target frequency cadence (e.g. 4 means target appears roughly 1 in 4 cards).
  final int targetFrequency;

  /// Total number of card presentations in the session (distractors + targets).
  final int trialCount;

  /// How tightly distractors are matched to the target visually.
  /// Used by [TargetBankService.selectDistractors] to rank candidates.
  final DistractorSimilarity similarity;

  /// Numeric level for analytics: 1 = easy, 2 = medium, 3 = hard.
  final int level;

  const TapDifficulty._({
    required this.distractorCount,
    required this.appearanceIntervalSeconds,
    required this.targetFrequency,
    required this.trialCount,
    required this.similarity,
    required this.level,
  });

  /// Easy: 2.5 s interval, 1-in-4 frequency, 16 total cards, visually distinct distractors.
  static const easy = TapDifficulty._(
    distractorCount: 6,
    appearanceIntervalSeconds: 2.5,
    targetFrequency: 4,
    trialCount: 16,
    similarity: DistractorSimilarity.distinct,
    level: 1,
  );

  /// Medium: 1.8 s interval, 1-in-5 frequency, 20 total cards, similar visual groups.
  static const medium = TapDifficulty._(
    distractorCount: 6,
    appearanceIntervalSeconds: 1.8,
    targetFrequency: 5,
    trialCount: 20,
    similarity: DistractorSimilarity.similar,
    level: 2,
  );

  /// Hard: 1.2 s interval, 1-in-6 frequency, 24 total cards, semantically & visually very similar.
  static const hard = TapDifficulty._(
    distractorCount: 6,
    appearanceIntervalSeconds: 1.2,
    targetFrequency: 6,
    trialCount: 24,
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

  /// Generates the full sequence of [TargetConfig] cards to display in the single-card cycle.
  ///
  /// Distributes target appearances based on [difficulty.targetFrequency] across [difficulty.trialCount]
  /// total cards, filling all other positions with distractors filtered by [difficulty.similarity].
  List<TargetConfig> generateCardSequence({
    required List<TargetConfig> bank,
    required TargetConfig target,
    required TapDifficulty difficulty,
  }) {
    final distractors = selectDistractors(
      bank: bank,
      target: target,
      difficulty: difficulty,
    );

    final totalCards = difficulty.trialCount;
    final cadence = max(2, difficulty.targetFrequency);
    final sequence = List<TargetConfig?>.filled(totalCards, null);

    // Distribute targets: 1 target in every block of [cadence] cards
    for (int blockStart = 0; blockStart < totalCards; blockStart += cadence) {
      final blockEnd = min(blockStart + cadence, totalCards);
      final blockSize = blockEnd - blockStart;
      if (blockSize <= 0) break;

      // In the first block, avoid placing target at index 0 so user sees at least 1 lead-in card
      final minOffset = (blockStart == 0 && blockSize > 1) ? 1 : 0;
      final offset = minOffset + _random.nextInt(blockSize - minOffset);
      sequence[blockStart + offset] = target;
    }

    // Fill remaining slots with distractors
    TargetConfig? lastDistractor;
    for (int i = 0; i < totalCards; i++) {
      if (sequence[i] == null) {
        // Pick a distractor, preferably not identical to the immediately preceding card
        final pool = distractors.where((d) => d.id != lastDistractor?.id).toList();
        final chosen = pool.isNotEmpty
            ? pool[_random.nextInt(pool.length)]
            : distractors[_random.nextInt(distractors.length)];
        sequence[i] = chosen;
        lastDistractor = chosen;
      } else {
        lastDistractor = null;
      }
    }

    return sequence.cast<TargetConfig>();
  }
}
