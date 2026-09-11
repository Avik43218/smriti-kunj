import 'dart:convert';

/// Represents a single cognitive game activity record stored locally in SQLite
/// and queued for synchronization to MongoDB.
class PatientActivityRecord {
  final int? id;
  final String clientSessionId;
  final String patientId;
  final String patientProfileId;
  final String gameType; // 'market_trip' | 'tap_target' | 'pair_matching' | 'word_association' | 'visual_search'
  final String gameName; // Display name, e.g. 'Market Trip', 'Tap the Target', 'Pair Matching'
  final String domain; // 'memory' | 'working_memory' | 'attention' | 'language'
  final int difficultyLevel; // 1 = easy, 2 = medium, 3 = hard
  final double scoreNormalized; // 0.0 to 1.0
  final int sessionDuration; // in seconds
  final double accuracy; // 0.0 to 1.0
  final double avgLatencyMs;
  final double errorRate;
  final DateTime sessionDate;
  final String status; // 'completed' | 'abandoned'
  final Map<String, dynamic> rawPayload;
  final bool isSynced;
  final DateTime? syncedAt;

  PatientActivityRecord({
    this.id,
    required this.clientSessionId,
    required this.patientId,
    required this.patientProfileId,
    required this.gameType,
    required this.gameName,
    required this.domain,
    required this.difficultyLevel,
    required this.scoreNormalized,
    required this.sessionDuration,
    required this.accuracy,
    required this.avgLatencyMs,
    required this.errorRate,
    required this.sessionDate,
    this.status = 'completed',
    this.rawPayload = const {},
    this.isSynced = false,
    this.syncedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'client_session_id': clientSessionId,
      'patient_id': patientId,
      'patient_profile_id': patientProfileId,
      'game_type': gameType,
      'game_name': gameName,
      'domain': domain,
      'difficulty_level': difficultyLevel,
      'score_normalized': scoreNormalized,
      'session_duration': sessionDuration,
      'accuracy': accuracy,
      'avg_latency_ms': avgLatencyMs,
      'error_rate': errorRate,
      'session_date': sessionDate.toIso8601String(),
      'status': status,
      'raw_payload': jsonEncode(rawPayload),
      'is_synced': isSynced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  factory PatientActivityRecord.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> parsedRawPayload = {};
    if (map['raw_payload'] != null) {
      if (map['raw_payload'] is String) {
        try {
          parsedRawPayload = jsonDecode(map['raw_payload'] as String) as Map<String, dynamic>;
        } catch (_) {}
      } else if (map['raw_payload'] is Map) {
        parsedRawPayload = Map<String, dynamic>.from(map['raw_payload'] as Map);
      }
    }

    return PatientActivityRecord(
      id: map['id'] as int?,
      clientSessionId: map['client_session_id'] as String? ?? '',
      patientId: map['patient_id'] as String? ?? '',
      patientProfileId: map['patient_profile_id'] as String? ?? '',
      gameType: map['game_type'] as String? ?? '',
      gameName: map['game_name'] as String? ?? '',
      domain: map['domain'] as String? ?? 'memory',
      difficultyLevel: (map['difficulty_level'] as num?)?.toInt() ?? 1,
      scoreNormalized: (map['score_normalized'] as num?)?.toDouble() ?? 0.0,
      sessionDuration: (map['session_duration'] as num?)?.toInt() ?? 0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      avgLatencyMs: (map['avg_latency_ms'] as num?)?.toDouble() ?? 0.0,
      errorRate: (map['error_rate'] as num?)?.toDouble() ?? 0.0,
      sessionDate: map['session_date'] != null
          ? (DateTime.tryParse(map['session_date'].toString()) ?? DateTime.now())
          : DateTime.now(),
      status: map['status'] as String? ?? 'completed',
      rawPayload: parsedRawPayload,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      syncedAt: map['synced_at'] != null ? DateTime.tryParse(map['synced_at'].toString()) : null,
    );
  }

  /// Converts record to JSON schema expected by POST /api/sync/batch
  Map<String, dynamic> toSyncBatchJson() {
    return {
      'client_session_id': clientSessionId,
      'game_type': gameType,
      'domain': domain,
      'difficulty_level': difficultyLevel.toString(),
      'accuracy': accuracy,
      'avg_latency_ms': avgLatencyMs,
      'error_rate': errorRate,
      'score_normalized': scoreNormalized,
      'session_duration': sessionDuration,
      'status': status,
      'client_timestamp': sessionDate.toUtc().toIso8601String(),
      'raw_payload': {
        ...rawPayload,
        'game_name': gameName,
        'domain': domain,
        'score_normalized': scoreNormalized,
        'session_duration': sessionDuration,
      },
    };
  }
}
