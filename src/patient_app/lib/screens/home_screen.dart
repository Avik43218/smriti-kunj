import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_strings.dart';
import '../services/background_music_service.dart';
import '../services/locale_service.dart';
import '../theme/theme.dart';
import '../widgets/mute_toggle.dart';
import '../widgets/sos_button.dart';
import 'games_screen.dart';
import 'memory_gallery_screen.dart';
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
                          // Language toggle + Mute
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _LangToggle(locale: locale),
                              const SizedBox(width: 8),
                              const MuteToggle(),
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
// Language toggle widget — two pill chips: EN | অ
// ─────────────────────────────────────────────────────────────────────────────
class _LangToggle extends StatelessWidget {
  final LocaleService locale;
  const _LangToggle({required this.locale});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LangChip(
            label: AppLang.english.label,
            selected: locale.lang == AppLang.english,
            onTap: () => locale.setLang(AppLang.english),
          ),
          _LangChip(
            label: AppLang.assamese.label,
            selected: locale.lang == AppLang.assamese,
            onTap: () => locale.setLang(AppLang.assamese),
          ),
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: selected ? AppColors.terracotta : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.inkSoft,
              ),
            ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
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
