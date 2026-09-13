import 'package:flutter/foundation.dart';
import '../models/game_recommendation.dart';
import '../models/patient_diagnosis.dart';
import 'activity_database_service.dart';

/// Clinical recommendation engine that determines the next recommended game for the patient.
///
/// Features:
/// - Evaluates patient clinical diagnosis and priority number (1-7).
/// - Analyzes historical performance stored in SQLite (latency, accuracy, hesitation, errors).
/// - Generates human-readable clinical rationale.
/// - Does NOT alter any difficulty settings (difficulty is maintained by DifficultyDatabaseService).
class GamePersonalizationService {
  static final GamePersonalizationService instance = GamePersonalizationService._internal();

  GamePersonalizationService._internal();
  factory GamePersonalizationService() => instance;

  static const List<String> supportedGameTypes = [
    'market_trip',
    'tap_target',
    'pair_matching',
  ];

  /// Computes the top recommended game given the patient's diagnosis and performance history.
  Future<GameRecommendation> getNextRecommendedGame({
    PatientDiagnosisInfo? diagnosisInfo,
    String? pairingCode,
  }) async {
    // 1. Resolve diagnosis info: either provided, from SQLite, or default
    PatientDiagnosisInfo effectiveDiagnosis = diagnosisInfo ??
        await ActivityDatabaseService.instance.getPatientDiagnosis(pairingCode: pairingCode) ??
        PatientDiagnosisInfo(
          pairingCode: pairingCode ?? '',
          patientId: '',
          patientName: '',
          rawDiagnosis: 'Other / Under Observation',
          priority: DiagnosisPriority.otherUnderObservation,
          fetchedAt: DateTime.now(),
        );

    // 2. Fetch performance snapshots from local SQLite database across latency, accuracy, hesitation, errors
    final snapshots = await ActivityDatabaseService.instance.getAllGamesPerformanceSnapshots();

    // 3. Score each game
    GameRecommendation? bestRecommendation;
    double highestScore = -1.0;

    for (final gameType in supportedGameTypes) {
      final snapshot = snapshots[gameType] ?? GamePerformanceSnapshot.empty(gameType);
      final score = _computeCompositeScore(gameType, effectiveDiagnosis.priority, snapshot);

      if (score > highestScore || bestRecommendation == null) {
        highestScore = score;
        final details = _getGameDetails(gameType);
        final rationale = _generateClinicalRationale(
          gameType: gameType,
          diagnosis: effectiveDiagnosis,
          snapshot: snapshot,
          domain: details['domain']!,
        );

        bestRecommendation = GameRecommendation(
          gameType: gameType,
          gameTitle: details['title']!,
          subtitle: details['subtitle']!,
          domain: details['domain']!,
          diagnosisPriority: effectiveDiagnosis.priority,
          priorityNumber: effectiveDiagnosis.priorityNumber,
          diagnosisName: effectiveDiagnosis.displayName,
          clinicalRationale: rationale,
          performanceSnapshot: snapshot,
          compositeScore: score,
        );
      }
    }

    return bestRecommendation!;
  }

  /// Calculates composite score based on diagnosis priority affinity and performance needs.
  double _computeCompositeScore(
    String gameType,
    DiagnosisPriority diagnosisPriority,
    GamePerformanceSnapshot snapshot,
  ) {
    // 1. Diagnosis Clinical Affinity (0.0 - 1.0)
    final recommendedOrder = diagnosisPriority.recommendedGames;
    double clinicalAffinity = 0.45;
    final index = recommendedOrder.indexOf(gameType);
    if (index != -1) {
      clinicalAffinity = 1.0 - (index * 0.15);
    }
    // Weight by clinical priority (Priority 1 = 1.35x multiplier, Priority 7 = 1.05x multiplier)
    final priorityMultiplier = 1.0 + ((8 - diagnosisPriority.priorityNumber) * 0.05);
    final weightedClinicalScore = (clinicalAffinity * priorityMultiplier).clamp(0.0, 1.5);

    // 2. Performance Need Score (0.0 - 1.0)
    double performanceNeed;
    if (snapshot.roundsPlayed == 0) {
      // Unplayed game: moderate exploration incentive
      performanceNeed = 0.65;
    } else {
      // Accuracy deficit: lower accuracy => higher need for practice
      final accuracyDeficit = (1.0 - snapshot.accuracy).clamp(0.0, 1.0);
      // Error burden: higher errors => higher need for reinforcement
      final errorBurden = snapshot.errorRate.clamp(0.0, 1.0);
      // Hesitation burden: higher hesitation => uncertainty in retrieval/attention
      final hesitationBurden = snapshot.hesitationRatio.clamp(0.0, 1.0);
      // Latency factor: higher latency compared to 2500ms baseline ceiling
      final latencyFactor = (snapshot.avgLatencyMs / 2500.0).clamp(0.0, 1.0);

      performanceNeed = (accuracyDeficit * 0.35) +
          (errorBurden * 0.25) +
          (hesitationBurden * 0.25) +
          (latencyFactor * 0.15);
    }

    // Composite: 45% clinical diagnosis priority weight, 55% measured performance need
    return (weightedClinicalScore * 0.45) + (performanceNeed * 0.55);
  }

  /// Generates a human-readable, encouraging clinical explanation for the patient.
  /// Omits raw numerical telemetry scores to prevent overwhelming or causing anxiety to elderly cognitive patients.
  String _generateClinicalRationale({
    required String gameType,
    required PatientDiagnosisInfo diagnosis,
    required GamePerformanceSnapshot snapshot,
    required String domain,
  }) {
    final diagLabel = "${diagnosis.displayName} (Priority ${diagnosis.priorityNumber})";

    if (snapshot.roundsPlayed == 0) {
      return "Recommended for $diagLabel to exercise your $domain and establish your comfortable rhythm.";
    }

    if (snapshot.hesitationRatio >= 0.30 || snapshot.errorRate >= 0.20 || snapshot.accuracy < 0.75) {
      return "Based on your clinical focus for $diagLabel, targeted practice in $domain will strengthen your recall and response confidence.";
    }

    return "Recommended for $diagLabel to sustain your active engagement and steady progress in $domain.";
  }

  Map<String, String> _getGameDetails(String gameType) {
    switch (gameType) {
      case 'market_trip':
        return {
          'title': 'The Market Trip',
          'subtitle': 'Remember the shopping list',
          'domain': 'Working Memory',
        };
      case 'tap_target':
        return {
          'title': 'Tap the Target',
          'subtitle': 'Tap the right item as it appears',
          'domain': 'Attention & Speed',
        };
      case 'pair_matching':
      default:
        return {
          'title': 'Pair Matching',
          'subtitle': 'Flip cards to find matching pairs',
          'domain': 'Episodic Memory',
        };
    }
  }
}
