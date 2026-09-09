/// Analytics result for a single Pair Matching game session.
/// Matches the schema defined in GAMES_ANALYTICS_README.md — Game 2.
class PairMatchingSessionResult {
  // ── Game-specific analytics ──────────────────────────────────────────────
  /// Total card flips taken across the entire session.
  final int totalFlips;

  /// Correct matches / total match attempts (0.0–1.0).
  final double correctMatchRate;

  /// Time in seconds from game start to first successful match.
  final double timeToFirstCorrectMatch;

  /// Ratio of pairs with 2+ misses to total pairs (0.0–1.0).
  /// Signals encoding failure rather than just slow recall.
  final double repeatErrorRate;

  /// Total time in seconds to complete the round.
  final double completionTime;

  /// Number of distinct pairs in the game (4, 6, or 8).
  final int pairsCount;

  /// Whether caregiver-uploaded family photos were used vs. generic icons.
  final bool usedFaceNameVariant;

  // ── Shared session fields ────────────────────────────────────────────────
  final String sessionId;
  final String patientProfileId;
  final String gameType; // always "pair_matching"
  final String domain; // always "episodic_memory"
  final DateTime sessionDate;
  final double sessionDuration; // seconds
  final String status; // "completed" | "abandoned"
  final int difficultyLevel; // 1 = easy, 2 = medium, 3 = hard
  final double scoreNormalized; // 0.0–1.0, relative to patient's own baseline
  final List<Map<String, dynamic>> rawTrials; // per-flip/attempt event log

  const PairMatchingSessionResult({
    required this.totalFlips,
    required this.correctMatchRate,
    required this.timeToFirstCorrectMatch,
    required this.repeatErrorRate,
    required this.completionTime,
    required this.pairsCount,
    required this.usedFaceNameVariant,
    required this.sessionId,
    required this.patientProfileId,
    this.gameType = 'pair_matching',
    this.domain = 'episodic_memory',
    required this.sessionDate,
    required this.sessionDuration,
    required this.status,
    required this.difficultyLevel,
    required this.scoreNormalized,
    required this.rawTrials,
  });

  Map<String, dynamic> toJson() => {
        'total_flips': totalFlips,
        'correct_match_rate': correctMatchRate,
        'time_to_first_correct_match': timeToFirstCorrectMatch,
        'repeat_error_rate': repeatErrorRate,
        'completion_time': completionTime,
        'pairs_count': pairsCount,
        'used_face_name_variant': usedFaceNameVariant,
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

  factory PairMatchingSessionResult.fromJson(Map<String, dynamic> json) {
    final rawList = json['raw_trials'] as List<dynamic>? ?? [];
    return PairMatchingSessionResult(
      totalFlips: (json['total_flips'] as num?)?.toInt() ?? 0,
      correctMatchRate:
          (json['correct_match_rate'] as num?)?.toDouble() ?? 0.0,
      timeToFirstCorrectMatch:
          (json['time_to_first_correct_match'] as num?)?.toDouble() ?? 0.0,
      repeatErrorRate:
          (json['repeat_error_rate'] as num?)?.toDouble() ?? 0.0,
      completionTime: (json['completion_time'] as num?)?.toDouble() ?? 0.0,
      pairsCount: (json['pairs_count'] as num?)?.toInt() ?? 4,
      usedFaceNameVariant: json['used_face_name_variant'] as bool? ?? false,
      sessionId: json['session_id'] as String? ?? '',
      patientProfileId: json['patient_profile_id'] as String? ?? '',
      gameType: json['game_type'] as String? ?? 'pair_matching',
      domain: json['domain'] as String? ?? 'episodic_memory',
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
