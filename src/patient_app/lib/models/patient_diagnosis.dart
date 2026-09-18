import 'package:flutter/foundation.dart';

/// Clinical diagnosis categories, assigned priority numbers (1-7),
/// and therapeutic cognitive domain affinities.
enum DiagnosisPriority {
  earlyStageAlzheimers(
    displayName: "Early Stage Alzheimer's",
    priorityNumber: 1,
    primaryDomains: ['episodic_memory', 'working_memory', 'memory'],
    recommendedGames: ['pair_matching', 'market_trip', 'tap_target'],
    description: "Focuses on preserving episodic recall and delayed retrieval.",
  ),
  vascularDementia(
    displayName: "Vascular Dementia",
    priorityNumber: 2,
    primaryDomains: ['attention', 'processing_speed'],
    recommendedGames: ['tap_target', 'market_trip', 'pair_matching'],
    description: "Targets processing speed, psychomotor reaction, and sustained attention.",
  ),
  frontotemporalDementia(
    displayName: "Frontotemporal Dementia",
    priorityNumber: 3,
    primaryDomains: ['attention', 'response_inhibition', 'executive_function'],
    recommendedGames: ['tap_target', 'pair_matching', 'market_trip'],
    description: "Reinforces response inhibition, selective attention, and vigilance.",
  ),
  mildCognitiveImpairment(
    displayName: "Mild Cognitive Impairment",
    priorityNumber: 4,
    primaryDomains: ['working_memory', 'episodic_memory'],
    recommendedGames: ['market_trip', 'pair_matching', 'tap_target'],
    description: "Promotes working memory consolidation and item recall.",
  ),
  subjectiveCognitiveDecline(
    displayName: "Subjective Cognitive Decline",
    priorityNumber: 5,
    primaryDomains: ['working_memory', 'attention'],
    recommendedGames: ['market_trip', 'tap_target', 'pair_matching'],
    description: "Maintains cognitive reserve with balanced memory and attention challenges.",
  ),
  ageAssociatedMemoryImpairment(
    displayName: "Age-Associated Memory Impairment",
    priorityNumber: 6,
    primaryDomains: ['attention', 'episodic_memory'],
    recommendedGames: ['tap_target', 'pair_matching', 'market_trip'],
    description: "Strengthens visual-motor speed and memory retention.",
  ),
  otherUnderObservation(
    displayName: "Other / Under Observation",
    priorityNumber: 7,
    primaryDomains: ['memory', 'attention'],
    recommendedGames: ['market_trip', 'tap_target', 'pair_matching'],
    description: "General cognitive stimulation across memory and attention domains.",
  );

  final String displayName;
  final int priorityNumber;
  final List<String> primaryDomains;
  final List<String> recommendedGames;
  final String description;

  const DiagnosisPriority({
    required this.displayName,
    required this.priorityNumber,
    required this.primaryDomains,
    required this.recommendedGames,
    required this.description,
  });

  /// Normalizes and matches any valid diagnosis string to its standardized priority.
  static DiagnosisPriority fromString(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return DiagnosisPriority.otherUnderObservation;
    }
    final clean = raw.trim().toLowerCase();
    if (clean.contains('alzheimer')) {
      return DiagnosisPriority.earlyStageAlzheimers;
    } else if (clean.contains('vascular')) {
      return DiagnosisPriority.vascularDementia;
    } else if (clean.contains('frontotemporal') || clean.contains('ftd')) {
      return DiagnosisPriority.frontotemporalDementia;
    } else if (clean.contains('mild cognitive') || clean.contains('mci')) {
      return DiagnosisPriority.mildCognitiveImpairment;
    } else if (clean.contains('subjective cognitive') || clean.contains('scd')) {
      return DiagnosisPriority.subjectiveCognitiveDecline;
    } else if (clean.contains('age-associated') || clean.contains('age associated') || clean.contains('aami')) {
      return DiagnosisPriority.ageAssociatedMemoryImpairment;
    } else {
      return DiagnosisPriority.otherUnderObservation;
    }
  }

  /// Looks up diagnosis by priority number (1-7).
  static DiagnosisPriority fromPriorityNumber(int priority) {
    for (final dp in DiagnosisPriority.values) {
      if (dp.priorityNumber == priority) return dp;
    }
    return DiagnosisPriority.otherUnderObservation;
  }
}

/// Represents the patient's clinical diagnosis record stored in local SQLite
/// and fetched from MongoDB.
@immutable
class PatientDiagnosisInfo {
  final int? id;
  final String pairingCode;
  final String patientId;
  final String patientName;
  final String rawDiagnosis;
  final DiagnosisPriority priority;
  final DateTime fetchedAt;

  const PatientDiagnosisInfo({
    this.id,
    required this.pairingCode,
    required this.patientId,
    required this.patientName,
    required this.rawDiagnosis,
    required this.priority,
    required this.fetchedAt,
  });

  int get priorityNumber => priority.priorityNumber;
  String get displayName => priority.displayName;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'pairing_code': pairingCode.trim().toUpperCase(),
      'patient_id': patientId,
      'patient_name': patientName,
      'diagnosis': rawDiagnosis.trim().isNotEmpty ? rawDiagnosis.trim() : priority.displayName,
      'priority': priority.priorityNumber,
      'fetched_at': fetchedAt.toIso8601String(),
    };
  }

  factory PatientDiagnosisInfo.fromMap(Map<String, dynamic> map) {
    final rawDiag = (map['diagnosis'] as String?) ?? '';
    final priorityNum = (map['priority'] as num?)?.toInt();
    final priority = priorityNum != null
        ? DiagnosisPriority.fromPriorityNumber(priorityNum)
        : DiagnosisPriority.fromString(rawDiag);

    return PatientDiagnosisInfo(
      id: map['id'] as int?,
      pairingCode: (map['pairing_code'] as String?) ?? '',
      patientId: (map['patient_id'] as String?) ?? '',
      patientName: (map['patient_name'] as String?) ?? '',
      rawDiagnosis: rawDiag,
      priority: priority,
      fetchedAt: map['fetched_at'] != null
          ? (DateTime.tryParse(map['fetched_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  factory PatientDiagnosisInfo.fromJson(Map<String, dynamic> json, {String? defaultPairingCode}) {
    final rawDiag = (json['diagnosis'] as String?) ?? '';
    final pairingCode = (json['pairing_code'] as String?) ?? defaultPairingCode ?? '';
    final priority = DiagnosisPriority.fromString(rawDiag);

    return PatientDiagnosisInfo(
      pairingCode: pairingCode,
      patientId: (json['patient_id'] as String?) ?? (json['id'] as String?) ?? '',
      patientName: (json['patient_name'] as String?) ?? (json['name'] as String?) ?? '',
      rawDiagnosis: rawDiag,
      priority: priority,
      fetchedAt: DateTime.now(),
    );
  }

  PatientDiagnosisInfo copyWith({
    int? id,
    String? pairingCode,
    String? patientId,
    String? patientName,
    String? rawDiagnosis,
    DiagnosisPriority? priority,
    DateTime? fetchedAt,
  }) {
    return PatientDiagnosisInfo(
      id: id ?? this.id,
      pairingCode: pairingCode ?? this.pairingCode,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      rawDiagnosis: rawDiagnosis ?? this.rawDiagnosis,
      priority: priority ?? this.priority,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }
}
