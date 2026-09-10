import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  GameDifficulty _marketDifficulty = GameDifficulty.easy;
  TapDifficulty _tapDifficulty = TapDifficulty.easy;
  PairDifficulty _pairDifficulty = PairDifficulty.easy;

  @override
  void initState() {
    super.initState();
    _checkPendingDifficulty();
  }

  Future<void> _checkPendingDifficulty() async {
    final pending = await DifficultyDatabaseService.instance.peekLatestDifficultySetting();
    if (pending != null && mounted) {
      setState(() {
        if (pending.gameType == 'market_trip' || pending.gameType.isEmpty) {
          if (pending.recommendedDifficulty == 1) _marketDifficulty = GameDifficulty.easy;
          if (pending.recommendedDifficulty == 2) _marketDifficulty = GameDifficulty.medium;
          if (pending.recommendedDifficulty == 3) _marketDifficulty = GameDifficulty.hard;
        }
        if (pending.gameType == 'tap_target' || pending.gameType.isEmpty) {
          if (pending.recommendedDifficulty == 1) _tapDifficulty = TapDifficulty.easy;
          if (pending.recommendedDifficulty == 2) _tapDifficulty = TapDifficulty.medium;
          if (pending.recommendedDifficulty == 3) _tapDifficulty = TapDifficulty.hard;
        }
        if (pending.gameType == 'pair_matching' || pending.gameType.isEmpty) {
          if (pending.recommendedDifficulty == 1) _pairDifficulty = PairDifficulty.easy;
          if (pending.recommendedDifficulty == 2) _pairDifficulty = PairDifficulty.medium;
          if (pending.recommendedDifficulty == 3) _pairDifficulty = PairDifficulty.hard;
        }
      });
      debugPrint('[GamesScreen] Auto-adapted difficulty chips from SQLite: '
          'Market: $_marketDifficulty, Tap: $_tapDifficulty, Pair: $_pairDifficulty');
    }
  }

  Future<void> _launchMarketTrip(
    BuildContext context,
    SessionService session,
    LocaleService locale,
  ) async {
    // Consume setting from SQLite and remove entry
    final pending = await DifficultyDatabaseService.instance
        .consumeLatestDifficultySetting(gameType: 'market_trip');
    if (pending != null) {
      if (pending.recommendedDifficulty == 1) _marketDifficulty = GameDifficulty.easy;
      if (pending.recommendedDifficulty == 2) _marketDifficulty = GameDifficulty.medium;
      if (pending.recommendedDifficulty == 3) _marketDifficulty = GameDifficulty.hard;
      if (mounted) setState(() {});
      debugPrint('[GamesScreen] Consumed and removed SQLite difficulty setting for Market Trip: $_marketDifficulty');
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MarketTripGameScreen(
        difficulty: _marketDifficulty,
        promptLanguage: locale.code,
        patientProfileId: session.patientId,
        onGameCompleted: (GameSessionResult result) {
          debugPrint('[MarketTrip] accuracy=${result.recallAccuracy}, '
              'score=${result.scoreNormalized}');
        },
      ),
    ));

    if (mounted) _checkPendingDifficulty();
  }

  Future<void> _launchTapTarget(
    BuildContext context,
    SessionService session,
    LocaleService locale,
  ) async {
    // Consume setting from SQLite and remove entry
    final pending = await DifficultyDatabaseService.instance
        .consumeLatestDifficultySetting(gameType: 'tap_target');
    if (pending != null) {
      if (pending.recommendedDifficulty == 1) _tapDifficulty = TapDifficulty.easy;
      if (pending.recommendedDifficulty == 2) _tapDifficulty = TapDifficulty.medium;
      if (pending.recommendedDifficulty == 3) _tapDifficulty = TapDifficulty.hard;
      if (mounted) setState(() {});
      debugPrint('[GamesScreen] Consumed and removed SQLite difficulty setting for Tap Target: $_tapDifficulty');
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TapTargetGameScreen(
        difficulty: _tapDifficulty,
        promptLanguage: locale.code,
        patientProfileId: session.patientId,
        onGameCompleted: (result) {
          debugPrint('[TapTarget] score=${result.scoreNormalized}, '
              'rt=${result.reactionTimeAvg}ms');
        },
      ),
    ));

    if (mounted) _checkPendingDifficulty();
  }

  Future<void> _launchPairMatching(
    BuildContext context,
    SessionService session,
    LocaleService locale,
  ) async {
    // Consume setting from SQLite and remove entry
    final pending = await DifficultyDatabaseService.instance
        .consumeLatestDifficultySetting(gameType: 'pair_matching');
    if (pending != null) {
      if (pending.recommendedDifficulty == 1) _pairDifficulty = PairDifficulty.easy;
      if (pending.recommendedDifficulty == 2) _pairDifficulty = PairDifficulty.medium;
      if (pending.recommendedDifficulty == 3) _pairDifficulty = PairDifficulty.hard;
      if (mounted) setState(() {});
      debugPrint('[GamesScreen] Consumed and removed SQLite difficulty setting for Pair Matching: $_pairDifficulty');
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PairMatchingGameScreen(
        difficulty: _pairDifficulty,
        promptLanguage: locale.code,
        patientProfileId: session.patientId,
        onGameCompleted: (PairMatchingSessionResult result) {
          debugPrint('[PairMatching] flips=${result.totalFlips}, '
              'score=${result.scoreNormalized}, '
              'usedPhotos=${result.usedFaceNameVariant}');
        },
      ),
    ));

    if (mounted) _checkPendingDifficulty();
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
                  const SizedBox(height: 12),
                  Text(
                    s.chooseDifficulty,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    _DifficultyChip<GameDifficulty>(
                      label: s.easy, sublabel: s.easyItems,
                      value: GameDifficulty.easy, selected: _marketDifficulty,
                      accentColor: AppColors.terracotta,
                      onTap: (v) => setState(() => _marketDifficulty = v),
                    ),
                    const SizedBox(width: 8),
                    _DifficultyChip<GameDifficulty>(
                      label: s.medium, sublabel: s.mediumItems,
                      value: GameDifficulty.medium, selected: _marketDifficulty,
                      accentColor: AppColors.terracotta,
                      onTap: (v) => setState(() => _marketDifficulty = v),
                    ),
                    const SizedBox(width: 8),
                    _DifficultyChip<GameDifficulty>(
                      label: s.hard, sublabel: s.hardItems,
                      value: GameDifficulty.hard, selected: _marketDifficulty,
                      accentColor: AppColors.terracotta,
                      onTap: (v) => setState(() => _marketDifficulty = v),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _launchMarketTrip(context, session, locale),
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: Text(s.playNow,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                  const SizedBox(height: 12),
                  Text(
                    s.chooseDifficulty,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    _DifficultyChip<TapDifficulty>(
                      label: s.easy, sublabel: s.easyItems,
                      value: TapDifficulty.easy, selected: _tapDifficulty,
                      accentColor: AppColors.terracottaDark,
                      onTap: (v) => setState(() => _tapDifficulty = v),
                    ),
                    const SizedBox(width: 8),
                    _DifficultyChip<TapDifficulty>(
                      label: s.medium, sublabel: s.mediumItems,
                      value: TapDifficulty.medium, selected: _tapDifficulty,
                      accentColor: AppColors.terracottaDark,
                      onTap: (v) => setState(() => _tapDifficulty = v),
                    ),
                    const SizedBox(width: 8),
                    _DifficultyChip<TapDifficulty>(
                      label: s.hard, sublabel: s.hardItems,
                      value: TapDifficulty.hard, selected: _tapDifficulty,
                      accentColor: AppColors.terracottaDark,
                      onTap: (v) => setState(() => _tapDifficulty = v),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _launchTapTarget(context, session, locale),
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: Text(s.playNow,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                  const SizedBox(height: 12),
                  Text(
                    s.chooseDifficulty,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    _DifficultyChip<PairDifficulty>(
                      label: s.easy, sublabel: s.easyPairs,
                      value: PairDifficulty.easy, selected: _pairDifficulty,
                      accentColor: AppColors.mugaGold,
                      onTap: (v) => setState(() => _pairDifficulty = v),
                    ),
                    const SizedBox(width: 8),
                    _DifficultyChip<PairDifficulty>(
                      label: s.medium, sublabel: s.mediumPairs,
                      value: PairDifficulty.medium, selected: _pairDifficulty,
                      accentColor: AppColors.mugaGold,
                      onTap: (v) => setState(() => _pairDifficulty = v),
                    ),
                    const SizedBox(width: 8),
                    _DifficultyChip<PairDifficulty>(
                      label: s.hard, sublabel: s.hardPairs,
                      value: PairDifficulty.hard, selected: _pairDifficulty,
                      accentColor: AppColors.mugaGold,
                      onTap: (v) => setState(() => _pairDifficulty = v),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _launchPairMatching(context, session, locale),
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: Text(s.playNow,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                    Text(title,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.2)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 16, color: AppColors.inkSoft, height: 1.3)),
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

// ─────────────────────────────────────────────────────────────────────────────
// Generic difficulty chip — works for any comparable enum/object.
// ─────────────────────────────────────────────────────────────────────────────
class _DifficultyChip<T> extends StatelessWidget {
  final String label;
  final String sublabel;
  final T value;
  final T selected;
  final Color accentColor;
  final ValueChanged<T> onTap;

  const _DifficultyChip({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? accentColor : AppColors.cream,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? accentColor : AppColors.border,
              width: isSelected ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.ink)),
              const SizedBox(height: 2),
              Text(sublabel,
                  style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppColors.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }
}
