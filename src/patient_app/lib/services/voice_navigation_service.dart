import 'package:flutter/material.dart';

/// The 5 supported voice navigation commands.
enum VoiceCommand {
  game,
  marketTrip,
  tapTarget,
  patternMatch,
  logout,
}

extension VoiceCommandDetails on VoiceCommand {
  String get id {
    switch (this) {
      case VoiceCommand.game:
        return 'game';
      case VoiceCommand.marketTrip:
        return 'market_trip';
      case VoiceCommand.tapTarget:
        return 'tap_target';
      case VoiceCommand.patternMatch:
        return 'pattern_match';
      case VoiceCommand.logout:
        return 'logout';
    }
  }

  String get englishTitle {
    switch (this) {
      case VoiceCommand.game:
        return 'Game';
      case VoiceCommand.marketTrip:
        return 'Market Trip';
      case VoiceCommand.tapTarget:
        return 'Tap the target';
      case VoiceCommand.patternMatch:
        return 'Pattern match';
      case VoiceCommand.logout:
        return 'Logout';
    }
  }

  String get bengaliTitle {
    switch (this) {
      case VoiceCommand.game:
        return 'খেলা';
      case VoiceCommand.marketTrip:
        return 'বাজারের যাত্রা';
      case VoiceCommand.tapTarget:
        return 'লক্ষ্যে ট্যাপ';
      case VoiceCommand.patternMatch:
        return 'প্যাটার্ন ম্যাচ';
      case VoiceCommand.logout:
        return 'লগআউট';
    }
  }

  String get englishSubtitle {
    switch (this) {
      case VoiceCommand.game:
        return 'Opens brain games library';
      case VoiceCommand.marketTrip:
        return 'Memory shopping list game';
      case VoiceCommand.tapTarget:
        return 'Attention & reflex game';
      case VoiceCommand.patternMatch:
        return 'Flip & find matching pairs';
      case VoiceCommand.logout:
        return 'Unpair and exit device';
    }
  }

  String get bengaliSubtitle {
    switch (this) {
      case VoiceCommand.game:
        return 'মগজের খেলার তালিকা খুলুন';
      case VoiceCommand.marketTrip:
        return 'বাজারের তালিকা মনে রাখার খেলা';
      case VoiceCommand.tapTarget:
        return 'লক্ষ্য দেখে সঠিক বস্তু স্পর্শ করুন';
      case VoiceCommand.patternMatch:
        return 'মিলন জোড়া খুঁজে বের করার খেলা';
      case VoiceCommand.logout:
        return 'ডিভাইস থেকে প্রস্থান ও আনপেয়ার করুন';
    }
  }

  IconData get icon {
    switch (this) {
      case VoiceCommand.game:
        return Icons.extension_rounded;
      case VoiceCommand.marketTrip:
        return Icons.shopping_basket_rounded;
      case VoiceCommand.tapTarget:
        return Icons.touch_app_rounded;
      case VoiceCommand.patternMatch:
        return Icons.flip_rounded;
      case VoiceCommand.logout:
        return Icons.logout_rounded;
    }
  }

  Color get color {
    switch (this) {
      case VoiceCommand.game:
        return const Color(0xFFC85A32); // terracotta
      case VoiceCommand.marketTrip:
        return const Color(0xFFE27248);
      case VoiceCommand.tapTarget:
        return const Color(0xFF9E3E1B);
      case VoiceCommand.patternMatch:
        return const Color(0xFFC28B2E); // mugaGold
      case VoiceCommand.logout:
        return const Color(0xFFB33927);
    }
  }
}

/// Result of evaluating a voice query.
class VoiceCommandMatch {
  final VoiceCommand command;
  final String matchedCandidate;
  final double confidence;
  final bool isBengali;

  const VoiceCommandMatch({
    required this.command,
    required this.matchedCandidate,
    required this.confidence,
    required this.isBengali,
  });
}

/// Engine that parses transcribed voice input into navigation actions.
class VoiceNavigationService {
  static final VoiceNavigationService instance = VoiceNavigationService._internal();
  VoiceNavigationService._internal();
  factory VoiceNavigationService() => instance;

  // ── English keywords & phrases ──────────────────────────────────────────
  static const List<String> _gameEnglish = [
    'game',
    'games',
    'brain game',
    'brain games',
    'play game',
    'play games',
    'open games',
    'open game',
    'khel',
  ];

  static const List<String> _marketTripEnglish = [
    'market trip',
    'the market trip',
    'market',
    'bazaar',
    'bajar',
    'shopping list',
    'shopping',
    'market game',
  ];

  static const List<String> _tapTargetEnglish = [
    'tap the target',
    'tap target',
    'target',
    'tap the target game',
    'tap on target',
    'tap game',
    'target game',
  ];

  static const List<String> _patternMatchEnglish = [
    'pattern match',
    'pattern matching',
    'pattern',
    'pair match',
    'pair matching',
    'matching',
    'pair game',
    'match pair',
  ];

  static const List<String> _logoutEnglish = [
    'logout',
    'log out',
    'sign out',
    'signout',
    'exit',
    'quit',
    'unpair',
    'disconnect',
  ];

  // ── Bengali keywords & phrases ───────────────────────────────────────────
  static const List<String> _gameBengali = [
    'খেলা',
    'গেম',
    'গেইম',
    'মগজের খেলা',
    'খেলুন',
    'খেলব',
    'খেলাধুলা',
    'খেলতে চাই',
  ];

  static const List<String> _marketTripBengali = [
    'বাজারের যাত্রা',
    'মার্কেট ট্রিপ',
    'মার্কেট ট্রিপ খেলব',
    'বাজার',
    'মার্কেট',
    'বাজারের খেলা',
    'বাজারের লিস্ট',
    'বাজার ট্রিপ',
  ];

  static const List<String> _tapTargetBengali = [
    'লক্ষ্যে ট্যাপ',
    'লক্ষ্য ট্যাপ',
    'লক্ষ্যে ট্যাপ করুন',
    'লক্ষ্য',
    'টার্গেট',
    'ট্যাপ দ্য টার্গেট',
    'টার্গেটে ট্যাপ',
    'লক্ষ্যে ক্লিক',
  ];

  static const List<String> _patternMatchBengali = [
    'প্যাটার্ন ম্যাচ',
    'প্যাটার্ন মিলান',
    'প্যাটার্ন ম্যাচিং',
    'জোড়া মেলানো',
    'জোড়া মিলান',
    'জোড়া মেলানো',
    'প্যাটার্ন',
    'জোড়া মিল',
    'মিলানো',
  ];

  static const List<String> _logoutBengali = [
    'লগআউট',
    'লগ আউট',
    'লগ-আউট',
    'প্রস্থান',
    'বের হন',
    'লগআউট করুন',
    'লগ আউট করুন',
    'বিদায়',
    'বিদায়',
  ];

  /// Parses an array of speech recognition candidates (ordered by confidence)
  /// and returns the highest matching [VoiceCommandMatch] or null if no command is recognized.
  VoiceCommandMatch? parseCandidates(List<String> candidates) {
    if (candidates.isEmpty) return null;

    for (int i = 0; i < candidates.length; i++) {
      final raw = candidates[i];
      final match = parseSingle(raw);
      if (match != null) {
        // Adjust confidence slightly based on candidate rank
        final adjustedConfidence = (match.confidence * (1.0 - (i * 0.1))).clamp(0.1, 1.0);
        return VoiceCommandMatch(
          command: match.command,
          matchedCandidate: match.matchedCandidate,
          confidence: adjustedConfidence,
          isBengali: match.isBengali,
        );
      }
    }
    return null;
  }

  /// Parses a single speech recognition transcription string.
  VoiceCommandMatch? parseSingle(String input) {
    final clean = _normalize(input);
    if (clean.isEmpty) return null;

    // Check longer/more specific commands first before general ones (e.g. "market trip" before "game")

    // 1. Market Trip
    final mtScore = _matchScore(clean, _marketTripEnglish, _marketTripBengali);
    if (mtScore.confidence > 0.6) {
      return VoiceCommandMatch(
        command: VoiceCommand.marketTrip,
        matchedCandidate: input,
        confidence: mtScore.confidence,
        isBengali: mtScore.isBengali,
      );
    }

    // 2. Tap the Target
    final ttScore = _matchScore(clean, _tapTargetEnglish, _tapTargetBengali);
    if (ttScore.confidence > 0.6) {
      return VoiceCommandMatch(
        command: VoiceCommand.tapTarget,
        matchedCandidate: input,
        confidence: ttScore.confidence,
        isBengali: ttScore.isBengali,
      );
    }

    // 3. Pattern Match
    final pmScore = _matchScore(clean, _patternMatchEnglish, _patternMatchBengali);
    if (pmScore.confidence > 0.6) {
      return VoiceCommandMatch(
        command: VoiceCommand.patternMatch,
        matchedCandidate: input,
        confidence: pmScore.confidence,
        isBengali: pmScore.isBengali,
      );
    }

    // 4. Logout
    final loScore = _matchScore(clean, _logoutEnglish, _logoutBengali);
    if (loScore.confidence > 0.6) {
      return VoiceCommandMatch(
        command: VoiceCommand.logout,
        matchedCandidate: input,
        confidence: loScore.confidence,
        isBengali: loScore.isBengali,
      );
    }

    // 5. Game (checked after specific games to avoid greedy prefix match)
    final gScore = _matchScore(clean, _gameEnglish, _gameBengali);
    if (gScore.confidence > 0.6) {
      return VoiceCommandMatch(
        command: VoiceCommand.game,
        matchedCandidate: input,
        confidence: gScore.confidence,
        isBengali: gScore.isBengali,
      );
    }

    return null;
  }

  /// Normalizes input text: lowercases, removes punctuation and accents.
  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r"""[.,!?\-_:;'"()[\]{}।॥]"""), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  _ScoreResult _matchScore(
    String normalizedInput,
    List<String> englishKeywords,
    List<String> bengaliKeywords,
  ) {
    // 1. Check Bengali matches
    for (final kw in bengaliKeywords) {
      final normKw = _normalize(kw);
      if (normalizedInput == normKw) {
        return const _ScoreResult(1.0, true);
      }
      if (normalizedInput.contains(normKw)) {
        return const _ScoreResult(0.92, true);
      }
    }

    // 2. Check English matches
    for (final kw in englishKeywords) {
      final normKw = _normalize(kw);
      if (normalizedInput == normKw) {
        return const _ScoreResult(1.0, false);
      }
      // Exact word boundary match
      if (RegExp('\\b${RegExp.escape(normKw)}\\b').hasMatch(normalizedInput)) {
        return const _ScoreResult(0.92, false);
      }
      if (normalizedInput.contains(normKw)) {
        return const _ScoreResult(0.85, false);
      }
    }

    return const _ScoreResult(0.0, false);
  }
}

class _ScoreResult {
  final double confidence;
  final bool isBengali;
  const _ScoreResult(this.confidence, this.isBengali);
}
