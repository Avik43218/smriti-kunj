import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/games/market_trip/models/game_session_result.dart';

void main() {
  group('Market Trip Distractor & Session Result Tests', () {
    test('GameSessionResult preserves distractor_task_completed and delay_duration without extra distractor fields', () {
      final now = DateTime.now();
      final result = GameSessionResult(
        itemsPromptedCount: 3,
        itemsRecalledCorrect: 3,
        recallAccuracy: 1.0,
        falseSelectionCount: 0,
        timeToCompleteRecall: 8.4,
        distractorTaskCompleted: true,
        delayDuration: 10.0,
        promptLanguage: 'assamese',
        sessionId: 'test_sess_mt_1',
        patientProfileId: 'p101',
        sessionDate: now,
        sessionDuration: 25.0,
        status: 'completed',
        scoreNormalized: 1.0,
        rawTrials: [
          {
            'timestamp': now.toIso8601String(),
            'item_id': 'bamboo_shoot',
            'action': 'select',
            'is_correct_target': true,
          }
        ],
      );

      final json = result.toJson();
      expect(json['distractor_task_completed'], isTrue);
      expect(json['delay_duration'], equals(10.0));
      expect(json.containsKey('tap_count'), isFalse);
      expect(json['raw_trials'].any((t) => t['event'] == 'distractor_summary'), isFalse);

      final restored = GameSessionResult.fromJson(json);
      expect(restored.distractorTaskCompleted, isTrue);
      expect(restored.delayDuration, equals(10.0));
      expect(restored.rawTrials.length, equals(1));
    });
  });
}
