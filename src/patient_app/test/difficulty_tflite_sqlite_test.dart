import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/services/difficulty_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DynamicDifficultyService & Telemetry Processing Tests', () {
    late DynamicDifficultyService difficultyService;

    setUp(() {
      difficultyService = DynamicDifficultyService.instance;
    });

    test('Feature extraction from MarketTrip telemetry JSON', () {
      final marketTripJson = {
        'game_type': 'market_trip',
        'items_prompted_count': 5,
        'items_recalled_correct': 5,
        'recall_accuracy': 1.0,
        'false_selection_count': 0,
        'time_to_complete_recall': 3.2,
        'score_normalized': 1.0,
        'telemetry': {
          'latency': {'avg_ms': 450.0, 'median_ms': 420.0},
          'accuracy': {'overall_rate': 1.0, 'total_rounds': 5},
          'hesitation': {'hesitation_ratio': 0.05, 'is_hesitation': false},
          'error_burst': {'error_burst_rate': 0.0, 'burst_detected': false},
        },
      };

      final features = difficultyService.extractFeatures(marketTripJson);
      expect(features.length, 4);
      // Latency normalized (450 / 2500 = 0.18)
      expect(features[0], closeTo(0.18, 0.01));
      // Accuracy = 1.0
      expect(features[1], 1.0);
      // Hesitation = 0.05
      expect(features[2], 0.05);
      // Error burst = 0.0
      expect(features[3], 0.0);
    });

    test('Feature extraction from TapTarget telemetry JSON', () {
      final tapTargetJson = {
        'game_type': 'tap_target',
        'reaction_time_avg': 1100.0,
        'reaction_time_variability': 250.0,
        'omission_rate': 0.40,
        'false_positive_rate': 0.35,
        'within_session_drift': -0.3,
        'trial_count': 10,
        'score_normalized': 0.42,
        'telemetry': {
          'latency': {'avg_ms': 1100.0},
          'accuracy': {'overall_rate': 0.60},
          'hesitation': {'hesitation_ratio': 0.45},
          'error_burst': {'error_burst_rate': 0.50},
        },
      };

      final features = difficultyService.extractFeatures(tapTargetJson);
      expect(features.length, 4);
      // Latency normalized (1100 / 2500 = 0.44)
      expect(features[0], closeTo(0.44, 0.01));
      // Accuracy = 0.60
      expect(features[1], closeTo(0.60, 0.01));
      // Hesitation = 0.45
      expect(features[2], closeTo(0.45, 0.01));
      // Error burst = 0.50
      expect(features[3], closeTo(0.50, 0.01));
    });

    test('Feature extraction from PairMatching telemetry JSON', () {
      final pairMatchingJson = {
        'game_type': 'pair_matching',
        'total_flips': 28,
        'correct_match_rate': 0.40,
        'time_to_first_correct_match': 14.5,
        'repeat_error_rate': 0.65,
        'completion_time': 58.0,
        'pairs_count': 4,
        'score_normalized': 0.35,
        'telemetry': {
          'latency': {'avg_ms': 1650.0},
          'accuracy': {'overall_rate': 0.40},
          'hesitation': {'hesitation_ratio': 0.70},
          'error_burst': {'error_burst_rate': 0.65},
        },
      };

      final features = difficultyService.extractFeatures(pairMatchingJson);
      expect(features.length, 4);
      // Latency normalized (1650 / 2500 = 0.66)
      expect(features[0], closeTo(0.66, 0.01));
      // Accuracy = 0.40
      expect(features[1], closeTo(0.40, 0.01));
      // Hesitation = 0.70
      expect(features[2], closeTo(0.70, 0.01));
      // Error burst = 0.65
      expect(features[3], closeTo(0.65, 0.01));
    });

    test('Struggling patient profile triggers Ease Up (-1) action', () async {
      final strugglingTelemetry = {
        'reaction_time_ms': 1800.0, // High latency (0.72)
        'accuracy': 0.30,           // Low accuracy
        'hesitation': 0.85,          // Heavy hesitation
        'error_burst': 0.75,         // Multiple consecutive errors
      };

      final decision = await difficultyService.evaluateSessionJson(
        jsonEncode(strugglingTelemetry),
        currentDifficulty: 2, // Medium
        gameType: 'tap_target',
      );

      expect(decision.action, 'Ease Up (-1)');
      expect(decision.difficultyDelta, -1);
      expect(decision.previousDifficulty, 2);
      expect(decision.recommendedDifficulty, 1); // Stepped down to Easy
      expect(decision.confidence, greaterThan(0.50));
    });

    test('Cruising patient profile triggers Level Up (+1) action', () async {
      final cruisingTelemetry = {
        'reaction_time_ms': 380.0, // Fast latency (0.15)
        'accuracy': 0.95,          // High accuracy
        'hesitation': 0.10,         // Low hesitation
        'error_burst': 0.0,         // No error burst
      };

      final decision = await difficultyService.evaluateSessionJson(
        jsonEncode(cruisingTelemetry),
        currentDifficulty: 1, // Easy
        gameType: 'market_trip',
      );

      expect(decision.action, 'Level Up (+1)');
      expect(decision.difficultyDelta, 1);
      expect(decision.previousDifficulty, 1);
      expect(decision.recommendedDifficulty, 2); // Stepped up to Medium
      expect(decision.confidence, greaterThan(0.50));
    });

    test('Steady flow profile triggers Maintain (0) action', () async {
      final steadyTelemetry = {
        'reaction_time_ms': 680.0, // Normal latency (~0.27)
        'accuracy': 0.75,          // Balanced accuracy
        'hesitation': 0.35,         // Moderate hesitation
        'error_burst': 0.10,        // Minimal error burst
      };

      final decision = await difficultyService.evaluateSessionJson(
        jsonEncode(steadyTelemetry),
        currentDifficulty: 2, // Medium
        gameType: 'pair_matching',
      );

      expect(decision.action, 'Maintain (0)');
      expect(decision.difficultyDelta, 0);
      expect(decision.previousDifficulty, 2);
      expect(decision.recommendedDifficulty, 2); // Maintained at Medium
    });

    test('Difficulty level clamping bounds (min 1, max 3)', () async {
      // Ease up from Level 1 -> should stay 1
      final struggling = jsonEncode({'accuracy': 0.2, 'reaction_time_ms': 2000.0, 'hesitation': 0.9, 'error_burst': 0.9});
      final stepDownFromEasy = await difficultyService.evaluateSessionJson(
        struggling,
        currentDifficulty: 1,
      );
      expect(stepDownFromEasy.recommendedDifficulty, 1);

      // Level up from Level 3 -> should stay 3
      final cruising = jsonEncode({'accuracy': 0.95, 'reaction_time_ms': 400.0, 'hesitation': 0.1, 'error_burst': 0.0});
      final stepUpFromHard = await difficultyService.evaluateSessionJson(
        cruising,
        currentDifficulty: 3,
      );
      expect(stepUpFromHard.recommendedDifficulty, 3);
    });

    test('DifficultyDecision JSON serialization roundtrip', () {
      final decision = DifficultyDecision(
        action: 'Level Up (+1)',
        difficultyDelta: 1,
        previousDifficulty: 1,
        recommendedDifficulty: 2,
        confidence: 0.885,
        distribution: {'Ease Up (-1)': 0.05, 'Maintain (0)': 0.15, 'Level Up (+1)': 0.80},
        gameType: 'market_trip',
        featureVector: [0.18, 0.95, 0.12, 0.0],
      );

      final jsonMap = decision.toJson();
      expect(jsonMap['action'], 'Level Up (+1)');
      expect(jsonMap['difficulty_delta'], 1);
      expect(jsonMap['recommended_difficulty'], 2);

      final restored = DifficultyDecision.fromJson(jsonMap);
      expect(restored.action, decision.action);
      expect(restored.difficultyDelta, decision.difficultyDelta);
      expect(restored.previousDifficulty, decision.previousDifficulty);
      expect(restored.recommendedDifficulty, decision.recommendedDifficulty);
      expect(restored.confidence, decision.confidence);
      expect(restored.gameType, decision.gameType);
      expect(restored.featureVector.length, 4);
    });

    test('Supported games list covers all live mini-games', () {
      expect(DifficultyDatabaseService.supportedGames, contains('market_trip'));
      expect(DifficultyDatabaseService.supportedGames, contains('tap_target'));
      expect(DifficultyDatabaseService.supportedGames, contains('pair_matching'));
      expect(DifficultyDatabaseService.supportedGames.length, 3);
    });
  });
}
