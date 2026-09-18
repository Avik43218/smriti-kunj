import 'dart:math';

// ─────────────────────────────────────────────────────────────────────────────
// Round-level and session-level telemetry models
// Measures: Latency, Accuracy, Hesitation, Error Burst
// ─────────────────────────────────────────────────────────────────────────────

/// Telemetry measurements for an individual round / trial within a game.
class RoundTelemetry {
  /// 1-based index of this round or trial within the session.
  final int roundIndex;

  /// UTC timestamp when this round event was completed.
  final DateTime timestamp;

  /// Type of event: `"tap"`, `"match_attempt"`, `"item_selection"`, `"omission"`, etc.
  final String eventType;

  /// Response latency in milliseconds (time from stimulus presentation to action).
  final double latencyMs;

  /// Accuracy score for this round: 1.0 (correct/hit/match) or 0.0 (error/miss/mismatch).
  final double accuracy;

  /// Measured hesitation duration in milliseconds (idle pause exceeding baseline threshold).
  final double hesitationMs;

  /// True if a hesitation episode was detected before/during this action.
  final bool isHesitation;

  /// True if the outcome of this round was an error.
  final bool isError;

  /// Current running count of consecutive errors without a success.
  final int consecutiveErrors;

  /// True if this error is part of an error burst (>= 2 consecutive errors).
  final bool isErrorBurst;

  /// Optional contextual details for this specific round (e.g. item ID, pair ID).
  final Map<String, dynamic> metadata;

  const RoundTelemetry({
    required this.roundIndex,
    required this.timestamp,
    required this.eventType,
    required this.latencyMs,
    required this.accuracy,
    required this.hesitationMs,
    required this.isHesitation,
    required this.isError,
    required this.consecutiveErrors,
    required this.isErrorBurst,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'round_index': roundIndex,
        'timestamp': timestamp.toIso8601String(),
        'event_type': eventType,
        'latency_ms': double.parse(latencyMs.toStringAsFixed(2)),
        'accuracy': double.parse(accuracy.toStringAsFixed(2)),
        'hesitation': {
          'hesitation_ms': double.parse(hesitationMs.toStringAsFixed(2)),
          'is_hesitation': isHesitation,
        },
        'error_burst': {
          'is_error': isError,
          'consecutive_errors': consecutiveErrors,
          'is_error_burst': isErrorBurst,
        },
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  factory RoundTelemetry.fromJson(Map<String, dynamic> json) {
    final hesitation = json['hesitation'] as Map<String, dynamic>? ?? {};
    final errorBurst = json['error_burst'] as Map<String, dynamic>? ?? {};
    return RoundTelemetry(
      roundIndex: (json['round_index'] as num?)?.toInt() ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      eventType: json['event_type'] as String? ?? 'action',
      latencyMs: (json['latency_ms'] as num?)?.toDouble() ?? 0.0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      hesitationMs: (hesitation['hesitation_ms'] as num?)?.toDouble() ?? 0.0,
      isHesitation: hesitation['is_hesitation'] as bool? ?? false,
      isError: errorBurst['is_error'] as bool? ?? false,
      consecutiveErrors:
          (errorBurst['consecutive_errors'] as num?)?.toInt() ?? 0,
      isErrorBurst: errorBurst['is_error_burst'] as bool? ?? false,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }
}

/// Aggregate session-level summary of Latency, Accuracy, Hesitation, and Error Burst.
class SessionTelemetrySummary {
  // ── 1. Latency Metrics ────────────────────────────────────────────────────
  final double avgLatencyMs;
  final double medianLatencyMs;
  final double minLatencyMs;
  final double maxLatencyMs;
  final double latencyVariabilityMs; // Standard deviation (cognitive consistency)
  final double p90LatencyMs;

  // ── 2. Accuracy Metrics ───────────────────────────────────────────────────
  final double overallAccuracy; // 0.0 to 1.0
  final int totalRounds;
  final int correctCount;
  final int errorCount;

  // ── 3. Hesitation Metrics ─────────────────────────────────────────────────
  final int hesitationEventsCount;
  final double totalHesitationMs;
  final double avgHesitationMs;
  final double hesitationRatio; // Hesitation time / total active latency time
  final double initialHesitationMs; // Latency to first action in the session

  // ── 4. Error Burst Metrics ────────────────────────────────────────────────
  final int maxConsecutiveErrors;
  final int errorBurstCount; // Count of distinct burst episodes (>= 2 errors in sequence)
  final int burstErrorsCount; // Total number of errors that occurred inside bursts
  final double errorBurstRate; // burstErrorsCount / total errorCount (0.0–1.0)
  final bool errorBurstDetected;

  // ── Round Breakdown ───────────────────────────────────────────────────────
  final List<RoundTelemetry> rounds;

  const SessionTelemetrySummary({
    required this.avgLatencyMs,
    required this.medianLatencyMs,
    required this.minLatencyMs,
    required this.maxLatencyMs,
    required this.latencyVariabilityMs,
    required this.p90LatencyMs,
    required this.overallAccuracy,
    required this.totalRounds,
    required this.correctCount,
    required this.errorCount,
    required this.hesitationEventsCount,
    required this.totalHesitationMs,
    required this.avgHesitationMs,
    required this.hesitationRatio,
    required this.initialHesitationMs,
    required this.maxConsecutiveErrors,
    required this.errorBurstCount,
    required this.burstErrorsCount,
    required this.errorBurstRate,
    required this.errorBurstDetected,
    required this.rounds,
  });

  Map<String, dynamic> toJson() => {
        'latency': {
          'avg_ms': double.parse(avgLatencyMs.toStringAsFixed(2)),
          'median_ms': double.parse(medianLatencyMs.toStringAsFixed(2)),
          'min_ms': double.parse(minLatencyMs.toStringAsFixed(2)),
          'max_ms': double.parse(maxLatencyMs.toStringAsFixed(2)),
          'variability_ms':
              double.parse(latencyVariabilityMs.toStringAsFixed(2)),
          'p90_ms': double.parse(p90LatencyMs.toStringAsFixed(2)),
        },
        'accuracy': {
          'overall_rate': double.parse(overallAccuracy.toStringAsFixed(3)),
          'total_rounds': totalRounds,
          'correct_count': correctCount,
          'error_count': errorCount,
        },
        'hesitation': {
          'hesitation_events_count': hesitationEventsCount,
          'total_hesitation_ms':
              double.parse(totalHesitationMs.toStringAsFixed(2)),
          'avg_hesitation_ms':
              double.parse(avgHesitationMs.toStringAsFixed(2)),
          'hesitation_ratio':
              double.parse(hesitationRatio.toStringAsFixed(3)),
          'initial_hesitation_ms':
              double.parse(initialHesitationMs.toStringAsFixed(2)),
        },
        'error_burst': {
          'max_consecutive_errors': maxConsecutiveErrors,
          'error_burst_count': errorBurstCount,
          'burst_errors_count': burstErrorsCount,
          'error_burst_rate':
              double.parse(errorBurstRate.toStringAsFixed(3)),
          'burst_detected': errorBurstDetected,
        },
        'rounds': rounds.map((r) => r.toJson()).toList(),
      };

  factory SessionTelemetrySummary.fromJson(Map<String, dynamic> json) {
    final latency = json['latency'] as Map<String, dynamic>? ?? {};
    final accuracy = json['accuracy'] as Map<String, dynamic>? ?? {};
    final hesitation = json['hesitation'] as Map<String, dynamic>? ?? {};
    final errorBurst = json['error_burst'] as Map<String, dynamic>? ?? {};
    final rawRounds = json['rounds'] as List<dynamic>? ?? [];

    return SessionTelemetrySummary(
      avgLatencyMs: (latency['avg_ms'] as num?)?.toDouble() ?? 0.0,
      medianLatencyMs: (latency['median_ms'] as num?)?.toDouble() ?? 0.0,
      minLatencyMs: (latency['min_ms'] as num?)?.toDouble() ?? 0.0,
      maxLatencyMs: (latency['max_ms'] as num?)?.toDouble() ?? 0.0,
      latencyVariabilityMs:
          (latency['variability_ms'] as num?)?.toDouble() ?? 0.0,
      p90LatencyMs: (latency['p90_ms'] as num?)?.toDouble() ?? 0.0,
      overallAccuracy: (accuracy['overall_rate'] as num?)?.toDouble() ?? 0.0,
      totalRounds: (accuracy['total_rounds'] as num?)?.toInt() ?? 0,
      correctCount: (accuracy['correct_count'] as num?)?.toInt() ?? 0,
      errorCount: (accuracy['error_count'] as num?)?.toInt() ?? 0,
      hesitationEventsCount:
          (hesitation['hesitation_events_count'] as num?)?.toInt() ?? 0,
      totalHesitationMs:
          (hesitation['total_hesitation_ms'] as num?)?.toDouble() ?? 0.0,
      avgHesitationMs:
          (hesitation['avg_hesitation_ms'] as num?)?.toDouble() ?? 0.0,
      hesitationRatio:
          (hesitation['hesitation_ratio'] as num?)?.toDouble() ?? 0.0,
      initialHesitationMs:
          (hesitation['initial_hesitation_ms'] as num?)?.toDouble() ?? 0.0,
      maxConsecutiveErrors:
          (errorBurst['max_consecutive_errors'] as num?)?.toInt() ?? 0,
      errorBurstCount:
          (errorBurst['error_burst_count'] as num?)?.toInt() ?? 0,
      burstErrorsCount:
          (errorBurst['burst_errors_count'] as num?)?.toInt() ?? 0,
      errorBurstRate:
          (errorBurst['error_burst_rate'] as num?)?.toDouble() ?? 0.0,
      errorBurstDetected: errorBurst['burst_detected'] as bool? ?? false,
      rounds: rawRounds
          .map((r) => RoundTelemetry.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Real-time engine for measuring and calculating round & session telemetry.
class GameTelemetryTracker {
  /// Hesitation threshold (ms) — latencies exceeding this trigger hesitation events.
  final double hesitationThresholdMs;

  /// Consecutive errors threshold required to flag an Error Burst (default: 2).
  final int errorBurstThreshold;

  final List<RoundTelemetry> _rounds = [];
  int _consecutiveErrors = 0;
  int _maxConsecutiveErrors = 0;
  int _errorBurstCount = 0;
  int _burstErrorsCount = 0;
  bool _inBurstState = false;

  GameTelemetryTracker({
    this.hesitationThresholdMs = 2000.0,
    this.errorBurstThreshold = 2,
  });

  List<RoundTelemetry> get rounds => List.unmodifiable(_rounds);
  int get roundCount => _rounds.length;

  /// Records a round/trial action and updates telemetry states.
  RoundTelemetry recordRound({
    required double latencyMs,
    required bool isCorrect,
    String eventType = 'action',
    double? rawHesitationMs,
    Map<String, dynamic> metadata = const {},
  }) {
    final isError = !isCorrect;

    // 1. Hesitation calculation
    final double hesitationMs = rawHesitationMs ??
        (latencyMs > hesitationThresholdMs
            ? (latencyMs - hesitationThresholdMs)
            : 0.0);
    final bool isHesitation = hesitationMs > 0 || latencyMs > hesitationThresholdMs;

    // 2. Error burst tracking
    if (isError) {
      _consecutiveErrors++;
      if (_consecutiveErrors > _maxConsecutiveErrors) {
        _maxConsecutiveErrors = _consecutiveErrors;
      }
      if (_consecutiveErrors >= errorBurstThreshold) {
        if (!_inBurstState) {
          // Started a new burst
          _errorBurstCount++;
          _inBurstState = true;
          // Count all consecutive errors in this streak so far
          _burstErrorsCount += _consecutiveErrors;
        } else {
          // Continuing existing burst
          _burstErrorsCount++;
        }
      }
    } else {
      _consecutiveErrors = 0;
      _inBurstState = false;
    }

    final isErrorBurst = _consecutiveErrors >= errorBurstThreshold;

    final telemetry = RoundTelemetry(
      roundIndex: _rounds.length + 1,
      timestamp: DateTime.now(),
      eventType: eventType,
      latencyMs: latencyMs,
      accuracy: isCorrect ? 1.0 : 0.0,
      hesitationMs: hesitationMs,
      isHesitation: isHesitation,
      isError: isError,
      consecutiveErrors: _consecutiveErrors,
      isErrorBurst: isErrorBurst,
      metadata: metadata,
    );

    _rounds.add(telemetry);
    return telemetry;
  }

  /// Computes the complete SessionTelemetrySummary across all recorded rounds.
  SessionTelemetrySummary computeSummary() {
    if (_rounds.isEmpty) {
      return const SessionTelemetrySummary(
        avgLatencyMs: 0,
        medianLatencyMs: 0,
        minLatencyMs: 0,
        maxLatencyMs: 0,
        latencyVariabilityMs: 0,
        p90LatencyMs: 0,
        overallAccuracy: 0,
        totalRounds: 0,
        correctCount: 0,
        errorCount: 0,
        hesitationEventsCount: 0,
        totalHesitationMs: 0,
        avgHesitationMs: 0,
        hesitationRatio: 0,
        initialHesitationMs: 0,
        maxConsecutiveErrors: 0,
        errorBurstCount: 0,
        burstErrorsCount: 0,
        errorBurstRate: 0,
        errorBurstDetected: false,
        rounds: [],
      );
    }

    final latencies = _rounds.map((r) => r.latencyMs).toList()..sort();
    final totalLatency = latencies.fold(0.0, (acc, val) => acc + val);
    final avgLatency = totalLatency / latencies.length;
    final minLatency = latencies.first;
    final maxLatency = latencies.last;

    // Median & P90 Latency
    final medianLatency = latencies[latencies.length ~/ 2];
    final p90Index = (latencies.length * 0.9).floor().clamp(0, latencies.length - 1);
    final p90Latency = latencies[p90Index];

    // Standard deviation (Variability)
    final variance = latencies.fold(
            0.0, (acc, val) => acc + pow(val - avgLatency, 2)) /
        latencies.length;
    final latencyVariability = sqrt(variance);

    // Accuracy
    final correctCount = _rounds.where((r) => !r.isError).length;
    final errorCount = _rounds.length - correctCount;
    final overallAccuracy = correctCount / _rounds.length;

    // Hesitation
    final hesitationRounds = _rounds.where((r) => r.isHesitation).toList();
    final hesitationEventsCount = hesitationRounds.length;
    final totalHesitationMs =
        _rounds.fold(0.0, (acc, r) => acc + r.hesitationMs);
    final avgHesitationMs = hesitationEventsCount > 0
        ? totalHesitationMs / hesitationEventsCount
        : 0.0;
    final hesitationRatio =
        totalLatency > 0 ? (totalHesitationMs / totalLatency).clamp(0.0, 1.0) : 0.0;
    final initialHesitationMs = _rounds.first.latencyMs;

    // Error Burst
    final errorBurstRate =
        errorCount > 0 ? (_burstErrorsCount / errorCount).clamp(0.0, 1.0) : 0.0;
    final errorBurstDetected = _errorBurstCount > 0;

    return SessionTelemetrySummary(
      avgLatencyMs: avgLatency,
      medianLatencyMs: medianLatency,
      minLatencyMs: minLatency,
      maxLatencyMs: maxLatency,
      latencyVariabilityMs: latencyVariability,
      p90LatencyMs: p90Latency,
      overallAccuracy: overallAccuracy,
      totalRounds: _rounds.length,
      correctCount: correctCount,
      errorCount: errorCount,
      hesitationEventsCount: hesitationEventsCount,
      totalHesitationMs: totalHesitationMs,
      avgHesitationMs: avgHesitationMs,
      hesitationRatio: hesitationRatio,
      initialHesitationMs: initialHesitationMs,
      maxConsecutiveErrors: _maxConsecutiveErrors,
      errorBurstCount: _errorBurstCount,
      burstErrorsCount: _burstErrorsCount,
      errorBurstRate: errorBurstRate,
      errorBurstDetected: errorBurstDetected,
      rounds: List.from(_rounds),
    );
  }
}
