import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../theme/theme.dart';
import '../../../games/shared/models/round_telemetry.dart';
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
  final String tappedItemId;
  final bool isCorrectTarget;
  final int reactionTimeMs; // ms from target appearance to tap
  final DateTime timestamp;

  const _TapEvent({
    required this.trialIndex,
    required this.tappedItemId,
    required this.isCorrectTarget,
    required this.reactionTimeMs,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'trial_index': trialIndex,
        'tapped_item_id': tappedItemId,
        'is_correct_target': isCorrectTarget,
        'reaction_time_ms': reactionTimeMs,
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
  List<TargetConfig> _currentGrid = []; // target + distractors for this trial
  int _targetGridIndex = -1; // position of target card in current grid

  // Trial tracking
  int _currentTrial = 0;
  bool _targetVisible = false; // true when target is in the grid
  bool _waitingForTarget = false; // distractor-only interlude
  DateTime? _targetAppearedAt;
  bool _trialAnswered = false; // prevent double-tap scoring

  // Analytics
  late DateTime _sessionStart;
  final List<_TapEvent> _tapEvents = [];
  final GameTelemetryTracker _telemetryTracker =
      GameTelemetryTracker(hesitationThresholdMs: 1800.0, errorBurstThreshold: 2);
  int _omissions = 0; // trials where target appeared but wasn't tapped in time
  int _totalTaps = 0;
  int _falseTaps = 0; // taps on distractors

  Timer? _trialTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  TapTargetSessionResult? _result;

  // ── Localisation helpers ──────────────────────────────────────────────────
  bool get _isAs => widget.promptLanguage == 'as';

  String get _appBarTitle =>
      _isAs ? 'লক্ষ্যত টেপ কৰক' : 'Tap the Target';

  String get _introHeading =>
      _isAs ? 'আপোনাৰ লক্ষ্য:' : 'Your target:';

  String get _introInstruction =>
      _isAs
          ? 'এই বস্তুটো দেখা পালে সোনকালে টেপ কৰক।'
          : 'Tap this item as soon as you see it appear.';

  String get _startButton =>
      _isAs ? 'আৰম্ভ কৰক' : 'Start';

  String get _waitText =>
      _isAs ? 'মনোযোগ ৰাখক...' : 'Stay focused...';

  String get _summaryHeading =>
      _isAs ? 'খেল সম্পূৰ্ণ!' : 'Session Complete!';

  late TapDifficulty _activeDifficulty;

  String get _doneButton =>
      _isAs ? "সম্পূৰ্ণ হ'ল" : 'Done';

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
    _trialTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _initGame() async {
    // Check if next-game difficulty was queued in SQLite
    final pending = await DifficultyDatabaseService.instance
        .consumeLatestDifficultySetting(gameType: 'tap_target');
    if (pending != null) {
      final level = pending.recommendedDifficulty;
      if (level == 1) _activeDifficulty = TapDifficulty.easy;
      if (level == 2) _activeDifficulty = TapDifficulty.medium;
      if (level == 3) _activeDifficulty = TapDifficulty.hard;
      debugPrint('[TapTarget] Applied and removed difficulty from SQLite: level $level');
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
    setState(() {
      _phase = _GamePhase.playing;
      _currentTrial = 0;
    });
    _scheduleNextTrial();
  }

  // ── Trial scheduling ──────────────────────────────────────────────────────

  /// Shows distractor-only grid for a randomised "lead-in" delay, then
  /// inserts the target card. Patient taps target; if missed, records omission.
  void _scheduleNextTrial() {
    if (_currentTrial >= _activeDifficulty.trialCount) {
      _finishSession();
      return;
    }

    _trialAnswered = false;

    // Build distractor grid (no target yet).
    final distractors = _bankService.selectDistractors(
      bank: _bank,
      target: _target,
      difficulty: _activeDifficulty,
    );

    // Randomise lead-in: 0.5× to 1.5× of the configured interval.
    final intervalMs =
        (_activeDifficulty.appearanceIntervalSeconds * 1000).round();
    final leadIn = (intervalMs * (0.5 + _random.nextDouble())).round();

    setState(() {
      _targetVisible = false;
      _waitingForTarget = true;
      _currentGrid = List.of(distractors)..shuffle(_random);
      _targetGridIndex = -1;
    });

    _trialTimer = Timer(Duration(milliseconds: leadIn), () {
      if (!mounted) return;
      _showTargetInGrid(distractors);
    });
  }

  void _showTargetInGrid(List<TargetConfig> distractors) {
    final gridWithTarget = List.of(distractors)..add(_target);
    gridWithTarget.shuffle(_random);
    final idx = gridWithTarget.indexOf(_target);

    // Target is visible for 1.5× the base interval, then counts as omission.
    final visibleMs =
        (_activeDifficulty.appearanceIntervalSeconds * 1500).round();

    setState(() {
      _targetVisible = true;
      _waitingForTarget = false;
      _currentGrid = gridWithTarget;
      _targetGridIndex = idx;
      _targetAppearedAt = DateTime.now();
    });

    _trialTimer = Timer(Duration(milliseconds: visibleMs), () {
      if (!mounted || _trialAnswered) return;
      // Omission: target disappeared before patient tapped.
      _omissions++;
      _rawTrialLog(
        tappedId: '__omission__',
        isCorrect: false,
        reactionMs: visibleMs,
      );
      _advanceTrial();
    });
  }

  void _onCardTapped(TargetConfig item) {
    if (!_targetVisible || _trialAnswered) {
      // Tapping during distractor-only phase or after answer → false positive.
      _falseTaps++;
      _totalTaps++;
      _rawTrialLog(
        tappedId: item.id,
        isCorrect: false,
        reactionMs: _targetAppearedAt != null
            ? DateTime.now().difference(_targetAppearedAt!).inMilliseconds
            : 0,
      );
      return;
    }

    _trialAnswered = true;
    _trialTimer?.cancel();
    _totalTaps++;

    final reactionMs = _targetAppearedAt != null
        ? DateTime.now().difference(_targetAppearedAt!).inMilliseconds
        : 0;

    final isCorrect = item.id == _target.id;
    if (!isCorrect) _falseTaps++;

    _rawTrialLog(
      tappedId: item.id,
      isCorrect: isCorrect,
      reactionMs: reactionMs,
    );

    _advanceTrial();
  }

  void _rawTrialLog({
    required String tappedId,
    required bool isCorrect,
    required int reactionMs,
  }) {
    _tapEvents.add(_TapEvent(
      trialIndex: _currentTrial,
      tappedItemId: tappedId,
      isCorrectTarget: isCorrect,
      reactionTimeMs: reactionMs,
      timestamp: DateTime.now(),
    ));

    _telemetryTracker.recordRound(
      latencyMs: reactionMs.toDouble(),
      isCorrect: isCorrect,
      eventType: tappedId == '__omission__'
          ? 'omission'
          : (isCorrect ? 'target_hit' : 'distractor_tap'),
      metadata: {
        'trial_index': _currentTrial,
        'tapped_item_id': tappedId,
        'target_id': _target.id,
      },
    );
  }

  void _advanceTrial() {
    setState(() {
      _targetVisible = false;
      _currentTrial++;
    });
    // Brief inter-trial blank before next trial
    _trialTimer = Timer(const Duration(milliseconds: 400), _scheduleNextTrial);
  }

  // ── Analytics computation ─────────────────────────────────────────────────
  void _finishSession() {
    final sessionDuration =
        DateTime.now().difference(_sessionStart).inMilliseconds / 1000.0;

    // Reaction times for correct taps only.
    final correctTaps = _tapEvents
        .where((e) => e.isCorrectTarget)
        .toList();

    double rtAvg = 0;
    double rtStdDev = 0;

    if (correctTaps.isNotEmpty) {
      final rts = correctTaps.map((e) => e.reactionTimeMs.toDouble()).toList();
      rtAvg = rts.reduce((a, b) => a + b) / rts.length;
      if (rts.length > 1) {
        final variance = rts
                .map((t) => pow(t - rtAvg, 2))
                .reduce((a, b) => a + b) /
            rts.length;
        rtStdDev = sqrt(variance);
      }
    }

    final trialCount = _activeDifficulty.trialCount;
    final omissionRate =
        trialCount > 0 ? (_omissions / trialCount).clamp(0.0, 1.0) : 0.0;
    final falsePositiveRate =
        _totalTaps > 0 ? (_falseTaps / _totalTaps).clamp(0.0, 1.0) : 0.0;

    // Within-session drift: compare first-half vs second-half correct rate.
    final half = trialCount ~/ 2;
    final earlyTrials =
        _tapEvents.where((e) => e.trialIndex < half).toList();
    final lateTrials =
        _tapEvents.where((e) => e.trialIndex >= half).toList();

    double earlyRate = earlyTrials.isEmpty
        ? 0.0
        : earlyTrials.where((e) => e.isCorrectTarget).length /
            earlyTrials.length;
    double lateRate = lateTrials.isEmpty
        ? 0.0
        : lateTrials.where((e) => e.isCorrectTarget).length /
            lateTrials.length;
    final withinSessionDrift = lateRate - earlyRate; // negative = fatigue

    // Normalised score: correct rate − false positive penalty.
    final correctRate = 1.0 - omissionRate;
    final score =
        (correctRate - (falsePositiveRate * 0.5)).clamp(0.0, 1.0);

    final result = TapTargetSessionResult(
      reactionTimeAvg: rtAvg,
      reactionTimeVariability: rtStdDev,
      omissionRate: omissionRate,
      falsePositiveRate: falsePositiveRate,
      withinSessionDrift: withinSessionDrift,
      trialCount: trialCount,
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

    // Persist session to local storage for later sync to backend.
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

    // Spin up TFLite model on raw telemetry JSON and save decision to SQLite database
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
        await DifficultyDatabaseService.instance.saveDifficultySetting(
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
          // Heading
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
                // Target card — large, prominent
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

  // ── Play area ─────────────────────────────────────────────────────────────
  Widget _buildPlayArea() {
    final trialCount = _activeDifficulty.trialCount;
    final progress = _currentTrial / trialCount;

    // Grid column count: 2 for easy (3 cards), 3 for medium (5 cards), 3 for hard.
    final colCount = _activeDifficulty.distractorCount <= 2 ? 2 : 3;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress indicator (no timer shown to patient — just subtle bar)
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

          // Status hint
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                _waitingForTarget ? _waitText : ' ',
                key: ValueKey(_waitingForTarget),
                style: const TextStyle(
                  fontSize: 18,
                  color: AppColors.inkSoft,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Item grid
          Expanded(
            child: _currentGrid.isEmpty
                ? const SizedBox.shrink()
                : GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _currentGrid.length,
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: colCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.0,
                    ),
                    itemBuilder: (context, i) {
                      final item = _currentGrid[i];
                      final isTarget = i == _targetGridIndex && _targetVisible;
                      return _ItemCard(
                        item: item,
                        languageCode: widget.promptLanguage,
                        isTarget: isTarget,
                        onTap: () => _onCardTapped(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Summary ───────────────────────────────────────────────────────────────
  Widget _buildSummary() {
    final r = _result;
    if (r == null) return const SizedBox.shrink();

    final pct = (r.scoreNormalized * 100).round();
    final rtDisplay = r.reactionTimeAvg > 0
        ? '${(r.reactionTimeAvg / 1000).toStringAsFixed(1)}s'
        : '--';

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
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$pct% Score',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.terracotta,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _StatRow(
                  label: _isAs ? 'গড় প্ৰতিক্ৰিয়া সময়' : 'Avg reaction time',
                  value: rtDisplay,
                ),
                _StatRow(
                  label: _isAs ? 'হেৰুওৱা লক্ষ্য' : 'Missed targets',
                  value:
                      '${(_omissions)}/${_activeDifficulty.trialCount}',
                ),
                _StatRow(
                  label: _isAs ? 'ভুল টেপ' : 'False taps',
                  value: '$_falseTaps',
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () => Navigator.of(context).maybePop(_result),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.terracotta,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 88),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              _doneButton,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Item card widget
// ─────────────────────────────────────────────────────────────────────────────
class _ItemCard extends StatelessWidget {
  final TargetConfig item;
  final String languageCode;
  final bool isTarget;
  final VoidCallback onTap;

  const _ItemCard({
    required this.item,
    required this.languageCode,
    required this.isTarget,
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
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.border,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.iconData,
                  size: 44,
                  // All cards look identical — no visual hint that any is the target.
                  color: AppColors.terracottaDark,
                ),
                const SizedBox(height: 8),
                Text(
                  item.getName(languageCode),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat row for summary screen
// ─────────────────────────────────────────────────────────────────────────────
class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 17, color: AppColors.inkSoft),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
