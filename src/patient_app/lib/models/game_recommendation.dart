import 'package:flutter/foundation.dart';
import 'patient_diagnosis.dart';

/// Aggregated performance telemetry for an individual game or across all games.
@immutable
class GamePerformanceSnapshot {
  final String gameType;
  final double accuracy; // 0.0 - 1.0
  final double avgLatencyMs;
  final double hesitationRatio; // 0.0 - 1.0
  final double errorRate; // 0.0 - 1.0
  final int roundsPlayed;
  final DateTime? lastPlayed;

  const GamePerformanceSnapshot({
    required this.gameType,
    required this.accuracy,
    required this.avgLatencyMs,
    required this.hesitationRatio,
    required this.errorRate,
    required this.roundsPlayed,
    this.lastPlayed,
  });

  /// Factory for empty/unplayed game metrics
  factory GamePerformanceSnapshot.empty(String gameType) {
    return GamePerformanceSnapshot(
      gameType: gameType,
      accuracy: 0.0,
      avgLatencyMs: 0.0,
      hesitationRatio: 0.0,
      errorRate: 0.0,
      roundsPlayed: 0,
    );
  }
}

/// A personalized game recommendation evaluated from clinical diagnosis priority
/// and historical performance metrics.
@immutable
class GameRecommendation {
  final String gameType; // 'market_trip' | 'tap_target' | 'pair_matching'
  final String gameTitle;
  final String subtitle;
  final String domain;
  final DiagnosisPriority diagnosisPriority;
  final int priorityNumber;
  final String diagnosisName;
  final String clinicalRationale;
  final GamePerformanceSnapshot performanceSnapshot;
  final double compositeScore;

  const GameRecommendation({
    required this.gameType,
    required this.gameTitle,
    required this.subtitle,
    required this.domain,
    required this.diagnosisPriority,
    required this.priorityNumber,
    required this.diagnosisName,
    required this.clinicalRationale,
    required this.performanceSnapshot,
    required this.compositeScore,
  });
}
