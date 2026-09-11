import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:patient_app/services/difficulty_service.dart';
import 'package:patient_app/services/difficulty_database_service.dart';

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

    test('Pair Matching with high correct_match_rate and zero repeat errors levels up', () async {
      // Player flipped 10 times to match 4 pairs: correct_match_rate is high (80%),
      // repeat_error_rate is 0.0, even though exploratory flip trial rate is only 35%.
      final cruisingPairMatchingJson = {
        'game_type': 'pair_matching',
        'total_flips': 10,
        'correct_match_rate': 0.85,
        'time_to_first_correct_match': 3.5,
        'repeat_error_rate': 0.0,
        'score_normalized': 0.88,
        'telemetry': {
          'latency': {'avg_ms': 550.0},
          'accuracy': {'overall_rate': 0.35}, // Exploratory flips rate
          'hesitation': {'hesitation_ratio': 0.12},
          'error_burst': {'error_burst_rate': 0.50}, // Exploratory mismatches
        },
      };

      final features = difficultyService.extractFeatures(cruisingPairMatchingJson);
      expect(features[1], 0.85); // Evaluates correct_match_rate, NOT exploratory trial rate
      expect(features[3], 0.0);  // Evaluates repeat_error_rate (0 repeat errors)

      final decision = await difficultyService.evaluateSessionJson(
        jsonEncode(cruisingPairMatchingJson),
        currentDifficulty: 1, // Easy
        gameType: 'pair_matching',
      );

      expect(decision.action, 'Level Up (+1)');
      expect(decision.recommendedDifficulty, 2);
    });

    test('Pair Matching with high repeat errors triggers Ease Up (-1)', () async {
      final strugglingPairMatchingJson = {
        'game_type': 'pair_matching',
        'total_flips': 32,
        'correct_match_rate': 0.30,
        'time_to_first_correct_match': 18.0,
        'repeat_error_rate': 0.75, // Severe encoding failure
        'score_normalized': 0.28,
        'telemetry': {
          'latency': {'avg_ms': 1800.0},
          'accuracy': {'overall_rate': 0.25},
          'hesitation': {'hesitation_ratio': 0.75},
          'error_burst': {'error_burst_rate': 0.75},
        },
      };

      final decision = await difficultyService.evaluateSessionJson(
        jsonEncode(strugglingPairMatchingJson),
        currentDifficulty: 2, // Medium
        gameType: 'pair_matching',
      );

      expect(decision.action, 'Ease Up (-1)');
      expect(decision.recommendedDifficulty, 1);
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

  group('Difficulty SQLite Integration & Next-Game Lifecycle Tests', () {
    late Database inMemoryDb;
    late DynamicDifficultyService difficultyService;
    late DifficultyDatabaseService dbService;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      difficultyService = DynamicDifficultyService.instance;
      dbService = DifficultyDatabaseService.instance;

      inMemoryDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await inMemoryDb.execute('''
        CREATE TABLE pending_difficulty_settings (
          id                     INTEGER PRIMARY KEY AUTOINCREMENT,
          game_type              TEXT    NOT NULL,
          action                 TEXT    NOT NULL,
          difficulty_delta       INTEGER NOT NULL,
          previous_difficulty    INTEGER NOT NULL,
          recommended_difficulty INTEGER NOT NULL,
          confidence             REAL    NOT NULL,
          raw_json               TEXT    NOT NULL,
          created_at             TEXT    NOT NULL
        )
      ''');
      await inMemoryDb.execute('''
        CREATE TABLE game_current_levels (
          game_type TEXT PRIMARY KEY,
          level     INTEGER NOT NULL
        )
      ''');

      dbService.setDatabaseForTesting(inMemoryDb);
    });

    tearDown(() async {
      await inMemoryDb.close();
    });

    test('Round completion: TFLite evaluates raw JSON, stores output in SQLite, applies to next game and removes entry', () async {
      // 1. Simulate a completed round of Market Trip with a cruising patient
      final rawTelemetryJson = jsonEncode({
        'game_type': 'market_trip',
        'items_prompted_count': 5,
        'items_recalled_correct': 5,
        'recall_accuracy': 1.0,
        'false_selection_count': 0,
        'time_to_complete_recall': 3.0,
        'distractor_task_completed': true,
        'score_normalized': 1.0,
        'telemetry': {
          'latency': {'avg_ms': 420.0},
          'accuracy': {'overall_rate': 1.0},
          'hesitation': {'hesitation_ratio': 0.08},
          'error_burst': {'error_burst_rate': 0.0},
        },
      });

      // 2. Model spins up and returns its output
      final decision = await difficultyService.evaluateSessionJson(
        rawTelemetryJson,
        currentDifficulty: 1, // Easy
        gameType: 'market_trip',
      );

      expect(decision.action, 'Level Up (+1)');
      expect(decision.recommendedDifficulty, 2);

      // 3. Output is stored in the local SQLite database
      await dbService.saveDifficultySettingsForAllGames(
        decision,
        rawJson: rawTelemetryJson,
      );

      // Verify that the setting is present in SQLite
      final pendingCountBefore = await dbService.getPendingCount();
      expect(pendingCountBefore, 3); // 1 recommendation per supported game

      // Peek shows recommended level 2 without consuming
      final peekDecision = await dbService.peekLatestDifficultySetting(gameType: 'tap_target');
      expect(peekDecision, isNotNull);
      expect(peekDecision!.recommendedDifficulty, 2);
      expect(await dbService.getPendingCount(), 3);

      // 4. When next game is selected (e.g. Tap Target), setting is applied according to SQLite
      final nextGameDecision = await dbService.consumeAndClearForSelectedGame('tap_target');
      expect(nextGameDecision, isNotNull);
      expect(nextGameDecision!.action, 'Level Up (+1)');
      expect(nextGameDecision.recommendedDifficulty, 2);

      // 5. The entry from the database is REMOVED
      final pendingCountAfter = await dbService.getPendingCount();
      expect(pendingCountAfter, 0);

      // Subsequent retrieval returns null since entry was cleared
      final emptyCheck = await dbService.consumeLatestDifficultySetting(gameType: 'tap_target');
      expect(emptyCheck, isNull);

      // Verify baseline level in SQLite was updated to 2
      final currentLevel = await dbService.getCurrentLevel('tap_target');
      expect(currentLevel, 2);
    });

    test('Struggling round eases difficulty for next game, then clears SQLite', () async {
      // Set current baseline level to 2 (Medium)
      await dbService.setCurrentLevel('market_trip', 2);
      await dbService.setCurrentLevel('tap_target', 2);
      await dbService.setCurrentLevel('pair_matching', 2);

      // Player struggles on Tap Target
      final strugglingJson = jsonEncode({
        'game_type': 'tap_target',
        'reaction_time_avg': 1750.0,
        'reaction_time_variability': 350.0,
        'omission_rate': 0.50,
        'false_positive_rate': 0.40,
        'within_session_drift': -0.4,
        'trial_count': 12,
        'score_normalized': 0.30,
        'telemetry': {
          'latency': {'avg_ms': 1750.0},
          'accuracy': {'overall_rate': 0.35},
          'hesitation': {'hesitation_ratio': 0.80},
          'error_burst': {'error_burst_rate': 0.70},
        },
      });

      final decision = await difficultyService.evaluateSessionJson(
        strugglingJson,
        currentDifficulty: 2,
        gameType: 'tap_target',
      );

      expect(decision.action, 'Ease Up (-1)');
      expect(decision.recommendedDifficulty, 1);

      // Save to SQLite
      await dbService.saveDifficultySettingsForAllGames(decision, rawJson: strugglingJson);
      expect(await dbService.getPendingCount(), 3);

      // Player next launches Pair Matching
      final appliedDecision = await dbService.consumeAndClearForSelectedGame('pair_matching');
      expect(appliedDecision, isNotNull);
      expect(appliedDecision!.action, 'Ease Up (-1)');
      expect(appliedDecision.recommendedDifficulty, 1);

      // Database entry is removed
      expect(await dbService.getPendingCount(), 0);
    });

    test('Play Again in same game applies setting and removes SQLite entry', () async {
      // Set baseline level to 1
      await dbService.setCurrentLevel('pair_matching', 1);

      // Cruising pair matching session
      final cruisingPairMatching = jsonEncode({
        'game_type': 'pair_matching',
        'total_flips': 10,
        'correct_match_rate': 0.90,
        'time_to_first_correct_match': 3.0,
        'repeat_error_rate': 0.0,
        'completion_time': 24.0,
        'pairs_count': 4,
        'score_normalized': 0.92,
        'telemetry': {
          'latency': {'avg_ms': 500.0},
          'accuracy': {'overall_rate': 0.90},
          'hesitation': {'hesitation_ratio': 0.10},
          'error_burst': {'error_burst_rate': 0.0},
        },
      });

      final decision = await difficultyService.evaluateSessionJson(
        cruisingPairMatching,
        currentDifficulty: 1,
        gameType: 'pair_matching',
      );

      await dbService.saveDifficultySettingsForAllGames(decision, rawJson: cruisingPairMatching);
      expect(await dbService.getPendingCount(), 3);

      // Patient clicks "Play Again" in Pair Matching
      final replayDecision = await dbService.consumeLatestDifficultySetting(gameType: 'pair_matching');
      expect(replayDecision, isNotNull);
      expect(replayDecision!.recommendedDifficulty, 2);

      // SQLite entries are consumed and removed
      expect(await dbService.getPendingCount(), 0);
    });

    test('Single game difficulty setting save, consume, and remove', () async {
      final singleDecision = DifficultyDecision(
        action: 'Maintain (0)',
        difficultyDelta: 0,
        previousDifficulty: 2,
        recommendedDifficulty: 2,
        confidence: 0.95,
        distribution: {'Ease Up (-1)': 0.02, 'Maintain (0)': 0.95, 'Level Up (+1)': 0.03},
        gameType: 'market_trip',
        featureVector: [0.25, 0.75, 0.30, 0.10],
      );

      final rowId = await dbService.saveDifficultySetting(singleDecision);
      expect(rowId, greaterThan(0));
      expect(await dbService.getPendingCount(), 1);

      final consumed = await dbService.consumeAndClearForSelectedGame('market_trip');
      expect(consumed, isNotNull);
      expect(consumed!.recommendedDifficulty, 2);
      expect(await dbService.getPendingCount(), 0);
    });
  });
}
