import 'dart:async';
import 'dart:convert';
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
import '../models/market_item.dart';
import '../services/item_bank_service.dart';
import '../services/prompt_delivery_service.dart';

enum MarketGamePhase {
  loading,
  prompting,
  distractor,
  recalling,
  summary,
}

class MarketTripGameScreen extends StatefulWidget {
  final GameDifficulty difficulty;
  final String promptLanguage;
  final String patientProfileId;
  final PromptDeliveryService promptDelivery;
  final void Function(GameSessionResult result)? onGameCompleted;

  const MarketTripGameScreen({
    super.key,
    this.difficulty = GameDifficulty.easy,
    this.promptLanguage = 'as',
    this.patientProfileId = 'patient_001',
    this.promptDelivery = const TextPromptDelivery(),
    this.onGameCompleted,
  });

  @override
  State<MarketTripGameScreen> createState() => _MarketTripGameScreenState();
}

class _MarketTripGameScreenState extends State<MarketTripGameScreen> {
  final ItemBankService _itemBankService = ItemBankService();

  MarketGamePhase _currentPhase = MarketGamePhase.loading;
  List<MarketItem> _promptItems = [];
  List<MarketItem> _recallGrid = [];
  final Set<String> _selectedItemIds = {};

  // Timing & Analytics tracking
  late DateTime _sessionStartTime;
  DateTime? _recallStartTime;
  DateTime? _recallEndTime;
  DateTime? _lastSelectionTime;
  GameTelemetryTracker _telemetryTracker =
      GameTelemetryTracker(hesitationThresholdMs: 2500.0, errorBurstThreshold: 2);
  final List<Map<String, dynamic>> _rawTrials = [];
  DateTime? _distractorStartTime;
  DateTime? _distractorEndTime;

  bool _distractorTaskCompleted = false;

  late GameDifficulty _activeDifficulty;
  GameSessionResult? _finalResult;
  CompletionMessage _completionMessage = CompletionMessage.getRandom();

  @override
  void initState() {
    super.initState();
    _activeDifficulty = widget.difficulty;
    _sessionStartTime = DateTime.now();
    _initGame();
  }

  Future<void> _initGame() async {
    setState(() {
      _currentPhase = MarketGamePhase.loading;
    });

    _completionMessage = CompletionMessage.getRandom();
    _sessionStartTime = DateTime.now();
    _recallStartTime = null;
    _recallEndTime = null;
    _lastSelectionTime = null;
    _distractorStartTime = null;
    _distractorEndTime = null;
    _distractorTaskCompleted = false;
    _selectedItemIds.clear();
    _rawTrials.clear();
    _telemetryTracker =
        GameTelemetryTracker(hesitationThresholdMs: 2500.0, errorBurstThreshold: 2);
    _finalResult = null;

    // Check if next-game difficulty was queued in SQLite
    final pending = await DifficultyDatabaseService.instance
        .consumeLatestDifficultySetting(gameType: 'market_trip');
    if (pending != null) {
      final level = pending.recommendedDifficulty;
      if (level == 1) _activeDifficulty = GameDifficulty.easy;
      if (level == 2) _activeDifficulty = GameDifficulty.medium;
      if (level == 3) _activeDifficulty = GameDifficulty.hard;
      debugPrint('[MarketTrip] Applied and removed difficulty from SQLite: $_activeDifficulty');
    }

    final bank = await _itemBankService.loadItemBank();
    final prompts = _itemBankService.selectPromptItems(
      bank: bank,
      difficulty: _activeDifficulty,
    );
    final grid = _itemBankService.generateRecallGrid(
      bank: bank,
      promptItems: prompts,
      difficulty: _activeDifficulty,
    );

    if (!mounted) return;
    setState(() {
      _promptItems = prompts;
      _recallGrid = grid;
      _currentPhase = MarketGamePhase.prompting;
    });
  }

  void _onPromptFinished() {
    if (_activeDifficulty == GameDifficulty.easy) {
      // Easy level bypasses distractor phase
      _startRecallPhase();
    } else {
      _startDistractorPhase();
    }
  }

  void _startDistractorPhase() {
    _distractorStartTime = DateTime.now();
    setState(() {
      _currentPhase = MarketGamePhase.distractor;
      _distractorTaskCompleted = false;
    });
  }

  void _onDistractorFinished() {
    _distractorEndTime = DateTime.now();
    _startRecallPhase();
  }

  void _startRecallPhase() {
    _recallStartTime = DateTime.now();
    _lastSelectionTime = _recallStartTime;
    setState(() {
      _currentPhase = MarketGamePhase.recalling;
      _selectedItemIds.clear();
    });
  }

  void _toggleItemSelection(MarketItem item) {
    if (_currentPhase != MarketGamePhase.recalling) return;

    final isSelected = _selectedItemIds.contains(item.id);
    final now = DateTime.now();
    final latencyMs = _lastSelectionTime != null
        ? now.difference(_lastSelectionTime!).inMilliseconds.toDouble()
        : 0.0;
    _lastSelectionTime = now;

    final isTarget = _promptItems.any((p) => p.id == item.id);
    final isCorrect = isSelected ? !isTarget : isTarget;

    _telemetryTracker.recordRound(
      latencyMs: latencyMs,
      isCorrect: isCorrect,
      eventType: isSelected ? 'item_deselect' : 'item_select',
      rawHesitationMs:
          latencyMs > 2500.0 ? (latencyMs - 2500.0) : 0.0,
      metadata: {
        'item_id': item.id,
        'action': isSelected ? 'deselect' : 'select',
        'is_prompt_target': isTarget,
      },
    );

    setState(() {
      if (isSelected) {
        _selectedItemIds.remove(item.id);
      } else {
        _selectedItemIds.add(item.id);
      }
    });

    _rawTrials.add({
      'timestamp': now.toIso8601String(),
      'item_id': item.id,
      'action': isSelected ? 'deselect' : 'select',
      'is_correct_target': isTarget,
    });
  }

  Future<void> _submitRecall() async {
    _recallEndTime = DateTime.now();
    final recallDurationSeconds = _recallEndTime != null && _recallStartTime != null
        ? _recallEndTime!.difference(_recallStartTime!).inMilliseconds / 1000.0
        : 0.0;

    final totalSessionSeconds = DateTime.now().difference(_sessionStartTime).inMilliseconds / 1000.0;

    double delayDuration = 0.0;
    if (_distractorStartTime != null && _distractorEndTime != null) {
      delayDuration = _distractorEndTime!.difference(_distractorStartTime!).inMilliseconds / 1000.0;
    }

    final bank = await _itemBankService.loadItemBank();
    final targetItemIds = _promptItems.map((e) => e.id).toSet();

    int correctCount = 0;
    int falseCount = 0;

    for (final id in _selectedItemIds) {
      if (targetItemIds.contains(id)) {
        correctCount++;
      } else {
        falseCount++;
      }
    }

    final promptedCount = _promptItems.length;
    final accuracy = promptedCount > 0 ? (correctCount / promptedCount).clamp(0.0, 1.0) : 0.0;
    final rawScore = promptedCount > 0
        ? ((correctCount - (falseCount * 0.5)) / promptedCount).clamp(0.0, 1.0)
        : 0.0;
    final normalizedScore = rawScore.clamp(0.0, 1.0);

    final langString = switch (widget.promptLanguage) {
      'as' => 'as',
      'bn' => 'bn',
      _ => 'en',
    };

    final result = GameSessionResult(
      gameType: 'market_trip',
      itemsPromptedCount: promptedCount,
      itemsRecalledCorrect: correctCount,
      recallAccuracy: accuracy,
      falseSelectionCount: falseCount,
      timeToCompleteRecall: recallDurationSeconds,
      distractorTaskCompleted: _distractorTaskCompleted || _activeDifficulty == GameDifficulty.easy,
      delayDuration: delayDuration,
      promptLanguage: langString,
      sessionId: 'sess_${DateTime.now().millisecondsSinceEpoch}',
      patientProfileId: widget.patientProfileId,
      sessionDate: DateTime.now(),
      sessionDuration: totalSessionSeconds,
      status: 'completed',
      scoreNormalized: normalizedScore,
      rawTrials: _rawTrials,
    );

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
      difficultyLevel: _activeDifficulty.index + 1,
      scoreNormalized: result.scoreNormalized,
      gameData: {
        'items_prompted_count': result.itemsPromptedCount,
        'items_recalled_correct': result.itemsRecalledCorrect,
        'recall_accuracy': result.recallAccuracy,
        'false_selection_count': result.falseSelectionCount,
        'time_to_complete_recall': result.timeToCompleteRecall,
        'distractor_task_completed': result.distractorTaskCompleted,
        'delay_duration': result.delayDuration,
        'prompt_language': result.promptLanguage,
        'telemetry': telemetrySummary.toJson(),
      },
      rawTrials: [
        ...result.rawTrials,
        ...telemetrySummary.rounds.map((r) => r.toJson()),
      ],
      createdAt: now,
    )));

    // Spin up TFLite model on raw telemetry JSON and save decision to SQLite database
    final rawTelemetryJson = jsonEncode({
      'game_type': result.gameType,
      'items_prompted_count': result.itemsPromptedCount,
      'items_recalled_correct': result.itemsRecalledCorrect,
      'recall_accuracy': result.recallAccuracy,
      'false_selection_count': result.falseSelectionCount,
      'time_to_complete_recall': result.timeToCompleteRecall,
      'distractor_task_completed': result.distractorTaskCompleted,
      'score_normalized': result.scoreNormalized,
      'telemetry': telemetrySummary.toJson(),
    });

    try {
      final decision = await DynamicDifficultyService.instance.evaluateSessionJson(
        rawTelemetryJson,
        currentDifficulty: _activeDifficulty.index + 1,
        gameType: 'market_trip',
      );
      await DifficultyDatabaseService.instance.saveDifficultySettingsForAllGames(
        decision,
        rawJson: rawTelemetryJson,
      );
      debugPrint('[MarketTrip] Evaluated and stored next difficulty: ${decision.action} -> level ${decision.recommendedDifficulty}');
    } catch (e) {
      debugPrint('[MarketTrip] Error running TFLite difficulty model: $e');
    }

    if (!mounted) return;
    setState(() {
      _finalResult = result;
      _currentPhase = MarketGamePhase.summary;
    });

    widget.onGameCompleted?.call(result);
  }

  AppStrings get _s => AppStrings(AppLangExt.fromCode(widget.promptLanguage));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _s.gameAppBarMarketTrip,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.ink,
          ),
        ),
      ),
      body: SafeArea(
        child: _buildPhaseContent(),
      ),
    );
  }

  Widget _buildPhaseContent() {
    switch (_currentPhase) {
      case MarketGamePhase.loading:
        return const Center(
          child: CircularProgressIndicator(
            color: AppColors.terracotta,
          ),
        );

      case MarketGamePhase.prompting:
        return widget.promptDelivery.buildPromptView(
          context: context,
          items: _promptItems,
          languageCode: widget.promptLanguage,
          onPromptFinished: _onPromptFinished,
        );

      case MarketGamePhase.distractor:
        return _buildDistractorWidget();

      case MarketGamePhase.recalling:
        return _buildRecallWidget();

      case MarketGamePhase.summary:
        return _buildSummaryWidget();
    }
  }

  /// Distractor Phase Widget: Interference counting task during memory delay.
  Widget _buildDistractorWidget() {
    return _DistractorTaskWidget(
      languageCode: widget.promptLanguage,
      difficulty: _activeDifficulty,
      onCompleted: (completed) {
        _distractorTaskCompleted = completed;
        _onDistractorFinished();
      },
    );
  }

  /// Recall Phase Widget: Item card grid with dementia-safe selection state (border + checkmark icon).
  Widget _buildRecallWidget() {
    final titleText = _s.recallTitle;
    final submitText = _s.recallSubmit(_selectedItemIds.length);

    return Container(
      color: AppColors.cream,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Instructions Card (22px text)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.checklist_rtl,
                  color: AppColors.terracotta,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    titleText,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Recall Cards Grid
          Expanded(
            child: GridView.builder(
              itemCount: _recallGrid.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                childAspectRatio: 1.1,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemBuilder: (context, index) {
                final item = _recallGrid[index];
                final isSelected = _selectedItemIds.contains(item.id);
                final itemName = item.getName(widget.promptLanguage);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _toggleItemSelection(item),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        // Card background: warm off-white surface + subtle terracotta tint when selected
                        color: isSelected
                            ? AppColors.terracotta.withValues(alpha: 0.08)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        // Selection state: 3.5px terracotta border vs 1.5px border
                        border: Border.all(
                          color: isSelected ? AppColors.terracotta : AppColors.border,
                          width: isSelected ? 3.5 : 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.ink.withValues(alpha: isSelected ? 0.12 : 0.05),
                            blurRadius: isSelected ? 8 : 4,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Center Content: Icon + Name
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  item.iconData,
                                  size: 42,
                                  color: isSelected
                                      ? AppColors.terracotta
                                      : AppColors.terracottaDark,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  itemName,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 18, // 18px text floor
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Selection Shape/Icon Badge (Top Right Corner) — Color + Icon compliance
                          if (isSelected)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.terracotta,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Submit Action Button (88dp min target, 20px text floor)
          ElevatedButton(
            onPressed: _selectedItemIds.isNotEmpty ? _submitRecall : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.terracotta,
              disabledBackgroundColor: AppColors.border,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 88),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 3,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shopping_bag, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    submitText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Summary Phase Widget: Displays warm completion message and Play Again / Done actions.
  Widget _buildSummaryWidget() {
    final String heading = _completionMessage.heading(widget.promptLanguage);
    final String subheading = _completionMessage.subheading(widget.promptLanguage);
    final String playAgainText = _s.playAgain;
    final String doneText = _s.done;

    return Container(
      color: AppColors.cream,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                      heading,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subheading,
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
                  playAgainText,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).maybePop(_finalResult);
                },
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
                  doneText,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DistractorShape {
  final IconData icon;
  final Color color;

  const _DistractorShape({required this.icon, required this.color});
}

/// Counting distractor task widget: Shapes appear sequentially during the delay.
/// Patient taps each shape as it appears to keep attention occupied.
class _DistractorTaskWidget extends StatefulWidget {
  final String languageCode;
  final GameDifficulty difficulty;
  final void Function(bool completed) onCompleted;

  const _DistractorTaskWidget({
    required this.languageCode,
    required this.difficulty,
    required this.onCompleted,
  });

  @override
  State<_DistractorTaskWidget> createState() => _DistractorTaskWidgetState();
}

class _DistractorTaskWidgetState extends State<_DistractorTaskWidget> {
  late int _totalDuration;
  late int _totalShapes;
  late int _secondsLeft;
  bool _hasTappedAtLeastOnce = false;
  final Set<int> _tappedShapeIndices = {};
  Timer? _timer;

  static const List<_DistractorShape> _shapePalette = [
    _DistractorShape(icon: Icons.star_rounded, color: AppColors.mugaGold),
    _DistractorShape(icon: Icons.circle, color: AppColors.terracotta),
    _DistractorShape(icon: Icons.square_rounded, color: AppColors.sageGreen),
    _DistractorShape(icon: Icons.diamond_rounded, color: AppColors.terracottaDark),
    _DistractorShape(icon: Icons.spa_rounded, color: AppColors.sageGreen),
    _DistractorShape(icon: Icons.change_history_rounded, color: AppColors.mugaGold),
    _DistractorShape(icon: Icons.circle, color: AppColors.inkSoft),
    _DistractorShape(icon: Icons.star_rounded, color: AppColors.terracotta),
    _DistractorShape(icon: Icons.hexagon_rounded, color: AppColors.sageGreen),
    _DistractorShape(icon: Icons.eco_rounded, color: AppColors.mugaGold),
  ];

  @override
  void initState() {
    super.initState();
    // Medium = 10s (5 shapes), Hard = 20s (10 shapes)
    _totalDuration = widget.difficulty == GameDifficulty.hard ? 20 : 10;
    _totalShapes = widget.difficulty == GameDifficulty.hard ? 10 : 5;
    _secondsLeft = _totalDuration;

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft > 1) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        _timer?.cancel();
        widget.onCompleted(_hasTappedAtLeastOnce);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _currentShapeIndex {
    final elapsed = _totalDuration - _secondsLeft;
    final index = (elapsed ~/ 2).clamp(0, _totalShapes - 1);
    return index;
  }

  void _tapCurrentShape(int index) {
    if (_tappedShapeIndices.contains(index)) return;
    setState(() {
      _hasTappedAtLeastOnce = true;
      _tappedShapeIndices.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final shapeIndex = _currentShapeIndex;
    final shape = _shapePalette[shapeIndex % _shapePalette.length];
    final isTapped = _tappedShapeIndices.contains(shapeIndex);

    final title = AppStrings(AppLangExt.fromCode(widget.languageCode)).distractorTitle;

    return Container(
      color: AppColors.cream,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timer and Title header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.sageGreen, width: 2),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer, color: AppColors.sageGreen, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      '$_secondsLeft seconds',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.sageGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
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
          const SizedBox(height: 32),

          // Interactive Counting Shape Target (Min target 88dp height/width)
          Center(
            child: GestureDetector(
              onTap: () => _tapCurrentShape(shapeIndex),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: isTapped
                      ? shape.color.withValues(alpha: 0.15)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: isTapped ? shape.color : AppColors.border,
                    width: isTapped ? 3.5 : 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isTapped
                          ? shape.color.withValues(alpha: 0.25)
                          : AppColors.ink.withValues(alpha: 0.08),
                      blurRadius: isTapped ? 16 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isTapped ? Icons.check_circle_rounded : shape.icon,
                      key: ValueKey('shape_${shapeIndex}_$isTapped'),
                      size: 80,
                      color: isTapped ? shape.color : shape.color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
