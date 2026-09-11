import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/games/tap_target/models/target_config.dart';
import 'package:patient_app/games/tap_target/services/target_bank_service.dart';
import 'package:patient_app/games/tap_target/models/game_session_result.dart';

void main() {
  group('Tap Target Single-Card Cycling & Sequence Generator Tests', () {
    late TargetBankService bankService;
    late TargetConfig target;
    late List<TargetConfig> bank;

    setUp(() {
      bankService = TargetBankService();
      target = const TargetConfig(
        id: 'japi',
        category: 'cultural',
        visualGroup: 'woven_hat',
        translations: {'en': 'Traditional Japi', 'as': 'জাপি'},
        iconName: 'style',
      );
      bank = [
        target,
        const TargetConfig(
          id: 'orange',
          category: 'fruit',
          visualGroup: 'round_fruit',
          translations: {'en': 'Orange', 'as': 'কমলা'},
          iconName: 'circle',
        ),
        const TargetConfig(
          id: 'bamboo_shoot',
          category: 'vegetable',
          visualGroup: 'green_stem',
          translations: {'en': 'Bamboo Shoot', 'as': 'বাঁহৰ গাজ'},
          iconName: 'eco',
        ),
        const TargetConfig(
          id: 'lotus',
          category: 'flower',
          visualGroup: 'flower',
          translations: {'en': 'Lotus Flower', 'as': 'পদুম ফুল'},
          iconName: 'local_florist',
        ),
      ];
    });

    test('generateCardSequence generates exact card count per difficulty', () {
      final easySeq = bankService.generateCardSequence(
        bank: bank,
        target: target,
        difficulty: TapDifficulty.easy,
      );
      expect(easySeq.length, equals(TapDifficulty.easy.trialCount));
      expect(easySeq.where((c) => c.id == target.id).length, greaterThanOrEqualTo(3));

      final mediumSeq = bankService.generateCardSequence(
        bank: bank,
        target: target,
        difficulty: TapDifficulty.medium,
      );
      expect(mediumSeq.length, equals(TapDifficulty.medium.trialCount));

      final hardSeq = bankService.generateCardSequence(
        bank: bank,
        target: target,
        difficulty: TapDifficulty.hard,
      );
      expect(hardSeq.length, equals(TapDifficulty.hard.trialCount));
    });

    test('raw_trials JSON schema logs null reaction times on omission and correct_rejection', () {
      final rawTrials = <Map<String, dynamic>>[
        {
          'trial_index': 0,
          'card_item_id': 'orange',
          'is_target_card': false,
          'was_tapped': false,
          'tapped_item_id': null,
          'reaction_time_ms': null,
          'event_type': 'correct_rejection',
          'timestamp': DateTime.now().toIso8601String(),
        },
        {
          'trial_index': 1,
          'card_item_id': 'japi',
          'is_target_card': true,
          'was_tapped': true,
          'tapped_item_id': 'japi',
          'reaction_time_ms': 532,
          'event_type': 'target_hit',
          'timestamp': DateTime.now().toIso8601String(),
        },
        {
          'trial_index': 2,
          'card_item_id': 'japi',
          'is_target_card': true,
          'was_tapped': false,
          'tapped_item_id': null,
          'reaction_time_ms': null,
          'event_type': 'omission',
          'timestamp': DateTime.now().toIso8601String(),
        },
      ];

      final sessionResult = TapTargetSessionResult(
        reactionTimeAvg: 532.0,
        reactionTimeVariability: 0.0,
        omissionRate: 0.5,
        falsePositiveRate: 0.0,
        withinSessionDrift: 0.0,
        trialCount: 3,
        targetItemType: 'japi',
        sessionId: 'test_session_1',
        patientProfileId: 'patient_test',
        sessionDate: DateTime.now(),
        sessionDuration: 12.5,
        status: 'completed',
        difficultyLevel: 1,
        scoreNormalized: 0.5,
        rawTrials: rawTrials,
      );

      final json = sessionResult.toJson();
      expect(json['trial_count'], equals(3));
      expect(json['raw_trials'][0]['event_type'], equals('correct_rejection'));
      expect(json['raw_trials'][0]['reaction_time_ms'], isNull);
      expect(json['raw_trials'][2]['event_type'], equals('omission'));
      expect(json['raw_trials'][2]['reaction_time_ms'], isNull);

      final restored = TapTargetSessionResult.fromJson(json);
      expect(restored.rawTrials.length, equals(3));
      expect(restored.rawTrials[0]['event_type'], equals('correct_rejection'));
      expect(restored.rawTrials[0]['reaction_time_ms'], isNull);
      expect(restored.rawTrials[2]['event_type'], equals('omission'));
      expect(restored.rawTrials[2]['reaction_time_ms'], isNull);
    });
  });
}
