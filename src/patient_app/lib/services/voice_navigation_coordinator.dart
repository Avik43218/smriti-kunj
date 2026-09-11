import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/patient_activity.dart';
import '../services/activity_database_service.dart';
import '../services/difficulty_database_service.dart';
import '../services/locale_service.dart';
import '../services/session_service.dart';
import '../screens/games_screen.dart';
import '../screens/pairing_screen.dart';
import '../games/market_trip/screens/market_trip_game.dart';
import '../games/market_trip/services/item_bank_service.dart';
import '../games/market_trip/models/game_session_result.dart';
import '../games/tap_target/screens/tap_target_game.dart';
import '../games/tap_target/services/target_bank_service.dart';
import '../games/pair_matching/screens/pair_matching_game.dart';
import '../games/pair_matching/services/pair_bank_service.dart';
import '../games/pair_matching/models/game_session_result.dart';
import '../theme/theme.dart';
import 'voice_navigation_service.dart';

/// Central coordinator that executes navigation commands identified by the voice system.
class VoiceNavigationCoordinator {
  static final VoiceNavigationCoordinator instance = VoiceNavigationCoordinator._internal();
  VoiceNavigationCoordinator._internal();
  factory VoiceNavigationCoordinator() => instance;

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Executes the given [command] using either [context] or [navigatorKey.currentContext].
  Future<void> execute(VoiceCommand command, [BuildContext? context]) async {
    final ctx = context ?? navigatorKey.currentContext;
    if (ctx == null) {
      debugPrint('[VoiceNavigationCoordinator] No active context found for command: $command');
      return;
    }

    _showCommandFeedback(ctx, command);

    switch (command) {
      case VoiceCommand.game:
        await navigateToGames(ctx);
        break;

      case VoiceCommand.marketTrip:
        await launchMarketTrip(ctx);
        break;

      case VoiceCommand.tapTarget:
        await launchTapTarget(ctx);
        break;

      case VoiceCommand.patternMatch:
        await launchPatternMatch(ctx);
        break;

      case VoiceCommand.logout:
        await performLogout(ctx);
        break;
    }
  }

  void _showCommandFeedback(BuildContext context, VoiceCommand command) {
    try {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1400),
          backgroundColor: command.color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            children: [
              Icon(command.icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '🎙️ ${command.englishTitle} (${command.bengaliTitle})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {}
  }

  /// Navigates to [GamesScreen].
  Future<void> navigateToGames(BuildContext context) async {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GamesScreen()),
    );
  }

  /// Direct launch of Market Trip game with auto-difficulty adjustment.
  Future<void> launchMarketTrip(BuildContext context) async {
    final session = Provider.of<SessionService>(context, listen: false);
    final locale = Provider.of<LocaleService>(context, listen: false);

    final decision = await DifficultyDatabaseService.instance
        .consumeAndClearForSelectedGame('market_trip');

    final level = decision?.recommendedDifficulty ??
        await DifficultyDatabaseService.instance.getCurrentLevel('market_trip');

    final difficulty = switch (level) {
      1 => GameDifficulty.easy,
      2 => GameDifficulty.medium,
      3 => GameDifficulty.hard,
      _ => GameDifficulty.easy,
    };

    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MarketTripGameScreen(
        difficulty: difficulty,
        promptLanguage: locale.code,
        patientProfileId: session.patientId,
        onGameCompleted: (GameSessionResult result) {
          ActivityDatabaseService.instance.recordGameActivity(PatientActivityRecord(
            clientSessionId: result.sessionId.isNotEmpty
                ? result.sessionId
                : 'mt_${DateTime.now().millisecondsSinceEpoch}',
            patientId: session.patientId,
            patientProfileId: session.patientId,
            pairingCode: session.pairingCode,
            gameType: 'market_trip',
            gameName: 'Market Trip',
            domain: 'memory',
            difficultyLevel: level,
            scoreNormalized: result.scoreNormalized,
            sessionDuration: result.sessionDuration.toInt(),
            accuracy: result.recallAccuracy,
            avgLatencyMs: (result.timeToCompleteRecall * 1000).clamp(0, 100000),
            errorRate: result.itemsPromptedCount > 0
                ? (result.falseSelectionCount / (result.itemsPromptedCount + result.falseSelectionCount)).clamp(0.0, 1.0)
                : 0.0,
            sessionDate: result.sessionDate,
            status: result.status,
            rawPayload: result.toJson(),
          ));
        },
      ),
    ));
  }

  /// Direct launch of Tap Target game with auto-difficulty adjustment.
  Future<void> launchTapTarget(BuildContext context) async {
    final session = Provider.of<SessionService>(context, listen: false);
    final locale = Provider.of<LocaleService>(context, listen: false);

    final decision = await DifficultyDatabaseService.instance
        .consumeAndClearForSelectedGame('tap_target');

    final level = decision?.recommendedDifficulty ??
        await DifficultyDatabaseService.instance.getCurrentLevel('tap_target');

    final difficulty = switch (level) {
      1 => TapDifficulty.easy,
      2 => TapDifficulty.medium,
      3 => TapDifficulty.hard,
      _ => TapDifficulty.easy,
    };

    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TapTargetGameScreen(
        difficulty: difficulty,
        promptLanguage: locale.code,
        patientProfileId: session.patientId,
        onGameCompleted: (result) {
          ActivityDatabaseService.instance.recordGameActivity(PatientActivityRecord(
            clientSessionId: result.sessionId.isNotEmpty
                ? result.sessionId
                : 'tt_${DateTime.now().millisecondsSinceEpoch}',
            patientId: session.patientId,
            patientProfileId: session.patientId,
            pairingCode: session.pairingCode,
            gameType: 'tap_target',
            gameName: 'Tap Target',
            domain: 'attention',
            difficultyLevel: level,
            scoreNormalized: result.scoreNormalized,
            sessionDuration: result.sessionDuration.toInt(),
            accuracy: (1.0 - result.omissionRate).clamp(0.0, 1.0),
            avgLatencyMs: result.reactionTimeAvg,
            errorRate: result.falsePositiveRate,
            sessionDate: result.sessionDate,
            status: result.status,
            rawPayload: result.toJson(),
          ));
        },
      ),
    ));
  }

  /// Direct launch of Pair Matching / Pattern Match game with auto-difficulty adjustment.
  Future<void> launchPatternMatch(BuildContext context) async {
    final session = Provider.of<SessionService>(context, listen: false);
    final locale = Provider.of<LocaleService>(context, listen: false);

    final decision = await DifficultyDatabaseService.instance
        .consumeAndClearForSelectedGame('pair_matching');

    final level = decision?.recommendedDifficulty ??
        await DifficultyDatabaseService.instance.getCurrentLevel('pair_matching');

    final difficulty = switch (level) {
      1 => PairDifficulty.easy,
      2 => PairDifficulty.medium,
      3 => PairDifficulty.hard,
      _ => PairDifficulty.easy,
    };

    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PairMatchingGameScreen(
        difficulty: difficulty,
        promptLanguage: locale.code,
        patientProfileId: session.patientId,
        onGameCompleted: (PairMatchingSessionResult result) {
          ActivityDatabaseService.instance.recordGameActivity(PatientActivityRecord(
            clientSessionId: result.sessionId.isNotEmpty
                ? result.sessionId
                : 'pm_${DateTime.now().millisecondsSinceEpoch}',
            patientId: session.patientId,
            patientProfileId: session.patientId,
            pairingCode: session.pairingCode,
            gameType: 'pair_matching',
            gameName: 'Pair Matching',
            domain: 'memory',
            difficultyLevel: level,
            scoreNormalized: result.scoreNormalized,
            sessionDuration: result.sessionDuration.toInt(),
            accuracy: result.correctMatchRate,
            avgLatencyMs: (result.timeToFirstCorrectMatch * 1000).clamp(0, 100000),
            errorRate: result.repeatErrorRate,
            sessionDate: result.sessionDate,
            status: result.status,
            rawPayload: result.toJson(),
          ));
        },
      ),
    ));
  }

  /// Performs device logout and navigates back to pairing screen.
  Future<void> performLogout(BuildContext context) async {
    final session = Provider.of<SessionService>(context, listen: false);
    await session.unpair();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PairingScreen()),
      (route) => false,
    );
  }
}
