import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_recommendation.dart';
import '../models/patient_activity.dart';
import '../services/activity_database_service.dart';
import '../services/app_strings.dart';
import '../services/difficulty_database_service.dart';
import '../services/game_personalization_service.dart';
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

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  GameRecommendation? _recommendation;
  bool _isLoadingRecommendation = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPersonalization();
    });
  }

  Future<void> _loadPersonalization() async {
    if (!mounted) return;
    final session = context.read<SessionService>();
    try {
      final rec = await GamePersonalizationService.instance.getNextRecommendedGame(
        diagnosisInfo: session.diagnosisInfo,
        pairingCode: session.pairingCode,
      );
      if (mounted) {
        setState(() {
          _recommendation = rec;
          _isLoadingRecommendation = false;
        });
      }
    } catch (e) {
      debugPrint('[GamesScreen] Error loading personalization: $e');
      if (mounted) {
        setState(() => _isLoadingRecommendation = false);
      }
    }
  }

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

    // Reload recommendation with fresh performance telemetry
    _loadPersonalization();
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

    // Reload recommendation with fresh performance telemetry
    _loadPersonalization();
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

    // Reload recommendation with fresh performance telemetry
    _loadPersonalization();
  }

  Future<void> _launchRecommendedGame(
    BuildContext context,
    SessionService session,
    LocaleService locale,
    String gameType,
  ) async {
    switch (gameType) {
      case 'market_trip':
        await _launchMarketTrip(context, session, locale);
        break;
      case 'tap_target':
        await _launchTapTarget(context, session, locale);
        break;
      case 'pair_matching':
      default:
        await _launchPairMatching(context, session, locale);
        break;
    }
  }

  Widget _buildRecommendationCard(
    BuildContext context,
    GameRecommendation rec,
    AppStrings s,
    SessionService session,
    LocaleService locale,
  ) {
    final icon = switch (rec.gameType) {
      'market_trip' => Icons.shopping_basket_rounded,
      'tap_target' => Icons.touch_app_rounded,
      _ => Icons.flip_rounded,
    };
    final cardColor = switch (rec.gameType) {
      'market_trip' => AppColors.terracotta,
      'tap_target' => AppColors.terracottaDark,
      _ => AppColors.mugaGold,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.sageGreen,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.sageGreen.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top header row: Recommendation badge + Priority pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.sageGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.sageGreen, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars_rounded, size: 22, color: AppColors.sageGreen),
                    const SizedBox(width: 6),
                    Text(
                      s.recommendedForYou,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.sageGreen,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: Text(
                    '${s.diagnosisPriorityLabel}: #${rec.priorityNumber}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Clinical diagnosis display
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.medical_information_outlined, size: 24, color: AppColors.inkSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rec.diagnosisName,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Game presentation: Icon + Title + Domain badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, size: 36, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec.gameTitle,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cardColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        rec.domain,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: cardColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Clinical rationale note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.insights_rounded, size: 24, color: AppColors.sageGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rec.clinicalRationale,
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.inkSoft,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Play Recommended Game (>= 88dp touch target)
          ElevatedButton.icon(
            onPressed: () => _launchRecommendedGame(context, session, locale, rec.gameType),
            icon: const Icon(Icons.play_circle_filled_rounded, size: 36),
            label: Text(
              s.playRecommended,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sageGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 88),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
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
      floatingActionButton: const VoiceNavButton(size: 88.0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            // ── Personalized Game Recommendation ──────────────────────────
            if (!_isLoadingRecommendation && _recommendation != null) ...[
              _buildRecommendationCard(context, _recommendation!, s, session, locale),
              Row(
                children: [
                  const Icon(Icons.grid_view_rounded, size: 24, color: AppColors.ink),
                  const SizedBox(width: 8),
                  Text(
                    s.allGames,
                    style: textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

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
          // Row 1: icon + title + subtitle
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        color: AppColors.inkSoft,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Row 2: domain tag badge
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isLive ? iconColor : AppColors.inkSoft,
                ),
              ),
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}
