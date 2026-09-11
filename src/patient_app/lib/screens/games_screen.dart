import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/patient_activity.dart';
import '../services/activity_database_service.dart';
import '../services/app_strings.dart';
import '../services/difficulty_database_service.dart';
import '../services/locale_service.dart';
import '../services/session_service.dart';
import '../theme/theme.dart';
import '../games/market_trip/screens/market_trip_game.dart';
import '../games/market_trip/services/item_bank_service.dart';
import '../games/market_trip/models/game_session_result.dart';
import '../games/tap_target/screens/tap_target_game.dart';
import '../games/tap_target/services/target_bank_service.dart';
import '../games/pair_matching/screens/pair_matching_game.dart';
import '../games/pair_matching/services/pair_bank_service.dart';
import '../games/pair_matching/models/game_session_result.dart';
import '../widgets/voice_nav_button.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  Future<void> _launchMarketTrip(
    BuildContext context,
    SessionService session,
    LocaleService locale,
  ) async {
    // Consume setting for Market Trip and automatically remove all pending settings from SQLite
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

    debugPrint('[GamesScreen] Launching Market Trip at auto-adjusted difficulty: $difficulty');

    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MarketTripGameScreen(
        difficulty: difficulty,
        promptLanguage: locale.code,
        patientProfileId: session.patientId,
        onGameCompleted: (GameSessionResult result) {
          debugPrint('[MarketTrip] accuracy=${result.recallAccuracy}, '
              'score=${result.scoreNormalized}');
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

  Future<void> _launchTapTarget(
    BuildContext context,
    SessionService session,
    LocaleService locale,
  ) async {
    // Consume setting for Tap Target and automatically remove all pending settings from SQLite
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

    debugPrint('[GamesScreen] Launching Tap Target at auto-adjusted difficulty: level $level');

    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TapTargetGameScreen(
        difficulty: difficulty,
        promptLanguage: locale.code,
        patientProfileId: session.patientId,
        onGameCompleted: (result) {
          debugPrint('[TapTarget] score=${result.scoreNormalized}, '
              'rt=${result.reactionTimeAvg}ms');
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

  Future<void> _launchPairMatching(
    BuildContext context,
    SessionService session,
    LocaleService locale,
  ) async {
    // Consume setting for Pair Matching and automatically remove all pending settings from SQLite
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

    debugPrint('[GamesScreen] Launching Pair Matching at auto-adjusted difficulty: level $level');

    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PairMatchingGameScreen(
        difficulty: difficulty,
        promptLanguage: locale.code,
        patientProfileId: session.patientId,
        onGameCompleted: (PairMatchingSessionResult result) {
          debugPrint('[PairMatching] flips=${result.totalFlips}, '
              'score=${result.scoreNormalized}, '
              'usedPhotos=${result.usedFaceNameVariant}');
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

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleService>();
    final session = context.watch<SessionService>();
    final s = AppStrings(locale.lang);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 32, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          s.brainGames,
          style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: const VoiceNavButton(size: 64.0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            // ── Market Trip (live) ──────────────────────────────────────────
            _GameCard(
              icon: Icons.shopping_basket_rounded,
              iconColor: AppColors.terracotta,
              title: s.marketTripTitle,
              subtitle: s.marketTripSubtitle,
              domain: s.workingMemory,
              isLive: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _launchMarketTrip(context, session, locale),
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: Text(
                      s.playNow,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.terracotta,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 64),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Tap the Target (live) ───────────────────────────────────────
            _GameCard(
              icon: Icons.touch_app_rounded,
              iconColor: AppColors.terracottaDark,
              title: s.tapTargetTitle,
              subtitle: s.tapTargetSubtitle,
              domain: s.attention,
              isLive: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _launchTapTarget(context, session, locale),
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: Text(
                      s.playNow,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.terracottaDark,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 64),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Pair Matching (live) ─────────────────────────────────────────
            _GameCard(
              icon: Icons.flip_rounded,
              iconColor: AppColors.mugaGold,
              title: s.pairMatchTitle,
              subtitle: s.pairMatchSubtitle,
              domain: s.episodicMemory,
              isLive: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _launchPairMatching(context, session, locale),
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: Text(
                      s.playNow,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mugaGold,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 64),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Coming soon: Family & Village Finder ────────────────────────
            const _GameCard(
              icon: Icons.face_rounded,
              iconColor: AppColors.sageGreen,
              title: 'Family & Village Finder',
              subtitle: 'Recognise family members & objects',
              domain: 'Semantic Memory',
              isLive: false,
              comingSoonLabel: 'Coming soon',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Game Card
// ─────────────────────────────────────────────────────────────────────────────
class _GameCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String domain;
  final bool isLive;
  final String? comingSoonLabel;
  final Widget? child;

  const _GameCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.domain,
    required this.isLive,
    this.comingSoonLabel,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLive ? iconColor.withValues(alpha: 0.4) : AppColors.border,
          width: isLive ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isLive ? iconColor : AppColors.border,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 32, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.inkSoft,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isLive ? iconColor.withValues(alpha: 0.12) : AppColors.cream,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isLive ? iconColor.withValues(alpha: 0.3) : AppColors.border,
                  ),
                ),
                child: Text(
                  isLive ? domain : (comingSoonLabel ?? 'Coming soon'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isLive ? iconColor : AppColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}
