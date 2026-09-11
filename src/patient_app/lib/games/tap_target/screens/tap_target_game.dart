import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../services/app_strings.dart';
import '../../../services/locale_service.dart';
import '../../../theme/theme.dart';
import '../../../games/shared/models/round_telemetry.dart';
import '../../../games/shared/models/completion_message.dart';
import '../../../games/shared/services/game_session_repository.dart';
import '../../../services/difficulty_service.dart';
import '../../../services/difficulty_database_service.dart';
import '../models/game_session_result.dart';
import '../models/target_config.dart';
import '../services/target_bank_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Game phase enum
// ─────────────────────────────────────────────────────────────────────────────
enum _GamePhase { loading, intro, playing, summary }

// ─────────────────────────────────────────────────────────────────────────────
// Main widget
// ─────────────────────────────────────────────────────────────────────────────
class TapTargetGameScreen extends StatefulWidget {
  final TapDifficulty difficulty;
  final String promptLanguage;
  final String patientProfileId;

  /// Optional initial target. If null, a random target from the bank is picked.
  final TargetConfig? initialTarget;

  final void Function(TapTargetSessionResult result)? onGameCompleted;

  const TapTargetGameScreen({
    super.key,
    this.difficulty = TapDifficulty.easy,
    this.promptLanguage = 'en',
    this.patientProfileId = 'patient_001',
    this.initialTarget,
    this.onGameCompleted,
  });

  @override
  State<TapTargetGameScreen> createState() => _TapTargetGameScreenState();
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-trial raw event record
// ─────────────────────────────────────────────────────────────────────────────
class _TapEvent {
  final int trialIndex;
  final String cardItemId;
  final String? tappedItemId;
  final bool isTargetCard;
  final bool wasTapped;
  final int? reactionTimeMs;
  final String eventType; // "target_hit" | "omission" | "false_positive" | "correct_rejection"
  final DateTime timestamp;

  const _TapEvent({
    required this.trialIndex,
    required this.cardItemId,
    this.tappedItemId,
    required this.isTargetCard,
    required this.wasTapped,
    this.reactionTimeMs,
    required this.eventType,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'trial_index': trialIndex,
        'card_item_id': cardItemId,
        'is_target_card': isTargetCard,
        'was_tapped': wasTapped,
        'tapped_item_id': tappedItemId,
        'reaction_time_ms': reactionTimeMs,
        'event_type': eventType,
        'timestamp': timestamp.toIso8601String(),
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────
class _TapTargetGameScreenState extends State<TapTargetGameScreen>
    with SingleTickerProviderStateMixin {
  final TargetBankService _bankService = TargetBankService();
  final Random _random = Random();

  _GamePhase _phase = _GamePhase.loading;
  List<TargetConfig> _bank = [];
  late TargetConfig _target;
  late TapDifficulty _activeDifficulty;

  // Single-card cycling sequence
  List<TargetConfig> _cardSequence = [];
  int _currentCardIndex = 0;
  DateTime? _cardAppearedAt;
  bool _cardTapped = false;
  int? _cardReactionTimeMs;
  Timer? _cycleTimer;

  // Analytics
  late DateTime _sessionStart;
  final List<_TapEvent> _tapEvents = [];
  GameTelemetryTracker _telemetryTracker =
      GameTelemetryTracker(hesitationThresholdMs: 1800.0, errorBurstThreshold: 2);
  int _omissions = 0; // target presentations where patient did not tap
  int _totalTaps = 0; // total taps made
  int _falseTaps = 0; // taps made during non-target cards

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  TapTargetSessionResult? _result;
  CompletionMessage _completionMessage = CompletionMessage.getRandom();

  // ── Localisation helpers ──────────────────────────────────────────────────
  AppStrings get _s => AppStrings(AppLangExt.fromCode(widget.promptLanguage));

  String get _appBarTitle => _s.gameAppBarTapTarget;

  String get _introHeading => _s.tapTargetIntroHeading;

  String get _introInstruction => _s.tapTargetIntroInstruction;

  String get _startButton => _s.tapTargetStartButton;

  String get _playInstruction => _s.tapTargetPlayInstruction;

  String get _summaryHeading =>
      _completionMessage.heading(widget.promptLanguage);

  String get _summarySubheading =>
      _completionMessage.subheading(widget.promptLanguage);

  String get _playAgainButton => _s.playAgain;

  String get _doneButton => _s.done;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _activeDifficulty = widget.difficulty;
    _sessionStart = DateTime.now();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initGame();
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _initGame() async {
    _cycleTimer?.cancel();
    _completionMessage = CompletionMessage.getRandom();
    _sessionStart = DateTime.now();
    _tapEvents.clear();
    _telemetryTracker =
        GameTelemetryTracker(hesitationThresholdMs: 1800.0, errorBurstThreshold: 2);
    _omissions = 0;
    _totalTaps = 0;
    _falseTaps = 0;
    _cardTapped = false;
    _cardReactionTimeMs = null;
    _currentCardIndex = 0;
    _result = null;

    // Check if next-game difficulty was queued in SQLite
    final pending = await DifficultyDatabaseService.instance
        .consumeLatestDifficultySetting(gameType: 'tap_target');
    if (pending != null) {
      final level = pending.recommendedDifficulty;
      if (level == 1) _activeDifficulty = TapDifficulty.easy;
      if (level == 2) _activeDifficulty = TapDifficulty.medium;
      if (level == 3) _activeDifficulty = TapDifficulty.hard;
      debugPrint('[TapTarget] Applied difficulty from SQLite: level $level');
    }

    final bank = await _bankService.loadTargetBank();
    if (!mounted) return;

    final target = widget.initialTarget ??
        bank[_random.nextInt(bank.length)];

    setState(() {
      _bank = bank;
      _target = target;
      _phase = _GamePhase.intro;
    });
  }

  void _startSession() {
    _sessionStart = DateTime.now();
    _tapEvents.clear();
    _omissions = 0;
    _totalTaps = 0;
    _falseTaps = 0;

    // Generate single-card cycle sequence according to difficulty
    _cardSequence = _bankService.generateCardSequence(
      bank: _bank,
      target: _target,
      difficulty: _activeDifficulty,
    );

    setState(() {
      _phase = _GamePhase.playing;
    });

    _showCardAtIndex(0);
  }

  // ── Single-card cycling loop ──────────────────────────────────────────────

  void _showCardAtIndex(int index) {
    if (index >= _cardSequence.length) {
      _finishSession();
      return;
    }

    _cycleTimer?.cancel();

    setState(() {
      _currentCardIndex = index;
      _cardTapped = false;
      _cardReactionTimeMs = null;
      _cardAppearedAt = DateTime.now();
    });

    final intervalMs =
        (_activeDifficulty.appearanceIntervalSeconds * 1000).round();

    _cycleTimer = Timer(Duration(milliseconds: intervalMs), _onCardIntervalExpired);
  }

  void _onCardTapped() {
    if (_phase != _GamePhase.playing || _currentCardIndex >= _cardSequence.length) {
      return;
    }

    // Debounce repeated taps during the same card presentation window
    if (_cardTapped) return;

    final item = _cardSequence[_currentCardIndex];
    final isTarget = item.id == _target.id;
    final rt = _cardAppearedAt != null
        ? DateTime.now().difference(_cardAppearedAt!).inMilliseconds
        : 0;

    setState(() {
      _cardTapped = true;
      _cardReactionTimeMs = rt;
      _totalTaps++;
      if (!isTarget) {
        _falseTaps++;
      }
    });

    if (isTarget) {
      _telemetryTracker.recordRound(
        latencyMs: rt.toDouble(),
        isCorrect: true,
        eventType: 'target_hit',
        metadata: {
          'trial_index': _currentCardIndex,
          'card_item_id': item.id,
          'target_id': _target.id,
        },
      );
    } else {
      _telemetryTracker.recordRound(
        latencyMs: rt.toDouble(),
        isCorrect: false,
        eventType: 'false_positive',
        metadata: {
          'trial_index': _currentCardIndex,
          'card_item_id': item.id,
          'target_id': _target.id,
        },
      );
    }
  }

  void _onCardIntervalExpired() {
    if (!mounted || _phase != _GamePhase.playing || _currentCardIndex >= _cardSequence.length) {
      return;
    }

    final item = _cardSequence[_currentCardIndex];
    final isTarget = item.id == _target.id;

    if (isTarget) {
      if (_cardTapped) {
        // Correct target hit
        _tapEvents.add(_TapEvent(
          trialIndex: _currentCardIndex,
          cardItemId: item.id,
          tappedItemId: item.id,
          isTargetCard: true,
          wasTapped: true,
          reactionTimeMs: _cardReactionTimeMs,
          eventType: 'target_hit',
          timestamp: DateTime.now(),
        ));
      } else {
        // Target was displayed but never tapped before next card arrived -> Omission
        _omissions++;
        _tapEvents.add(_TapEvent(
          trialIndex: _currentCardIndex,
          cardItemId: item.id,
          tappedItemId: null,
          isTargetCard: true,
          wasTapped: false,
          reactionTimeMs: null, // null for omissions per requirement
          eventType: 'omission',
          timestamp: DateTime.now(),
        ));

        _telemetryTracker.recordRound(
          latencyMs: (_activeDifficulty.appearanceIntervalSeconds * 1000).toDouble(),
          isCorrect: false,
          eventType: 'omission',
          metadata: {
            'trial_index': _currentCardIndex,
            'card_item_id': item.id,
            'target_id': _target.id,
          },
        );
      }
    } else {
      if (_cardTapped) {
        // Non-target was tapped -> False positive
        _tapEvents.add(_TapEvent(
          trialIndex: _currentCardIndex,
          cardItemId: item.id,
          tappedItemId: item.id,
          isTargetCard: false,
          wasTapped: true,
          reactionTimeMs: _cardReactionTimeMs,
          eventType: 'false_positive',
          timestamp: DateTime.now(),
        ));
      } else {
        // Distractor ignored -> Correct rejection
        _tapEvents.add(_TapEvent(
          trialIndex: _currentCardIndex,
          cardItemId: item.id,
          tappedItemId: null,
          isTargetCard: false,
          wasTapped: false,
          reactionTimeMs: null, // null for correct rejection
          eventType: 'correct_rejection',
          timestamp: DateTime.now(),
        ));

        _telemetryTracker.recordRound(
          latencyMs: 0.0,
          isCorrect: true,
          eventType: 'correct_rejection',
          metadata: {
            'trial_index': _currentCardIndex,
            'card_item_id': item.id,
            'target_id': _target.id,
          },
        );
      }
    }

    _showCardAtIndex(_currentCardIndex + 1);
  }

  // ── Analytics computation ─────────────────────────────────────────────────
  void _finishSession() {
    _cycleTimer?.cancel();

    final sessionDuration =
        DateTime.now().difference(_sessionStart).inMilliseconds / 1000.0;

    // Reaction times for correct target hits only
    final correctHits = _tapEvents
        .where((e) => e.eventType == 'target_hit' && e.reactionTimeMs != null)
        .toList();

    double rtAvg = 0;
    double rtStdDev = 0;

    if (correctHits.isNotEmpty) {
      final rts =
          correctHits.map((e) => e.reactionTimeMs!.toDouble()).toList();
      rtAvg = rts.reduce((a, b) => a + b) / rts.length;
      if (rts.length > 1) {
        final variance = rts
                .map((t) => pow(t - rtAvg, 2))
                .reduce((a, b) => a + b) /
            rts.length;
        rtStdDev = sqrt(variance);
      }
    }

    final totalCards = _cardSequence.length;
    final targetTrials = _tapEvents.where((e) => e.isTargetCard).toList();
    final totalTargets = targetTrials.length;

    final omissionRate =
        totalTargets > 0 ? (_omissions / totalTargets).clamp(0.0, 1.0) : 0.0;
    final falsePositiveRate =
        _totalTaps > 0 ? (_falseTaps / _totalTaps).clamp(0.0, 1.0) : 0.0;

    // Within-session drift: compare accuracy across first-half vs second-half cards
    final half = totalCards ~/ 2;
    final earlyTrials =
        _tapEvents.where((e) => e.trialIndex < half).toList();
    final lateTrials =
        _tapEvents.where((e) => e.trialIndex >= half).toList();

    int countCorrect(List<_TapEvent> list) {
      return list.where((e) {
        if (e.isTargetCard) return e.wasTapped; // target hit
        return !e.wasTapped; // correct rejection
      }).length;
    }

    final double earlyRate = earlyTrials.isEmpty
        ? 0.0
        : countCorrect(earlyTrials) / earlyTrials.length;
    final double lateRate = lateTrials.isEmpty
        ? 0.0
        : countCorrect(lateTrials) / lateTrials.length;
    final withinSessionDrift = lateRate - earlyRate; // negative = fatigue / drift

    // Normalised score: hit rate - penalty for false positives
    final hitRate = totalTargets > 0
        ? ((totalTargets - _omissions) / totalTargets).clamp(0.0, 1.0)
        : 0.0;
    final score =
        (hitRate - (falsePositiveRate * 0.5)).clamp(0.0, 1.0);

    final result = TapTargetSessionResult(
      reactionTimeAvg: rtAvg,
      reactionTimeVariability: rtStdDev,
      omissionRate: omissionRate,
      falsePositiveRate: falsePositiveRate,
      withinSessionDrift: withinSessionDrift,
      trialCount: totalCards,
      targetItemType: _target.id,
      sessionId: 'tt_${DateTime.now().millisecondsSinceEpoch}',
      patientProfileId: widget.patientProfileId,
      sessionDate: DateTime.now(),
      sessionDuration: sessionDuration,
      status: 'completed',
      difficultyLevel: _activeDifficulty.level,
      scoreNormalized: score,
      rawTrials: _tapEvents.map((e) => e.toJson()).toList(),
    );

    setState(() {
      _result = result;
      _phase = _GamePhase.summary;
    });

    final telemetrySummary = _telemetryTracker.computeSummary();

    // Persist session to local storage for later sync to backend
    final now = DateTime.now();
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
        'reaction_time_avg': result.reactionTimeAvg,
        'reaction_time_variability': result.reactionTimeVariability,
        'omission_rate': result.omissionRate,
        'false_positive_rate': result.falsePositiveRate,
        'within_session_drift': result.withinSessionDrift,
        'trial_count': result.trialCount,
        'target_item_type': result.targetItemType,
        'telemetry': telemetrySummary.toJson(),
      },
      rawTrials: telemetrySummary.rounds.map((r) => r.toJson()).toList(),
      createdAt: now,
    )));

    // Dynamic difficulty evaluation
    final rawTelemetryJson = jsonEncode({
      'game_type': result.gameType,
      'reaction_time_avg': result.reactionTimeAvg,
      'reaction_time_variability': result.reactionTimeVariability,
      'omission_rate': result.omissionRate,
      'false_positive_rate': result.falsePositiveRate,
      'within_session_drift': result.withinSessionDrift,
      'trial_count': result.trialCount,
      'score_normalized': result.scoreNormalized,
      'telemetry': telemetrySummary.toJson(),
    });

    unawaited(() async {
      try {
        final decision = await DynamicDifficultyService.instance.evaluateSessionJson(
          rawTelemetryJson,
          currentDifficulty: _activeDifficulty.level,
          gameType: 'tap_target',
        );
        await DifficultyDatabaseService.instance.saveDifficultySettingsForAllGames(
          decision,
          rawJson: rawTelemetryJson,
        );
      } catch (e) {
        debugPrint('[TapTarget] Error running TFLite difficulty model: $e');
      }
    }());

    widget.onGameCompleted?.call(result);
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _appBarTitle,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.ink,
          ),
        ),
      ),
      body: SafeArea(child: _buildPhase()),
    );
  }

  Widget _buildPhase() {
    return switch (_phase) {
      _GamePhase.loading => const Center(
          child: CircularProgressIndicator(color: AppColors.terracotta),
        ),
      _GamePhase.intro => _buildIntro(),
      _GamePhase.playing => _buildPlayArea(),
      _GamePhase.summary => _buildSummary(),
    };
  }

  // ── Intro ─────────────────────────────────────────────────────────────────
  Widget _buildIntro() {
    final targetName = _target.getName(widget.promptLanguage);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: Column(
              children: [
                Text(
                  _introHeading,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 20),
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: AppColors.terracotta.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(24),
                      border:
                          Border.all(color: AppColors.terracotta, width: 3.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _target.iconData,
                          size: 64,
                          color: AppColors.terracotta,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          targetName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _introInstruction,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppColors.inkSoft,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          ElevatedButton.icon(
            onPressed: _startSession,
            icon: const Icon(Icons.play_arrow_rounded, size: 30),
            label: Text(
              _startButton,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.terracotta,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 88),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Play area (Single-card cycling) ───────────────────────────────────────
  Widget _buildPlayArea() {
    final totalCards = _cardSequence.length;
    final progress = totalCards > 0 ? (_currentCardIndex + 1) / totalCards : 0.0;
    final currentCard = _currentCardIndex < _cardSequence.length
        ? _cardSequence[_currentCardIndex]
        : null;

    final targetName = _target.getName(widget.promptLanguage);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 16),

          // Target reminder header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_target.iconData, size: 24, color: AppColors.terracotta),
                const SizedBox(width: 8),
                Text(
                  _s.tapTargetLabel(targetName),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Center(
            child: Text(
              _playInstruction,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.inkSoft,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Central Single Cycling Card
          Expanded(
            child: Center(
              child: currentCard == null
                  ? const SizedBox.shrink()
                  : _SingleCyclingCard(
                      key: ValueKey('card_${_currentCardIndex}_${currentCard.id}'),
                      item: currentCard,
                      languageCode: widget.promptLanguage,
                      wasTapped: _cardTapped,
                      onTap: _onCardTapped,
                    ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Summary ───────────────────────────────────────────────────────────────
  Widget _buildSummary() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                const Icon(
                  Icons.stars_rounded,
                  size: 72,
                  color: AppColors.mugaGold,
                ),
                const SizedBox(height: 20),
                Text(
                  _summaryHeading,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _summarySubheading,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () => _initGame(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.terracotta,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 88),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 2,
            ),
            child: Text(
              _playAgainButton,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).maybePop(_result),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.border, width: 2),
              minimumSize: const Size(double.infinity, 88),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: Text(
              _doneButton,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single cycling card widget
// ─────────────────────────────────────────────────────────────────────────────
class _SingleCyclingCard extends StatelessWidget {
  final TargetConfig item;
  final String languageCode;
  final bool wasTapped;
  final VoidCallback onTap;

  const _SingleCyclingCard({
    super.key,
    required this.item,
    required this.languageCode,
    required this.wasTapped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: item.getName(languageCode),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          splashColor: AppColors.terracotta.withValues(alpha: 0.15),
          highlightColor: AppColors.terracotta.withValues(alpha: 0.08),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 250,
            height: 270,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: wasTapped ? AppColors.mugaGold : AppColors.border,
                width: wasTapped ? 3.5 : 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: wasTapped
                      ? AppColors.mugaGold.withValues(alpha: 0.25)
                      : AppColors.ink.withValues(alpha: 0.08),
                  blurRadius: wasTapped ? 16 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.iconData,
                  size: 88,
                  color: wasTapped
                      ? AppColors.terracottaDark
                      : AppColors.terracotta,
                ),
                const SizedBox(height: 18),
                Text(
                  item.getName(languageCode),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                if (wasTapped) ...[
                  const SizedBox(height: 10),
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 24,
                    color: AppColors.mugaGold,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}



