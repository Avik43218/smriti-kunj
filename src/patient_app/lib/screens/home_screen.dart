import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/patient_activity.dart';
import '../services/activity_database_service.dart';
import '../services/api_service.dart';
import '../services/app_strings.dart';
import '../services/background_music_service.dart';
import '../services/locale_service.dart';
import '../services/session_service.dart';
import '../theme/theme.dart';
import '../widgets/mute_toggle.dart';
import '../widgets/sos_button.dart';
import '../widgets/voice_nav_button.dart';
import 'games_screen.dart';
import 'memory_gallery_screen.dart';
import 'pairing_screen.dart';
import 'reminders_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    BackgroundMusicService.instance.start();
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top header row: App title + controls (Language toggle + Mute)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.appName,
                                  style: textTheme.displayLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  s.todayActivity,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: AppColors.inkSoft,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Controls: Language dropdown + Top-Right Dropdown Menu (Sound + Logout)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _LanguageDropdown(locale: locale),
                              const SizedBox(width: 8),
                              _HeaderMenuDropdown(session: session),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Main action tiles
                      Expanded(
                        child: Column(
                          children: [
                            // 1. Games
                            Expanded(
                              child: _HomeActionTile(
                                icon: Icons.extension_rounded,
                                iconBgColor: AppColors.terracotta,
                                title: s.brainGames,
                                subtitle: s.brainGamesSubtitle,
                                onTap: () => _navigateTo(const GamesScreen()),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 2. Reminders
                            Expanded(
                              child: _HomeActionTile(
                                icon: Icons.notifications_active_rounded,
                                iconBgColor: AppColors.sageGreen,
                                title: s.reminders,
                                subtitle: s.remindersSubtitle,
                                onTap: () => _navigateTo(const RemindersScreen()),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 3. Memory Gallery
                            Expanded(
                              child: _HomeActionTile(
                                icon: Icons.photo_library_rounded,
                                iconBgColor: AppColors.mugaGold,
                                title: s.memoryGallery,
                                subtitle: s.memoryGallerySubtitle,
                                onTap: () => _navigateTo(const MemoryGalleryScreen()),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),

                  // Floating Sync button — fixed bottom-left (floats above other items, stays only in home screen)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: _FloatingSyncButton(session: session, strings: s),
                  ),

                  // Voice Navigation button — fixed bottom-center
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Center(
                      child: VoiceNavButton(size: 76.0),
                    ),
                  ),

                  // SOS button — fixed bottom-right
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: SosButton(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Language selector dropdown widget — shows full native script names
// ─────────────────────────────────────────────────────────────────────────────
class _LanguageDropdown extends StatelessWidget {
  final LocaleService locale;
  const _LanguageDropdown({required this.locale});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppLang>(
          value: locale.lang,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.terracotta,
            size: 24,
          ),
          dropdownColor: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          elevation: 4,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
          onChanged: (AppLang? newLang) {
            if (newLang != null) {
              locale.setLang(newLang);
            }
          },
          items: AppLang.values.map((AppLang lang) {
            final isSelected = lang == locale.lang;
            return DropdownMenuItem<AppLang>(
              value: lang,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lang.fullLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.terracotta : AppColors.ink,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top-right dropdown menu containing Sound button and Logout button
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderMenuDropdown extends StatelessWidget {
  final SessionService session;

  const _HeaderMenuDropdown({required this.session});

  Future<void> _handleLogout(BuildContext context) async {
    await session.unpair();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PairingScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BackgroundMusicService.instance,
      builder: (context, _) {
        final isMuted = BackgroundMusicService.instance.isMuted;

        return Theme(
          data: Theme.of(context).copyWith(
            popupMenuTheme: PopupMenuThemeData(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: AppColors.border, width: 1.5),
              ),
              elevation: 6,
            ),
          ),
          child: PopupMenuButton<String>(
            tooltip: 'Options',
            offset: const Offset(0, 50),
            onSelected: (value) async {
              if (value == 'sound') {
                BackgroundMusicService.instance.toggleMute();
              } else if (value == 'logout') {
                await _handleLogout(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'sound',
                child: Row(
                  children: [
                    Icon(
                      isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: isMuted ? AppColors.inkSoft : AppColors.terracotta,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isMuted ? 'Sound (Off)' : 'Sound (On)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isMuted ? AppColors.inkSoft : AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: AppColors.terracottaDark,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Log Out',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.terracottaDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.more_vert_rounded,
                    size: 22,
                    color: AppColors.ink,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home action tile (unchanged visually)
// ─────────────────────────────────────────────────────────────────────────────
class _HomeActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeActionTile({
    required this.icon,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title: $subtitle',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 36, color: Colors.white),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: AppColors.inkSoft,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.inkSoft,
                  size: 24,
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
// Floating Sync Button in bottom-left corner of Home Screen
// ─────────────────────────────────────────────────────────────────────────────
class _FloatingSyncButton extends StatefulWidget {
  final SessionService session;
  final AppStrings strings;

  const _FloatingSyncButton({
    required this.session,
    required this.strings,
    // this.size = 88.0,
  });

  @override
  State<_FloatingSyncButton> createState() => _FloatingSyncButtonState();
}

class _FloatingSyncButtonState extends State<_FloatingSyncButton>
    with SingleTickerProviderStateMixin {
  bool _isSyncing = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _performSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    _animController.repeat();

    final activityService = ActivityDatabaseService.instance;
    try {
      // 1. Verify pairing code exists in local SQLite database
      final activeCode = await activityService.getActivePairingCode();
      if (activeCode == null || activeCode.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync failed: No pairing code found in local database. Please pair your device first.'),
            backgroundColor: AppColors.terracottaDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      var pending = await activityService.getUnsyncedActivities();

      // If nothing pending, seed a starter activity so user/evaluator can test right away
      if (pending.isEmpty) {
        await activityService.seedSampleActivityIfEmpty(
          widget.session.patientId,
          pairingCode: widget.session.pairingCode ?? activeCode,
        );
        pending = await activityService.getUnsyncedActivities();
      }

      if (pending.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.strings.allSynced),
            backgroundColor: AppColors.sageGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // 2. The sync system only works if the pairing code associated with the stored game activities exists in the database
      final validToSync = <PatientActivityRecord>[];
      for (final act in pending) {
        final code = act.pairingCode;
        if (code != null && code.isNotEmpty && await activityService.hasPairingCode(code)) {
          validToSync.add(act);
        } else {
          debugPrint(
            '[HomeScreen] Skipping activity ${act.clientSessionId}: associated pairing code ($code) not found in local database.',
          );
        }
      }

      if (validToSync.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync rejected: Stored game activities do not have a matching pairing code in the local database.'),
            backgroundColor: AppColors.terracottaDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // 3. Send only game activities over to MongoDB for the patient matching the local pairing code
      final accepted = await ApiService.instance.syncBatchActivities(
        activities: validToSync,
        token: widget.session.authToken,
        patientId: widget.session.patientId,
        pairingCode: activeCode,
      );

      // CRITICAL REQUIREMENT: Wipe clean transferred activities from SQLite once transferred to MongoDB
      final sessionIds = validToSync.map((a) => a.clientSessionId).toList();
      await activityService.deleteActivities(sessionIds);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${widget.strings.syncSuccess} ($accepted games sent) • ${widget.strings.syncCleaned}',
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
      debugPrint('[HomeScreen] Sync error: $e');
      if (!mounted) return;
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
    } finally {
      if (mounted) {
        _animController.stop();
        _animController.reset();
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ActivityDatabaseService.instance,
      builder: (context, _) {
        return FutureBuilder<int>(
          future: ActivityDatabaseService.instance.getUnsyncedCount(),
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            final buttonColor = count > 0 ? AppColors.terracotta : AppColors.sageGreen;

            const buttonSize = 88.0;
            return Semantics(
              button: true,
              label: '${widget.strings.syncButton}. ${count > 0 ? "$count games ready to sync." : "All synced."}',
              child: SizedBox(
                width: buttonSize,
                height: buttonSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: buttonColor.withValues(alpha: 0.35),
                            blurRadius: 14,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: buttonColor,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _isSyncing ? null : _performSync,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              RotationTransition(
                                turns: _animController,
                                child: const Icon(
                                  Icons.sync_rounded,
                                  size: 34,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.strings.syncButton,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (count > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.ink,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          child: Center(
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
