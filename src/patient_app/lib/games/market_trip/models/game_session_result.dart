/// Model representing the computed analytics and session parameters for a Market Trip game session.
/// Matches the schema specified in GAMES_ANALYTICS_README.md.
class GameSessionResult {
  // Game-specific analytics parameters
  final int itemsPromptedCount;
  final int itemsRecalledCorrect;
  final double recallAccuracy;
  final int falseSelectionCount;
  final double timeToCompleteRecall;
  final bool distractorTaskCompleted;
  final double delayDuration;
  final String promptLanguage;

  // Shared session fields
  final String sessionId;
  final String patientProfileId;
  final String gameType;
  final String domain;
  final DateTime sessionDate;
  final double sessionDuration;
  final String status;
  final double scoreNormalized;
  final List<Map<String, dynamic>> rawTrials;

  const GameSessionResult({
    required this.itemsPromptedCount,
    required this.itemsRecalledCorrect,
    required this.recallAccuracy,
    required this.falseSelectionCount,
    required this.timeToCompleteRecall,
    required this.distractorTaskCompleted,
    required this.delayDuration,
    required this.promptLanguage,
    required this.sessionId,
    required this.patientProfileId,
    this.gameType = 'market_trip',
    this.domain = 'working_memory',
    required this.sessionDate,
    required this.sessionDuration,
    required this.status,
    required this.scoreNormalized,
    required this.rawTrials,
  });

  factory GameSessionResult.fromJson(Map<String, dynamic> json) {
    final rawTrialsList = json['raw_trials'] as List<dynamic>? ?? [];
    final trialsMap = rawTrialsList
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return GameSessionResult(
      itemsPromptedCount: (json['items_prompted_count'] as num?)?.toInt() ?? 0,
      itemsRecalledCorrect: (json['items_recalled_correct'] as num?)?.toInt() ?? 0,
      recallAccuracy: (json['recall_accuracy'] as num?)?.toDouble() ?? 0.0,
      falseSelectionCount: (json['false_selection_count'] as num?)?.toInt() ?? 0,
      timeToCompleteRecall: (json['time_to_complete_recall'] as num?)?.toDouble() ?? 0.0,
      distractorTaskCompleted: json['distractor_task_completed'] as bool? ?? false,
      delayDuration: (json['delay_duration'] as num?)?.toDouble() ?? 0.0,
      promptLanguage: json['prompt_language'] as String? ?? 'assamese',
      sessionId: json['session_id'] as String? ?? '',
      patientProfileId: json['patient_profile_id'] as String? ?? '',
      gameType: json['game_type'] as String? ?? 'market_trip',
      domain: json['domain'] as String? ?? 'working_memory',
      sessionDate: json['session_date'] != null
          ? DateTime.tryParse(json['session_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      sessionDuration: (json['session_duration'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'completed',
      scoreNormalized: (json['score_normalized'] as num?)?.toDouble() ?? 0.0,
      rawTrials: trialsMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items_prompted_count': itemsPromptedCount,
      'items_recalled_correct': itemsRecalledCorrect,
      'recall_accuracy': recallAccuracy,
      'false_selection_count': falseSelectionCount,
      'time_to_complete_recall': timeToCompleteRecall,
      'distractor_task_completed': distractorTaskCompleted,
      'delay_duration': delayDuration,
      'prompt_language': promptLanguage,
      'session_id': sessionId,
      'patient_profile_id': patientProfileId,
      'game_type': gameType,
      'domain': domain,
      'session_date': sessionDate.toIso8601String(),
      'session_duration': sessionDuration,
      'status': status,
      'score_normalized': scoreNormalized,
      'raw_trials': rawTrials,
    };
  }
}
