import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../games/shared/services/game_session_repository.dart';
import '../models/patient_activity.dart';
import '../services/activity_database_service.dart';
import '../services/api_service.dart';
import '../services/app_strings.dart';
import '../services/background_music_service.dart';
import '../services/locale_service.dart';
import '../services/session_service.dart';
import '../theme/theme.dart';
import '../widgets/app_background.dart';
import '../widgets/sos_button.dart';
import '../widgets/voice_nav_button.dart';
import 'games_screen.dart';
import 'memory_gallery_screen.dart';
import 'pairing_screen.dart';
import 'profile_status_screen.dart';
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

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        bottomNavigationBar: _PatientBottomNavBar(session: session, strings: s),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Top Brand row: Logo + App Name (Full width)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/images/logo.svg',
                      width: 44,
                      height: 44,
                      semanticsLabel: 'Smriti Kunj logo',
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s.appName,
                        style: textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 2. Sub-header row: Today's Activities text + Language dropdown & options menu
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        s.todayActivity,
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 22,
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                const SizedBox(height: 12),

                // Main action tiles (Proportionally distributed)
                Expanded(
                  child: Column(
                    children: [
                      // 1. Brain Games
                      Expanded(
                        child: _HomeActionTile(
                          icon: Icons.extension_rounded,
                          iconBgColor: AppColors.terracotta,
                          title: s.brainGames,
                          subtitle: s.brainGamesSubtitle,
                          onTap: () => _navigateTo(const GamesScreen()),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2. Daily Reminders
                      Expanded(
                        child: _HomeActionTile(
                          icon: Icons.notifications_active_rounded,
                          iconBgColor: AppColors.sageGreen,
                          title: s.reminders,
                          subtitle: s.remindersSubtitle,
                          onTap: () => _navigateTo(const RemindersScreen()),
                        ),
                      ),
                      const SizedBox(height: 12),

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
              ],
            ),
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
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
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
            fontSize: 18,
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
                      fontSize: 18,
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
    final strings = AppStrings(context.watch<LocaleService>().lang);

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
          if (value == 'profile_status') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileStatusScreen()),
            );
          } else if (value == 'logout') {
            await _handleLogout(context);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'profile_status',
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: AppColors.terracotta,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    strings.profileStatus,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
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
                      fontSize: 18,
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

              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.more_vert_rounded,
                    size: 24,
                    color: AppColors.ink,
                  ),
                ],
              ),
            ),
          ),
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
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10.0),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 34, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
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
                      const SizedBox(height: 3),
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
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.inkSoft,
                  size: 22,
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
// Dedicated Bottom Navigation Bar for Sync, Voice, and Help
// ─────────────────────────────────────────────────────────────────────────────
class _PatientBottomNavBar extends StatelessWidget {
  final SessionService session;
  final AppStrings strings;

  const _PatientBottomNavBar({
    required this.session,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavBarSyncButton(
              session: session,
              strings: strings,
              size: 80.0,
            ),
            VoiceNavButton(
              size: 80.0,
              inactiveLabel: strings.voiceButton,
              activeLabel: strings.voiceButton,
            ),
            SosButton(
              size: 80.0,
              label: strings.helpButton,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sync Button for Patient Bottom Navigation Bar
// ─────────────────────────────────────────────────────────────────────────────
class _NavBarSyncButton extends StatefulWidget {
  final SessionService session;
  final AppStrings strings;
  final double size;

  const _NavBarSyncButton({
    required this.session,
    required this.strings,
    this.size = 80.0,
  });

  @override
  State<_NavBarSyncButton> createState() => _NavBarSyncButtonState();
}

class _NavBarSyncButtonState extends State<_NavBarSyncButton>
    with SingleTickerProviderStateMixin {
  bool _isSyncing = false;
  late AnimationController _animController;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _count = ActivityDatabaseService.instance.cachedUnsyncedCount;
    ActivityDatabaseService.instance.addListener(_onDatabaseChanged);
    _refreshCount();
  }

  @override
  void dispose() {
    ActivityDatabaseService.instance.removeListener(_onDatabaseChanged);
    _animController.dispose();
    super.dispose();
  }

  void _onDatabaseChanged() {
    if (mounted) {
      setState(() {
        _count = ActivityDatabaseService.instance.cachedUnsyncedCount;
      });
      _refreshCount();
    }
  }

  Future<void> _refreshCount() async {
    final count = await ActivityDatabaseService.instance.getUnsyncedCount();
    if (mounted && _count != count) {
      setState(() {
        _count = count;
      });
    }
  }

  Future<void> _performSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    _animController.repeat();

    final activityService = ActivityDatabaseService.instance;
    try {
      // 1. First check whether the backend is reachable or not
      final isAvailable = await ApiService.instance.isBackendReachable();
      if (!isAvailable) {
        debugPrint('[HomeScreen] Backend unreachable. Sync aborted, local data preserved.');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.cloud_off_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Saved locally on device. Will sync once backend is reachable.'),
                ),
              ],
            ),
            backgroundColor: AppColors.terracotta,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // 2. Verify pairing code exists in local SQLite database
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

      // 3. Query pending activities waiting for sync (without auto-seeding dummy data)
      final pending = await activityService.getUnsyncedActivities();

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

      // 4. Validate activities matching local pairing code
      final validToSync = <PatientActivityRecord>[];
      for (final act in pending) {
        final code = act.pairingCode;
        if (code != null && code.isNotEmpty && await activityService.hasPairingCode(code)) {
          validToSync.add(act);
        } else if (code == null || code.isEmpty) {
          validToSync.add(act.copyWith(pairingCode: activeCode));
        } else if (code.toUpperCase() == activeCode.toUpperCase()) {
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

      // 5. Send only game activities over to MongoDB for the patient matching the local pairing code
      final accepted = await ApiService.instance.syncBatchActivities(
        activities: validToSync,
        token: widget.session.authToken,
        patientId: widget.session.patientId,
        pairingCode: activeCode,
      );

      // 6. Flush the local SQLite database now that backend received data
      await activityService.wipeCleanAllActivities();
      await GameSessionRepository.instance.clearAllSessions();

      if (mounted) {
        setState(() {
          _count = 0;
        });
      }

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
                child: Text('Saved locally on device. Will sync once backend is reachable.'),
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
    final count = _count;
    final buttonColor = count > 0 ? AppColors.terracotta : AppColors.sageGreen;
    final buttonSize = widget.size;

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
                    spreadRadius: 1,
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
                        child: Icon(
                          Icons.sync_rounded,
                          size: buttonSize * 0.38,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            widget.strings.syncButton,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: buttonSize * 0.16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
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
  }
}
