import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class DifficultyDecision {
  final String action;          // "Ease Up (-1)", "Maintain (0)", "Level Up (+1)"
  final int difficultyDelta;    // -1, 0, +1
  final double confidence;      // Highest confidence probability
  final Map<String, double> distribution;

  DifficultyDecision({
    required this.action,
    required this.difficultyDelta,
    required this.confidence,
    required this.distribution,
  });
}

class DynamicDifficultyService {
  Interpreter? _interpreter;
  final List<String> _actions = ["Ease Up (-1)", "Maintain (0)", "Level Up (+1)"];
  final List<int> _deltas = [-1, 0, 1];

  // 1. Initialize and load model into memory
  Future<void> init() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/difficulty_mlp_ucb1.tflite');
      print("TFLite UCB1 MLP loaded successfully on-device!");
    } catch (e) {
      print("Failed to load TFLite model: $e");
    }
  }

  // 2. Process JSON telemetry and execute inference
  DifficultyDecision evaluateSession(String jsonString) {
    if (_interpreter == null) {
      throw Exception("Interpreter not initialized. Call init() first.");
    }

    final Map<String, dynamic> data = jsonDecode(jsonString);

    // Extract & normalize inputs into the 4-feature vector [0.0 - 1.0][cite: 1]
    final double rawLatencyMs = (data['reaction_time_ms'] as num).toDouble();
    final double normLatency = (rawLatencyMs / 2500.0).clamp(0.0, 1.0);
    final double accuracy = (data['accuracy'] as num).toDouble().clamp(0.0, 1.0);
    final double hesitation = (data['hesitation'] as num).toDouble().clamp(0.0, 1.0);
    final double errorBurst = (data['error_burst'] as num).toDouble().clamp(0.0, 1.0);

    // Input shape: [1, 4]
    var input = [
      [normLatency, accuracy, hesitation, errorBurst]
    ];

    // Output shape: [1, 3] (Distilled UCB1 probabilities)[cite: 1]
    var output = List.generate(1, (_) => List.filled(3, 0.0));

    // Run synchronous on-device inference (<2ms)
    _interpreter!.run(input, output);

    List<double> probabilities = output[0];

    // Find argmax for the optimal clinical decision
    int bestIndex = 0;
    double maxProb = probabilities[0];
    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        bestIndex = i;
      }
    }

    return DifficultyDecision(
      action: _actions[bestIndex],
      difficultyDelta: _deltas[bestIndex],
      confidence: maxProb,
      distribution: {
        _actions[0]: probabilities[0],
        _actions[1]: probabilities[1],
        _actions[2]: probabilities[2],
      },
    );
  }

  void dispose() {
    _interpreter?.close();
  }
}
