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
import '../services/api_service.dart';
import 'app_strings.dart';
import '../theme/theme.dart';
import '../screens/reminders_screen.dart';
import '../screens/memory_gallery_screen.dart';
import '../widgets/sos_button.dart';
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
      case VoiceCommand.home:
        await navigateToHome(ctx);
        break;

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

      case VoiceCommand.reminders:
        await navigateToReminders(ctx);
        break;

      case VoiceCommand.gallery:
        await navigateToGallery(ctx);
        break;

      case VoiceCommand.sync:
        await performSync(ctx);
        break;

      case VoiceCommand.help:
        await triggerHelp(ctx);
        break;

      case VoiceCommand.langAssamese:
        await changeLanguage(ctx, AppLang.assamese);
        break;

      case VoiceCommand.langBengali:
        await changeLanguage(ctx, AppLang.bengali);
        break;

      case VoiceCommand.langBodo:
        await changeLanguage(ctx, AppLang.bodo);
        break;

      case VoiceCommand.langEnglish:
        await changeLanguage(ctx, AppLang.english);
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

  /// Navigates to Home screen if currently on any other pushed screen.
  Future<void> navigateToHome(BuildContext context) async {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Navigates to [RemindersScreen].
  Future<void> navigateToReminders(BuildContext context) async {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RemindersScreen()),
    );
  }

  /// Navigates to [MemoryGalleryScreen].
  Future<void> navigateToGallery(BuildContext context) async {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MemoryGalleryScreen()),
    );
  }

  /// Dispatches Emergency SOS confirmation dialog and opens device dialer.
  Future<void> triggerHelp(BuildContext context) async {
    debugPrint('[SOS ALERT] Emergency trigger dispatched via voice navigation at ${DateTime.now().toIso8601String()}');
    launchGuardianDialer();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SosConfirmationScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  /// Changes the application UI language reactively.
  Future<void> changeLanguage(BuildContext context, AppLang lang) async {
    try {
      final locale = Provider.of<LocaleService>(context, listen: false);
      locale.setLang(lang);
    } catch (_) {
      LocaleService.instance.setLang(lang);
    }
  }

  /// Executes data synchronization with MongoDB backend.
  Future<void> performSync(BuildContext context) async {
    final activityService = ActivityDatabaseService.instance;
    final session = Provider.of<SessionService>(context, listen: false);
    final locale = Provider.of<LocaleService>(context, listen: false);
    final strings = AppStrings(locale.lang);

    try {
      final activeCode = await activityService.getActivePairingCode();
      if (activeCode == null || activeCode.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync failed: No pairing code found. Please pair your device first.'),
            backgroundColor: AppColors.terracottaDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      var pending = await activityService.getUnsyncedActivities();
      if (pending.isEmpty) {
        await activityService.seedSampleActivityIfEmpty(
          session.patientId,
          pairingCode: session.pairingCode ?? activeCode,
        );
        pending = await activityService.getUnsyncedActivities();
      }

      if (pending.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.allSynced),
            backgroundColor: AppColors.sageGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final validToSync = <PatientActivityRecord>[];
      for (final act in pending) {
        final code = act.pairingCode;
        if (code != null && code.isNotEmpty && await activityService.hasPairingCode(code)) {
          validToSync.add(act);
        }
      }

      if (validToSync.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync rejected: Stored game activities do not have a matching pairing code in the local database.'),
            backgroundColor: AppColors.terracottaDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final accepted = await ApiService.instance.syncBatchActivities(
        activities: validToSync,
        token: session.authToken,
        patientId: session.patientId,
        pairingCode: activeCode,
      );

      final sessionIds = validToSync.map((a) => a.clientSessionId).toList();
      await activityService.deleteActivities(sessionIds);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${strings.syncSuccess} ($accepted games sent) • ${strings.syncCleaned}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.sageGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      debugPrint('[VoiceNavigationCoordinator] Sync error: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Saved locally on tablet. Will sync once backend is reachable.'),
              ),
            ],
          ),
          backgroundColor: AppColors.terracotta,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
