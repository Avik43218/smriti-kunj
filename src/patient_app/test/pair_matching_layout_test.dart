import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/games/pair_matching/services/pair_bank_service.dart';
import 'package:patient_app/games/pair_matching/models/game_session_result.dart';

void main() {
  group('Pair Matching Responsive Grid & Difficulty Specifications', () {
    test('PairDifficulty tier properties match required grid geometry and pair counts', () {
      // Easy: 4 pairs (8 cards) -> 2 columns x 4 rows
      expect(PairDifficulty.easy.level, equals(1));
      expect(PairDifficulty.easy.pairCount, equals(4));
      expect(PairDifficulty.easy.gridColumns, equals(2));
      final easyCards = PairDifficulty.easy.pairCount * 2;
      final easyRows = (easyCards / PairDifficulty.easy.gridColumns).ceil();
      expect(easyCards, equals(8));
      expect(easyRows, equals(4));

      // Medium: 6 pairs (12 cards) -> 3 columns x 4 rows
      expect(PairDifficulty.medium.level, equals(2));
      expect(PairDifficulty.medium.pairCount, equals(6));
      expect(PairDifficulty.medium.gridColumns, equals(3));
      final medCards = PairDifficulty.medium.pairCount * 2;
      final medRows = (medCards / PairDifficulty.medium.gridColumns).ceil();
      expect(medCards, equals(12));
      expect(medRows, equals(4));

      // Hard: 8 pairs (16 cards) -> 4 columns x 4 rows
      expect(PairDifficulty.hard.level, equals(3));
      expect(PairDifficulty.hard.pairCount, equals(8));
      expect(PairDifficulty.hard.gridColumns, equals(4));
      final hardCards = PairDifficulty.hard.pairCount * 2;
      final hardRows = (hardCards / PairDifficulty.hard.gridColumns).ceil();
      expect(hardCards, equals(16));
      expect(hardRows, equals(4));
    });

    test('Zero-scroll dynamic card geometry calculation on compact screens (360x640dp)', () {
      const screenWidth = 360.0;
      const availableGridHeight = 440.0; // Viewport height minus app bar, header, padding

      // Hard tier calculation: 4 columns x 4 rows, 8dp pad, 6dp spacing
      const hardPad = 8.0;
      const hardSpacing = 6.0;
      const hardColumns = 4;
      const hardRows = 4;

      const hardAvailW = screenWidth - (hardPad * 2);
      const hardCardW = (hardAvailW - (hardColumns - 1) * hardSpacing) / hardColumns;
      const hardCardH = (availableGridHeight - (hardRows - 1) * hardSpacing) / hardRows;

      expect(hardCardW, inInclusiveRange(75.0, 85.0));
      expect(hardCardH, inInclusiveRange(95.0, 115.0));
      expect(hardCardW * hardCardH, greaterThan(8000)); // ~8,400 dp^2 touch area

      const hardAspect = hardCardW / hardCardH;
      expect(hardAspect, greaterThan(0.6));
      expect(hardAspect, lessThan(0.9));
    });

    test('PairMatchingSessionResult JSON contract stability', () {
      final now = DateTime.now();
      final result = PairMatchingSessionResult(
        difficultyLevel: 3,
        totalFlips: 18,
        correctMatchRate: 0.88,
        timeToFirstCorrectMatch: 4.2,
        repeatErrorRate: 0.12,
        completionTime: 45.0,
        pairsCount: 8,
        usedFaceNameVariant: false,
        sessionId: 'test_session_pm_1',
        patientProfileId: 'patient_001',
        sessionDate: now,
        sessionDuration: 45.0,
        status: 'completed',
        scoreNormalized: 0.88,
        rawTrials: [],
      );

      final json = result.toJson();
      expect(json['difficulty_level'], equals(3));
      expect(json['total_flips'], equals(18));
      expect(json['correct_match_rate'], equals(0.88));
      expect(json['time_to_first_correct_match'], equals(4.2));
      expect(json['repeat_error_rate'], equals(0.12));
      expect(json['completion_time'], equals(45.0));
      expect(json['pairs_count'], equals(8));
      expect(json['used_face_name_variant'], isFalse);

      final restored = PairMatchingSessionResult.fromJson(json);
      expect(restored.difficultyLevel, equals(3));
      expect(restored.pairsCount, equals(8));
      expect(restored.totalFlips, equals(18));
    });
  });
}
