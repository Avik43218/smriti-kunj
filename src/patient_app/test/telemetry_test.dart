import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/games/shared/models/round_telemetry.dart';

void main() {
  group('GameTelemetryTracker & Telemetry Models Tests', () {
    test('Calculates Latency, Accuracy, Hesitation, and Error Burst accurately', () {
      final tracker = GameTelemetryTracker(
        hesitationThresholdMs: 2000.0,
        errorBurstThreshold: 2,
      );

      // Round 1: Success, fast (400ms)
      final r1 = tracker.recordRound(
        latencyMs: 400.0,
        isCorrect: true,
        eventType: 'tap',
      );
      expect(r1.accuracy, 1.0);
      expect(r1.isError, false);
      expect(r1.isHesitation, false);
      expect(r1.isErrorBurst, false);
      expect(r1.consecutiveErrors, 0);

      // Round 2: Success, with hesitation (3500ms > 2000ms threshold)
      final r2 = tracker.recordRound(
        latencyMs: 3500.0,
        isCorrect: true,
        eventType: 'tap',
      );
      expect(r2.accuracy, 1.0);
      expect(r2.isHesitation, true);
      expect(r2.hesitationMs, 1500.0);
      expect(r2.isError, false);

      // Round 3: Error 1 (600ms) -> consecutive errors = 1 (not yet a burst)
      final r3 = tracker.recordRound(
        latencyMs: 600.0,
        isCorrect: false,
        eventType: 'distractor_tap',
      );
      expect(r3.accuracy, 0.0);
      expect(r3.isError, true);
      expect(r3.consecutiveErrors, 1);
      expect(r3.isErrorBurst, false);

      // Round 4: Error 2 (700ms) -> consecutive errors = 2 (triggers Error Burst)
      final r4 = tracker.recordRound(
        latencyMs: 700.0,
        isCorrect: false,
        eventType: 'distractor_tap',
      );
      expect(r4.accuracy, 0.0);
      expect(r4.isError, true);
      expect(r4.consecutiveErrors, 2);
      expect(r4.isErrorBurst, true);

      // Round 5: Error 3 (800ms) -> continuing Error Burst
      final r5 = tracker.recordRound(
        latencyMs: 800.0,
        isCorrect: false,
        eventType: 'omission',
      );
      expect(r5.consecutiveErrors, 3);
      expect(r5.isErrorBurst, true);

      // Round 6: Success (500ms) -> resets error streak
      final r6 = tracker.recordRound(
        latencyMs: 500.0,
        isCorrect: true,
        eventType: 'tap',
      );
      expect(r6.consecutiveErrors, 0);
      expect(r6.isErrorBurst, false);

      // Compute summary
      final summary = tracker.computeSummary();

      expect(summary.totalRounds, 6);
      expect(summary.correctCount, 3);
      expect(summary.errorCount, 3);
      expect(summary.overallAccuracy, 0.5);

      // Hesitation summary
      expect(summary.hesitationEventsCount, 1);
      expect(summary.totalHesitationMs, 1500.0);

      // Error burst summary
      expect(summary.maxConsecutiveErrors, 3);
      expect(summary.errorBurstCount, 1);
      expect(summary.burstErrorsCount, 3);
      expect(summary.errorBurstRate, 1.0);
      expect(summary.errorBurstDetected, true);

      // JSON serialization & deserialization check
      final jsonMap = summary.toJson();
      expect(jsonMap.containsKey('latency'), true);
      expect(jsonMap.containsKey('accuracy'), true);
      expect(jsonMap.containsKey('hesitation'), true);
      expect(jsonMap.containsKey('error_burst'), true);
      expect(jsonMap.containsKey('rounds'), true);

      final restored = SessionTelemetrySummary.fromJson(jsonMap);
      expect(restored.totalRounds, 6);
      expect(restored.overallAccuracy, 0.5);
      expect(restored.maxConsecutiveErrors, 3);
      expect(restored.errorBurstDetected, true);
      expect(restored.rounds.length, 6);
    });
  });
}
