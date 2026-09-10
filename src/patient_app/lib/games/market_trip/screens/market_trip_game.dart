import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../theme/theme.dart';
import '../../../games/shared/models/round_telemetry.dart';
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
  final GameTelemetryTracker _telemetryTracker =
      GameTelemetryTracker(hesitationThresholdMs: 2500.0, errorBurstThreshold: 2);
  final List<Map<String, dynamic>> _rawTrials = [];
  DateTime? _distractorStartTime;
  DateTime? _distractorEndTime;

  int _distractorTapCount = 0;
  bool _distractorTaskCompleted = false;

  late GameDifficulty _activeDifficulty;
  GameSessionResult? _finalResult;

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
      _distractorTapCount = 0;
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

  void _submitRecall() {
    _recallEndTime = DateTime.now();
    final recallDurationSeconds = _recallEndTime != null && _recallStartTime != null
        ? _recallEndTime!.difference(_recallStartTime!).inMilliseconds / 1000.0
        : 0.0;

    final totalSessionSeconds = DateTime.now().difference(_sessionStartTime).inMilliseconds / 1000.0;

    double delayDuration = 0.0;
    if (_distractorStartTime != null && _distractorEndTime != null) {
      delayDuration = _distractorEndTime!.difference(_distractorStartTime!).inMilliseconds / 1000.0;
    }

    final promptIds = _promptItems.map((e) => e.id).toSet();
    int correctCount = 0;
    int falseCount = 0;

    for (final selectedId in _selectedItemIds) {
      if (promptIds.contains(selectedId)) {
        correctCount++;
      } else {
        falseCount++;
      }
    }

    final int promptedCount = _promptItems.length;
    final double accuracy = promptedCount > 0 ? (correctCount / promptedCount).clamp(0.0, 1.0) : 0.0;

    // Calculate normalized score (0.0 to 1.0) taking intrusion errors into account
    final double penalty = falseCount * 0.15;
    final double normalizedScore = (accuracy - penalty).clamp(0.0, 1.0);

    final String langString = widget.promptLanguage == 'as'
        ? 'assamese'
        : (widget.promptLanguage == 'bn' ? 'bengali' : 'english');

    // Record distractor tap count into rawTrials for downstream analytics.
    _rawTrials.add({
      'event': 'distractor_summary',
      'tap_count': _distractorTapCount,
      'completed': _distractorTaskCompleted || _activeDifficulty == GameDifficulty.easy,
    });

    final result = GameSessionResult(
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

    setState(() {
      _finalResult = result;
      _currentPhase = MarketGamePhase.summary;
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

    unawaited(() async {
      try {
        final decision = await DynamicDifficultyService.instance.evaluateSessionJson(
          rawTelemetryJson,
          currentDifficulty: _activeDifficulty.index + 1,
          gameType: 'market_trip',
        );
        await DifficultyDatabaseService.instance.saveDifficultySetting(
          decision,
          rawJson: rawTelemetryJson,
        );
      } catch (e) {
        debugPrint('[MarketTrip] Error running TFLite difficulty model: $e');
      }
    }());

    widget.onGameCompleted?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.promptLanguage == 'as' ? 'বজাৰৰ যাত্ৰা (Market Trip)' : 'The Market Trip',
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

  /// Distractor Phase Widget: Calm 10-second interactive plant watering / counting task.
  Widget _buildDistractorWidget() {
    return _DistractorTaskWidget(
      languageCode: widget.promptLanguage,
      onCompleted: (tapsCount, completed) {
        _distractorTapCount = tapsCount;
        _distractorTaskCompleted = completed;
        _onDistractorFinished();
      },
    );
  }

  /// Recall Phase Widget: Item card grid with dementia-safe selection state (border + checkmark icon).
  Widget _buildRecallWidget() {
    final titleText = widget.promptLanguage == 'as'
        ? 'বজাৰৰ মোনাত কি কি আছিল বাছনি কৰক:'
        : 'Select the items that were on your shopping list:';

    final submitText = widget.promptLanguage == 'as'
        ? 'জমা দিয়ক (${_selectedItemIds.length} টা বাছনি কৰা হ’ল)'
        : 'Submit Shopping Bag (${_selectedItemIds.length} selected)';

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

  /// Summary Phase Widget: Displays session results and encouragement.
  Widget _buildSummaryWidget() {
    final result = _finalResult;
    if (result == null) return const SizedBox.shrink();

    final int pct = (result.recallAccuracy * 100).round();

    final String heading = widget.promptLanguage == 'as'
        ? 'ধন্যবাদ! বজাৰৰ যাত্ৰা সম্পূৰ্ণ হ’ল'
        : 'Well Done! Market Trip Complete';

    final String scoreMsg = widget.promptLanguage == 'as'
        ? 'আপুনি ${result.itemsPromptedCount} টা বস্তুৰ ভিতৰত ${result.itemsRecalledCorrect} টা সঠিকভাৱে বাছনি কৰিলে।'
        : 'You correctly recalled ${result.itemsRecalledCorrect} out of ${result.itemsPromptedCount} items.';

    return Container(
      color: AppColors.cream,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
                const Icon(
                  Icons.stars,
                  size: 64,
                  color: AppColors.mugaGold,
                ),
                const SizedBox(height: 16),
                Text(
                  heading,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$pct% Recall Accuracy',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.terracotta,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  scoreMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppColors.inkSoft,
                    height: 1.4,
                  ),
                ),
                if (result.falseSelectionCount > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Extra items selected: ${result.falseSelectionCount}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).maybePop(result);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.terracotta,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 88),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              widget.promptLanguage == 'as' ? 'সম্পূৰ্ণ হ’ল (Done)' : 'Done',
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

/// Simple 10-second distractor interaction widget: Water the garden tea plants.
class _DistractorTaskWidget extends StatefulWidget {
  final String languageCode;
  final void Function(int tapCount, bool completed) onCompleted;

  const _DistractorTaskWidget({
    required this.languageCode,
    required this.onCompleted,
  });

  @override
  State<_DistractorTaskWidget> createState() => _DistractorTaskWidgetState();
}

class _DistractorTaskWidgetState extends State<_DistractorTaskWidget> {
  int _secondsLeft = 10;
  int _waterTaps = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft > 1) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        _timer?.cancel();
        widget.onCompleted(_waterTaps, true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tapWaterPlant() {
    setState(() {
      _waterTaps++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.languageCode == 'as'
        ? 'মন স্থিৰ কৰক: কিছু সময় বাগিচাত পানী দিয়ক'
        : 'Take a short breath: Water the tea leaves';

    final instruction = widget.languageCode == 'as'
        ? 'গছজোপাত পানী দিবলৈ টেপ কৰক ($_waterTaps বাৰ পানী দিয়া হ’ল)'
        : 'Tap the plant to water it ($_waterTaps times watered)';

    return Container(
      color: AppColors.cream,
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

          // Interactive Water Plant Target (Min target 88dp height/width)
          GestureDetector(
            onTap: _tapWaterPlant,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.sageGreen, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.water_drop,
                    size: 64,
                    color: AppColors.sageGreen,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    instruction,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
