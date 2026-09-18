/// Analytics result for a single Tap the Target game session.
/// Matches the schema defined in GAMES_ANALYTICS_README.md — Game 4.
class TapTargetSessionResult {
  // ── Game-specific analytics ──────────────────────────────────────────────
  /// Average reaction time in milliseconds across all correct taps.
  final double reactionTimeAvg;

  /// Standard deviation of reaction times (ms). High variability is an
  /// early-decline signal even when average speed looks normal.
  final double reactionTimeVariability;

  /// Missed targets / total targets shown (0.0–1.0).
  final double omissionRate;

  /// Incorrect taps / total taps made (0.0–1.0).
  final double falsePositiveRate;

  /// Performance delta: (late-trial accuracy − early-trial accuracy).
  /// Negative value = fatigue or attention drift within the session.
  final double withinSessionDrift;

  /// Total number of target appearances shown in the session.
  final int trialCount;

  /// The culturally-customized target used for this session (e.g. "japi").
  final String targetItemType;

  // ── Shared session fields ────────────────────────────────────────────────
  final String sessionId;
  final String patientProfileId;
  final String gameType;   // always "visual_search"
  final String domain;     // always "attention"
  final DateTime sessionDate;
  final double sessionDuration; // seconds
  final String status;     // "completed" | "abandoned"
  final int difficultyLevel; // 1 = easy, 2 = medium, 3 = hard
  final double scoreNormalized; // 0.0–1.0, relative to patient's own baseline
  final List<Map<String, dynamic>> rawTrials; // per-tap event log

  const TapTargetSessionResult({
    required this.reactionTimeAvg,
    required this.reactionTimeVariability,
    required this.omissionRate,
    required this.falsePositiveRate,
    required this.withinSessionDrift,
    required this.trialCount,
    required this.targetItemType,
    required this.sessionId,
    required this.patientProfileId,
    this.gameType = 'visual_search',
    this.domain = 'attention',
    required this.sessionDate,
    required this.sessionDuration,
    required this.status,
    required this.difficultyLevel,
    required this.scoreNormalized,
    required this.rawTrials,
  });

  Map<String, dynamic> toJson() => {
        'reaction_time_avg': reactionTimeAvg,
        'reaction_time_variability': reactionTimeVariability,
        'omission_rate': omissionRate,
        'false_positive_rate': falsePositiveRate,
        'within_session_drift': withinSessionDrift,
        'trial_count': trialCount,
        'target_item_type': targetItemType,
        'session_id': sessionId,
        'patient_profile_id': patientProfileId,
        'game_type': gameType,
        'domain': domain,
        'session_date': sessionDate.toIso8601String(),
        'session_duration': sessionDuration,
        'status': status,
        'difficulty_level': difficultyLevel,
        'score_normalized': scoreNormalized,
        'raw_trials': rawTrials,
      };

  factory TapTargetSessionResult.fromJson(Map<String, dynamic> json) {
    final rawList = json['raw_trials'] as List<dynamic>? ?? [];
    return TapTargetSessionResult(
      reactionTimeAvg: (json['reaction_time_avg'] as num?)?.toDouble() ?? 0.0,
      reactionTimeVariability:
          (json['reaction_time_variability'] as num?)?.toDouble() ?? 0.0,
      omissionRate: (json['omission_rate'] as num?)?.toDouble() ?? 0.0,
      falsePositiveRate:
          (json['false_positive_rate'] as num?)?.toDouble() ?? 0.0,
      withinSessionDrift:
          (json['within_session_drift'] as num?)?.toDouble() ?? 0.0,
      trialCount: (json['trial_count'] as num?)?.toInt() ?? 0,
      targetItemType: json['target_item_type'] as String? ?? 'unknown',
      sessionId: json['session_id'] as String? ?? '',
      patientProfileId: json['patient_profile_id'] as String? ?? '',
      gameType: json['game_type'] as String? ?? 'visual_search',
      domain: json['domain'] as String? ?? 'attention',
      sessionDate: json['session_date'] != null
          ? DateTime.tryParse(json['session_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      sessionDuration: (json['session_duration'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'completed',
      difficultyLevel: (json['difficulty_level'] as num?)?.toInt() ?? 1,
      scoreNormalized: (json['score_normalized'] as num?)?.toDouble() ?? 0.0,
      rawTrials: rawList
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }
}
