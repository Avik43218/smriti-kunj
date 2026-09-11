import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Clinical difficulty decision emitted by the TFLite UCB1 MLP model.
class DifficultyDecision {
  /// Clinical action label: "Ease Up (-1)", "Maintain (0)", "Level Up (+1)"
  final String action;

  /// Delta to adjust difficulty: -1, 0, or +1
  final int difficultyDelta;

  /// The difficulty of the round just played (1 = easy, 2 = medium, 3 = hard)
  final int previousDifficulty;

  /// Recommended difficulty level for the next game (clamped to 1..3)
  final int recommendedDifficulty;

  /// Highest probability confidence [0.0 - 1.0]
  final double confidence;

  /// Probability distribution across all 3 arms
  final Map<String, double> distribution;

  /// Game type ("market_trip", "tap_target", "pair_matching", etc.)
  final String gameType;

  /// Raw telemetry features extracted: [latency, accuracy, hesitation, error_burst]
  final List<double> featureVector;

  /// ISO8601 timestamp of evaluation
  final DateTime createdAt;

  DifficultyDecision({
    required this.action,
    required this.difficultyDelta,
    required this.previousDifficulty,
    required this.recommendedDifficulty,
    required this.confidence,
    required this.distribution,
    this.gameType = '',
    required this.featureVector,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'action': action,
        'difficulty_delta': difficultyDelta,
        'previous_difficulty': previousDifficulty,
        'recommended_difficulty': recommendedDifficulty,
        'confidence': confidence,
        'distribution': distribution,
        'game_type': gameType,
        'feature_vector': featureVector,
        'created_at': createdAt.toIso8601String(),
      };

  factory DifficultyDecision.fromJson(Map<String, dynamic> json) {
    final distMap = json['distribution'] as Map<String, dynamic>? ?? {};
    final fList = (json['feature_vector'] as List<dynamic>? ?? [])
        .map((e) => (e as num).toDouble())
        .toList();

    return DifficultyDecision(
      action: json['action'] as String? ?? 'Maintain (0)',
      difficultyDelta: (json['difficulty_delta'] as num?)?.toInt() ?? 0,
      previousDifficulty:
          (json['previous_difficulty'] as num?)?.toInt() ?? 1,
      recommendedDifficulty:
          (json['recommended_difficulty'] as num?)?.toInt() ?? 1,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      distribution: distMap.map((k, v) => MapEntry(k, (v as num).toDouble())),
      gameType: json['game_type'] as String? ?? '',
      featureVector: fList,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Dynamic Difficulty Service that loads and spins up the on-device TFLite model.
///
/// Features expected by the 3-layer MLP:
///   [norm_latency, accuracy, hesitation, error_burst]
///
/// Outputs 3 action probabilities:
///   - Arm 0: Ease Up (-1)
///   - Arm 1: Maintain (0)
///   - Arm 2: Level Up (+1)
class DynamicDifficultyService {
  static final DynamicDifficultyService instance =
      DynamicDifficultyService._internal();

  DynamicDifficultyService._internal();
  factory DynamicDifficultyService() => instance;

  Interpreter? _interpreter;
  bool _isInitialized = false;
  bool _useFallback = false;

  final List<String> _actions = [
    "Ease Up (-1)",
    "Maintain (0)",
    "Level Up (+1)"
  ];
  final List<int> _deltas = [-1, 0, 1];

  bool get isInitialized => _isInitialized;
  bool get isTfliteActive => _interpreter != null && !_useFallback;

  /// Loads the TFLite model asset into memory.
  Future<void> init() async {
    if (_isInitialized && _interpreter != null) return;

    final candidateAssets = [
      'assets/models/difficulty_mlp_ucb1.tflite',
      'agents/difficulty_mlp_ucb1.tflite',
    ];

    for (final assetPath in candidateAssets) {
      try {
        _interpreter = await Interpreter.fromAsset(assetPath);
        _isInitialized = true;
        _useFallback = false;
        debugPrint(
            '[DynamicDifficultyService] TFLite UCB1 MLP loaded successfully from $assetPath');
        return;
      } catch (e) {
        debugPrint(
            '[DynamicDifficultyService] Attempting $assetPath: $e');
      }
    }

    // If native TFLite binaries are not present on the host (e.g. desktop/test),
    // fallback gracefully to algorithmic UCB1 policy to ensure zero crashes.
    _useFallback = true;
    _isInitialized = true;
    debugPrint(
        '[DynamicDifficultyService] Using high-fidelity algorithmic UCB1 policy fallback.');
  }

  /// Extracts the 4-feature vector [norm_latency, accuracy, hesitation, error_burst]
  /// from any game's raw JSON telemetry map.
  List<double> extractFeatures(Map<String, dynamic> raw) {
    // Check if telemetry is nested
    Map<String, dynamic> data = raw;
    if (raw.containsKey('game_data') && raw['game_data'] is Map) {
      final gd = raw['game_data'] as Map<String, dynamic>;
      if (gd.containsKey('telemetry') && gd['telemetry'] is Map) {
        data = gd['telemetry'] as Map<String, dynamic>;
      } else {
        data = gd;
      }
    } else if (raw.containsKey('telemetry') && raw['telemetry'] is Map) {
      data = raw['telemetry'] as Map<String, dynamic>;
    }

    // 1. Latency (ms) -> normalized against 2500ms ceiling
    double rawLatency = 650.0;
    if (data.containsKey('reaction_time_ms') && data['reaction_time_ms'] is num) {
      rawLatency = (data['reaction_time_ms'] as num).toDouble();
    } else if (data.containsKey('latency_ms') && data['latency_ms'] is num) {
      rawLatency = (data['latency_ms'] as num).toDouble();
    } else if (data.containsKey('reaction_time_avg') &&
        data['reaction_time_avg'] is num) {
      rawLatency = (data['reaction_time_avg'] as num).toDouble();
    } else if (data.containsKey('latency') && data['latency'] is Map) {
      final latMap = data['latency'] as Map<String, dynamic>;
      rawLatency = (latMap['avg_ms'] as num?)?.toDouble() ??
          (latMap['median_ms'] as num?)?.toDouble() ??
          650.0;
    } else if (data.containsKey('time_to_complete_recall') &&
        data['time_to_complete_recall'] is num) {
      rawLatency = (data['time_to_complete_recall'] as num).toDouble() * 1000.0;
    }
    final double normLatency = (rawLatency / 2500.0).clamp(0.0, 1.0);

    // 2. Accuracy [0.0 - 1.0]
    double accuracy = 0.75;
    if (data.containsKey('accuracy') && data['accuracy'] is num) {
      accuracy = (data['accuracy'] as num).toDouble();
    } else if (data.containsKey('accuracy') && data['accuracy'] is Map) {
      final accMap = data['accuracy'] as Map<String, dynamic>;
      accuracy = (accMap['overall_rate'] as num?)?.toDouble() ?? 0.75;
    } else if (data.containsKey('recall_accuracy') &&
        data['recall_accuracy'] is num) {
      accuracy = (data['recall_accuracy'] as num).toDouble();
    } else if (data.containsKey('correct_match_rate') &&
        data['correct_match_rate'] is num) {
      accuracy = (data['correct_match_rate'] as num).toDouble();
    } else if (data.containsKey('score_normalized') &&
        data['score_normalized'] is num) {
      accuracy = (data['score_normalized'] as num).toDouble();
    } else if (data.containsKey('omission_rate') &&
        data['omission_rate'] is num) {
      accuracy = (1.0 - (data['omission_rate'] as num).toDouble());
    }
    accuracy = accuracy.clamp(0.0, 1.0);

    // 3. Hesitation [0.0 - 1.0]
    double hesitation = 0.30;
    if (data.containsKey('hesitation') && data['hesitation'] is num) {
      hesitation = (data['hesitation'] as num).toDouble();
    } else if (data.containsKey('hesitation') && data['hesitation'] is Map) {
      final hesMap = data['hesitation'] as Map<String, dynamic>;
      if (hesMap.containsKey('hesitation_ratio') &&
          hesMap['hesitation_ratio'] is num) {
        hesitation = (hesMap['hesitation_ratio'] as num).toDouble();
      } else if (hesMap.containsKey('is_hesitation') &&
          hesMap['is_hesitation'] is bool) {
        hesitation = (hesMap['is_hesitation'] as bool) ? 0.70 : 0.15;
      }
    } else if (data.containsKey('hesitation_ratio') &&
        data['hesitation_ratio'] is num) {
      hesitation = (data['hesitation_ratio'] as num).toDouble();
    }
    hesitation = hesitation.clamp(0.0, 1.0);

    // 4. Error Burst [0.0 - 1.0]
    double errorBurst = 0.10;
    if (data.containsKey('error_burst') && data['error_burst'] is num) {
      errorBurst = (data['error_burst'] as num).toDouble();
    } else if (data.containsKey('error_burst') && data['error_burst'] is Map) {
      final ebMap = data['error_burst'] as Map<String, dynamic>;
      if (ebMap.containsKey('error_burst_rate') &&
          ebMap['error_burst_rate'] is num) {
        errorBurst = (ebMap['error_burst_rate'] as num).toDouble();
      } else if (ebMap.containsKey('is_error_burst') &&
          ebMap['is_error_burst'] is bool) {
        errorBurst = (ebMap['is_error_burst'] as bool) ? 0.80 : 0.0;
      } else if (ebMap.containsKey('burst_detected') &&
          ebMap['burst_detected'] is bool) {
        errorBurst = (ebMap['burst_detected'] as bool) ? 0.80 : 0.0;
      }
    } else if (data.containsKey('error_burst_rate') &&
        data['error_burst_rate'] is num) {
      errorBurst = (data['error_burst_rate'] as num).toDouble();
    } else if (data.containsKey('repeat_error_rate') &&
        data['repeat_error_rate'] is num) {
      errorBurst = (data['repeat_error_rate'] as num).toDouble();
    } else if (data.containsKey('false_positive_rate') &&
        data['false_positive_rate'] is num) {
      errorBurst = (data['false_positive_rate'] as num).toDouble();
    }
    errorBurst = errorBurst.clamp(0.0, 1.0);

    return [normLatency, accuracy, hesitation, errorBurst];
  }

  /// Evaluates raw JSON string or map, executing on-device inference,
  /// and returns the structured [DifficultyDecision].
  Future<DifficultyDecision> evaluateSessionJson(
    String jsonString, {
    int currentDifficulty = 1,
    String gameType = '',
  }) async {
    if (!_isInitialized) {
      await init();
    }

    final dynamic parsed = jsonDecode(jsonString);
    final Map<String, dynamic> data =
        parsed is Map<String, dynamic> ? parsed : Map<String, dynamic>.from(parsed as Map);

    final features = extractFeatures(data);
    final normLatency = features[0];
    final accuracy = features[1];
    final hesitation = features[2];
    final errorBurst = features[3];

    List<double> probabilities;

    if (_interpreter != null && !_useFallback) {
      try {
        var input = [
          [normLatency, accuracy, hesitation, errorBurst]
        ];
        var output = List.generate(1, (_) => List.filled(3, 0.0));
        _interpreter!.run(input, output);
        probabilities = output[0];
      } catch (e) {
        debugPrint(
            '[DynamicDifficultyService] Inference error, fallback to UCB1 policy: $e');
        probabilities = _computeUcb1FallbackProbs(
            normLatency, accuracy, hesitation, errorBurst);
      }
    } else {
      probabilities = _computeUcb1FallbackProbs(
          normLatency, accuracy, hesitation, errorBurst);
    }

    // Argmax selection
    int bestIndex = 0;
    double maxProb = probabilities[0];
    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        bestIndex = i;
      }
    }

    final delta = _deltas[bestIndex];
    final recommended = (currentDifficulty + delta).clamp(1, 3);

    final decision = DifficultyDecision(
      action: _actions[bestIndex],
      difficultyDelta: delta,
      previousDifficulty: currentDifficulty,
      recommendedDifficulty: recommended,
      confidence: maxProb,
      distribution: {
        _actions[0]: probabilities[0],
        _actions[1]: probabilities[1],
        _actions[2]: probabilities[2],
      },
      gameType: gameType,
      featureVector: features,
    );

    debugPrint(
        '[DynamicDifficultyService] Evaluated $gameType: ${decision.action} '
        '(level: $currentDifficulty -> $recommended, confidence: ${(maxProb * 100).toStringAsFixed(1)}%)');

    return decision;
  }

  /// Algorithmic UCB1 Distillation policy fallback matching agents/train.py.
  List<double> _computeUcb1FallbackProbs(
    double latency,
    double accuracy,
    double hesitation,
    double errorBurst,
  ) {
    // Struggling archetype indicator:
    // Low accuracy, high latency, high hesitation, high error burst
    final strugglingScore =
        (1.0 - accuracy) * 0.40 + latency * 0.25 + hesitation * 0.20 + errorBurst * 0.15;

    // Cruising archetype indicator:
    // High accuracy, low latency, low hesitation, low error burst
    final cruisingScore =
        accuracy * 0.45 + (1.0 - latency) * 0.25 + (1.0 - hesitation) * 0.15 + (1.0 - errorBurst) * 0.15;

    double rEase = 0.15;
    double rMaintain = 0.70;
    double rLevelUp = 0.15;

    if (strugglingScore > 0.55 || accuracy < 0.50 || errorBurst >= 0.50) {
      // Patient is struggling -> ease up
      rEase = 0.88;
      rMaintain = 0.10;
      rLevelUp = 0.02;
    } else if (cruisingScore > 0.75 && accuracy >= 0.85 && errorBurst < 0.20) {
      // Patient is cruising -> level up
      rEase = 0.05;
      rMaintain = 0.25;
      rLevelUp = 0.70;
    } else {
      // Patient in steady flow state -> maintain
      rEase = 0.15;
      rMaintain = 0.72;
      rLevelUp = 0.13;
    }

    // Softmax with temperature 0.25
    const double tau = 0.25;
    final maxR = max(rEase, max(rMaintain, rLevelUp));
    final e0 = exp((rEase - maxR) / tau);
    final e1 = exp((rMaintain - maxR) / tau);
    final e2 = exp((rLevelUp - maxR) / tau);
    final sumE = e0 + e1 + e2;

    return [e0 / sumE, e1 / sumE, e2 / sumE];
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}
