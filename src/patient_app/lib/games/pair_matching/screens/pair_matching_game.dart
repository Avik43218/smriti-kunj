import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../theme/theme.dart';
import '../../../games/shared/models/round_telemetry.dart';
import '../../../games/shared/services/game_session_repository.dart';
import '../../../services/difficulty_service.dart';
import '../../../services/difficulty_database_service.dart';
import '../models/game_session_result.dart';
import '../models/pair_card.dart';
import '../services/pair_bank_service.dart';

enum _GamePhase { loading, playing, summary }

/// Card state for animation and interaction.
class _CardDisplayState {
  final PairCard card;
  bool isFaceUp = false;
  bool isMatched = false;

  _CardDisplayState({
    required this.card,
  });
}


/// Pair Matching Game Screen (Episodic Memory).
class PairMatchingGameScreen extends StatefulWidget {
  final PairDifficulty difficulty;
  final String promptLanguage;
  final String patientProfileId;
  final void Function(PairMatchingSessionResult result)? onGameCompleted;

  const PairMatchingGameScreen({
    super.key,
    this.difficulty = PairDifficulty.easy,
    this.promptLanguage = 'en',
    this.patientProfileId = 'patient_001',
    this.onGameCompleted,
  });

  @override
  State<PairMatchingGameScreen> createState() => _PairMatchingGameScreenState();
}

class _PairMatchingGameScreenState extends State<PairMatchingGameScreen> {
  final PairBankService _bankService = PairBankService();

  _GamePhase _phase = _GamePhase.loading;
  List<_CardDisplayState> _deck = [];
  bool _usedFaceNameVariant = false;

  // Selection tracking
  int? _firstFlippedIndex;
  int? _secondFlippedIndex;
  bool _isProcessingMismatch = false;

  // Analytics tracking
  late DateTime _sessionStart;
  final GameTelemetryTracker _telemetryTracker =
      GameTelemetryTracker(hesitationThresholdMs: 2500.0, errorBurstThreshold: 2);
  DateTime? _turnStartTime;
  DateTime? _firstFlipTime;
  int _totalFlips = 0;
  int _matchAttempts = 0;
  int _matchedPairs = 0;
  DateTime? _firstCorrectMatchAt;
  final Map<String, int> _pairMissCounts = {}; // pairId -> miss count
  final List<Map<String, dynamic>> _rawTrials = [];

  PairMatchingSessionResult? _result;

  // ── Localisation helpers ──────────────────────────────────────────────────
  bool get _isAs => widget.promptLanguage == 'as';

  String get _appBarTitle => _isAs ? "যোৰ মিলোৱা" : "Pair Matching";
  String get _instruction =>
      _isAs ? "মিলন যোৰ বিচাৰিবলৈ কাৰ্ডবোৰ ওলোটাওক" : "Flip cards to find matching pairs";
  String get _pairsFoundLabel => _isAs ? "মিলিত যোৰ:" : "Pairs found:";
  String get _summaryHeading => _isAs ? "খেল সম্পূৰ্ণ!" : "Session Complete!";
  String get _flipsSummaryLabel => _isAs ? "মুঠ ওলোটোৱা:" : "Total flips:";
  String get _accuracyLabel => _isAs ? "শুদ্ধতা:" : "Accuracy:";
  late PairDifficulty _activeDifficulty;

  String get _repeatErrorsLabel => _isAs ? "পুনৰাবৃত্তিমূলক ভুল:" : "Repeat errors:";
  String get _doneButton => _isAs ? "সম্পূৰ্ণ হ'ল" : "Done";

  @override
  void initState() {
    super.initState();
    _activeDifficulty = widget.difficulty;
    _initGame();
  }

  Future<void> _initGame() async {
    setState(() => _phase = _GamePhase.loading);
    _sessionStart = DateTime.now();
    _totalFlips = 0;
    _matchAttempts = 0;
    _matchedPairs = 0;
    _firstCorrectMatchAt = null;
    _pairMissCounts.clear();
    _rawTrials.clear();
    _firstFlippedIndex = null;
    _secondFlippedIndex = null;
    _isProcessingMismatch = false;
    _result = null;

    // Check if next-game difficulty was queued in SQLite
    final pending = await DifficultyDatabaseService.instance
        .consumeLatestDifficultySetting(gameType: 'pair_matching');
    if (pending != null) {
      final level = pending.recommendedDifficulty;
      if (level == 1) _activeDifficulty = PairDifficulty.easy;
      if (level == 2) _activeDifficulty = PairDifficulty.medium;
      if (level == 3) _activeDifficulty = PairDifficulty.hard;
      debugPrint('[PairMatching] Applied and removed difficulty from SQLite: level $level');
    }

    final deckResult = await _bankService.loadDeck(
      patientProfileId: widget.patientProfileId,
      difficulty: _activeDifficulty,
    );

    if (!mounted) return;

    setState(() {
      _deck = deckResult.cards
          .map((c) => _CardDisplayState(card: c))
          .toList();
      _usedFaceNameVariant = deckResult.usedFaceNameVariant;
      _phase = _GamePhase.playing;
      _turnStartTime = DateTime.now();
      _firstFlipTime = null;
    });
  }

  void _onCardTapped(int index) {
    if (_phase != _GamePhase.playing) return;
    if (_isProcessingMismatch) return;

    final cardState = _deck[index];
    if (cardState.isMatched || cardState.isFaceUp) return;

    setState(() {
      cardState.isFaceUp = true;
      _totalFlips++;
    });

    _rawTrials.add({
      'event': 'flip',
      'card_id': cardState.card.id,
      'pair_id': cardState.card.pairId,
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (_firstFlippedIndex == null) {
      // First card of the turn
      _firstFlippedIndex = index;
      _firstFlipTime = DateTime.now();
    } else {
      // Second card of the turn
      _secondFlippedIndex = index;
      _matchAttempts++;
      _evaluateTurn();
    }
  }

  void _evaluateTurn() {
    final firstIdx = _firstFlippedIndex!;
    final secondIdx = _secondFlippedIndex!;
    final firstCard = _deck[firstIdx].card;
    final secondCard = _deck[secondIdx].card;

    final isMatch = firstCard.pairId == secondCard.pairId;
    final secondFlipTime = DateTime.now();
    final turnStart = _turnStartTime ?? _firstFlipTime ?? secondFlipTime;
    final turnLatencyMs =
        secondFlipTime.difference(turnStart).inMilliseconds.toDouble();
    final firstFlipHesitationMs = _firstFlipTime != null
        ? _firstFlipTime!.difference(turnStart).inMilliseconds.toDouble()
        : 0.0;

    _telemetryTracker.recordRound(
      latencyMs: turnLatencyMs,
      isCorrect: isMatch,
      eventType: 'match_attempt',
      rawHesitationMs: firstFlipHesitationMs > 2000.0
          ? (firstFlipHesitationMs - 2000.0)
          : 0.0,
      metadata: {
        'card_a': firstCard.id,
        'card_b': secondCard.id,
        'pair_id_a': firstCard.pairId,
        'pair_id_b': secondCard.pairId,
        'is_match': isMatch,
      },
    );

    _rawTrials.add({
      'event': 'match_attempt',
      'card_a': firstCard.id,
      'card_b': secondCard.id,
      'pair_id_a': firstCard.pairId,
      'pair_id_b': secondCard.pairId,
      'is_match': isMatch,
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (isMatch) {
      // Correct Match
      _firstCorrectMatchAt ??= DateTime.now();

      setState(() {
        _deck[firstIdx].isMatched = true;
        _deck[secondIdx].isMatched = true;
        _matchedPairs++;
        _firstFlippedIndex = null;
        _secondFlippedIndex = null;
        _turnStartTime = DateTime.now();
        _firstFlipTime = null;
      });

      if (_matchedPairs >= widget.difficulty.pairCount) {
        _completeGame();
      }
    } else {
      // Mismatch
      _pairMissCounts[firstCard.pairId] =
          (_pairMissCounts[firstCard.pairId] ?? 0) + 1;
      _pairMissCounts[secondCard.pairId] =
          (_pairMissCounts[secondCard.pairId] ?? 0) + 1;

      _isProcessingMismatch = true;
      Timer(const Duration(milliseconds: 1100), () {
        if (!mounted) return;
        setState(() {
          _deck[firstIdx].isFaceUp = false;
          _deck[secondIdx].isFaceUp = false;
          _firstFlippedIndex = null;
          _secondFlippedIndex = null;
          _isProcessingMismatch = false;
          _turnStartTime = DateTime.now();
          _firstFlipTime = null;
        });
      });
    }
  }

  void _completeGame() {
    final now = DateTime.now();
    final durationSeconds =
        now.difference(_sessionStart).inMilliseconds / 1000.0;

    final correctMatchRate = _matchAttempts > 0
        ? (_activeDifficulty.pairCount / _matchAttempts).clamp(0.0, 1.0)
        : 1.0;

    final timeToFirst = _firstCorrectMatchAt != null
        ? _firstCorrectMatchAt!.difference(_sessionStart).inMilliseconds /
            1000.0
        : durationSeconds;

    // Repeat error = pairs missed 2+ times across the session
    final repeatErrorPairsCount = _pairMissCounts.values
        .where((missCount) => missCount >= 2)
        .length;
    final repeatErrorRate = _activeDifficulty.pairCount > 0
        ? (repeatErrorPairsCount / _activeDifficulty.pairCount).clamp(0.0, 1.0)
        : 0.0;

    // Normalized score calculation
    final minFlips = _activeDifficulty.pairCount * 2;
    final flipEfficiency = _totalFlips > 0
        ? (minFlips / _totalFlips).clamp(0.0, 1.0)
        : 1.0;
    final scoreNormalized =
        ((correctMatchRate * 0.7) + (flipEfficiency * 0.3)).clamp(0.1, 1.0);

    final result = PairMatchingSessionResult(
      totalFlips: _totalFlips,
      correctMatchRate: correctMatchRate,
      timeToFirstCorrectMatch: timeToFirst,
      repeatErrorRate: repeatErrorRate,
      completionTime: durationSeconds,
      pairsCount: _activeDifficulty.pairCount,
      usedFaceNameVariant: _usedFaceNameVariant,
      sessionId: 'pm_${DateTime.now().millisecondsSinceEpoch}',
      patientProfileId: widget.patientProfileId,
      sessionDate: _sessionStart,
      sessionDuration: durationSeconds,
      status: 'completed',
      difficultyLevel: _activeDifficulty.level,
      scoreNormalized: scoreNormalized,
      rawTrials: _rawTrials,
    );

    setState(() {
      _result = result;
      _phase = _GamePhase.summary;
    });

    final telemetrySummary = _telemetryTracker.computeSummary();

    // Persist session to local storage for later sync to backend.
    unawaited(GameSessionRepository.instance.saveSession(StoredGameSession(
      sessionId: result.sessionId,
      patientProfileId: result.patientProfileId,
      gameType: result.gameType,
      domain: result.domain,
      sessionDate: result.sessionDate,
      sessionDuration: result.sessionDuration,
      status: result.status,
      difficultyLevel: result.difficultyLevel,
      scoreNormalized: result.scoreNormalized,
      gameData: {
        'total_flips': result.totalFlips,
        'correct_match_rate': result.correctMatchRate,
        'time_to_first_correct_match': result.timeToFirstCorrectMatch,
        'repeat_error_rate': result.repeatErrorRate,
        'completion_time': result.completionTime,
        'pairs_count': result.pairsCount,
        'used_face_name_variant': result.usedFaceNameVariant,
        'telemetry': telemetrySummary.toJson(),
      },
      rawTrials: telemetrySummary.rounds.map((r) => r.toJson()).toList(),
      createdAt: now,
    )));

    // Spin up TFLite model on raw telemetry JSON and save decision to SQLite database
    final rawTelemetryJson = jsonEncode({
      'game_type': result.gameType,
      'total_flips': result.totalFlips,
      'correct_match_rate': result.correctMatchRate,
      'time_to_first_correct_match': result.timeToFirstCorrectMatch,
      'repeat_error_rate': result.repeatErrorRate,
      'completion_time': result.completionTime,
      'pairs_count': result.pairsCount,
      'score_normalized': result.scoreNormalized,
      'telemetry': telemetrySummary.toJson(),
    });

    unawaited(() async {
      try {
        final decision = await DynamicDifficultyService.instance.evaluateSessionJson(
          rawTelemetryJson,
          currentDifficulty: _activeDifficulty.level,
          gameType: 'pair_matching',
        );
        await DifficultyDatabaseService.instance.saveDifficultySettingsForAllGames(
          decision,
          rawJson: rawTelemetryJson,
        );
      } catch (e) {
        debugPrint('[PairMatching] Error running TFLite difficulty model: $e');
      }
    }());

    widget.onGameCompleted?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              size: 32, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _appBarTitle,
          style:
              textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: switch (_phase) {
          _GamePhase.loading => const Center(
              child: CircularProgressIndicator(
                color: AppColors.mugaGold,
                strokeWidth: 3.5,
              ),
            ),
          _GamePhase.playing => _buildGameBoard(),
          _GamePhase.summary => _buildSummary(),
        },
      ),
    );
  }

  // ── Game Board ─────────────────────────────────────────────────────────────
  Widget _buildGameBoard() {
    final progress = _activeDifficulty.pairCount > 0
        ? _matchedPairs / _activeDifficulty.pairCount
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header / Instructions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _instruction,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.mugaGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.mugaGold.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '$_pairsFoundLabel $_matchedPairs/${_activeDifficulty.pairCount}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.terracottaDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.mugaGold),
            ),
          ),
          const SizedBox(height: 14),

          // Cards Grid
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: _deck.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _activeDifficulty.gridColumns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (context, index) {
                final itemState = _deck[index];
                return _CardTile(
                  state: itemState,
                  languageCode: widget.promptLanguage,
                  onTap: () => _onCardTapped(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary Screen ─────────────────────────────────────────────────────────
  Widget _buildSummary() {
    final r = _result;
    if (r == null) return const SizedBox.shrink();

    final pct = (r.scoreNormalized * 100).round();
    final accPct = (r.correctMatchRate * 100).round();
    final repeatPct = (r.repeatErrorRate * 100).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.mugaGold, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.stars_rounded,
                    size: 64, color: AppColors.mugaGold),
                const SizedBox(height: 16),
                Text(
                  _summaryHeading,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  '$pct%',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mugaGold,
                  ),
                ),
                const SizedBox(height: 24),
                _StatRow(
                  label: _flipsSummaryLabel,
                  value: '${r.totalFlips}',
                ),
                const Divider(height: 20, color: AppColors.border),
                _StatRow(
                  label: _accuracyLabel,
                  value: '$accPct%',
                ),
                const Divider(height: 20, color: AppColors.border),
                _StatRow(
                  label: _repeatErrorsLabel,
                  value: '$repeatPct%',
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mugaGold,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 88),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              _doneButton,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Interactive Card Tile Widget
// ─────────────────────────────────────────────────────────────────────────────
class _CardTile extends StatelessWidget {
  final _CardDisplayState state;
  final String languageCode;
  final VoidCallback onTap;

  const _CardTile({
    required this.state,
    required this.languageCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: state.isFaceUp || state.isMatched
              ? AppColors.surface
              : AppColors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: state.isMatched
                ? AppColors.sageGreen
                : state.isFaceUp
                    ? AppColors.mugaGold
                    : AppColors.border,
            width: state.isMatched ? 3.0 : (state.isFaceUp ? 2.5 : 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: state.isFaceUp || state.isMatched
            ? _buildFaceContent()
            : _buildBackContent(),
      ),
    );
  }

  Widget _buildFaceContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (state.isMatched)
            const Align(
              alignment: Alignment.topRight,
              child: Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: AppColors.sageGreen,
              ),
            ),
          Expanded(
            child: Center(
              child: state.card.isPhoto && state.card.imagePath != null
                  ? Image.asset(
                      state.card.imagePath!,
                      fit: BoxFit.contain,
                    )
                  : Icon(
                      state.card.iconData,
                      size: 40,
                      color: state.isMatched
                          ? AppColors.sageGreen
                          : AppColors.mugaGold,
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.card.getName(languageCode),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: state.isMatched ? AppColors.sageGreen : AppColors.ink,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBackContent() {
    return Center(
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.mugaGold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.mugaGold.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: const Icon(
          Icons.help_outline_rounded,
          size: 26,
          color: AppColors.mugaGold,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary Stat Row
// ─────────────────────────────────────────────────────────────────────────────
class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 18, color: AppColors.inkSoft),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}
