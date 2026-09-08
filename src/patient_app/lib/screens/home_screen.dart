import 'package:flutter/material.dart';
import '../services/background_music_service.dart';
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
    // Start ambient background music per app scaffold decision
    BackgroundMusicService.instance.start();
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      // Top header row: App title + Mute toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Smriti Setu',
                                  style: textTheme.displayLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Today\'s Activities',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: AppColors.inkSoft,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const MuteToggle(),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Main action tiles: Games, Reminders, Memory Gallery
                      Expanded(
                        child: Column(
                          children: [
                            // 1. Games Tile
                            Expanded(
                              child: _HomeActionTile(
                                icon: Icons.extension_rounded,
                                iconBgColor: AppColors.terracotta,
                                title: 'Brain Games',
                                subtitle: 'Play matching & word games',
                                onTap: () => _navigateTo(const GamesScreen()),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 2. Reminders Tile
                            Expanded(
                              child: _HomeActionTile(
                                icon: Icons.notifications_active_rounded,
                                iconBgColor: AppColors.sageGreen,
                                title: 'Daily Reminders',
                                subtitle: 'Medicines, hydration & routine',
                                onTap: () => _navigateTo(const RemindersScreen()),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 3. Memory Gallery Tile
                            Expanded(
                              child: _HomeActionTile(
                                icon: Icons.photo_library_rounded,
                                iconBgColor: AppColors.mugaGold,
                                title: 'Memory Gallery',
                                subtitle: 'Family photos & voice notes',
                                onTap: () => _navigateTo(const MemoryGalleryScreen()),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),

                  // Fixed Position SOS Button in bottom-right corner
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
                // Icon circle with distinctive category accent color
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 18),

                // Text labels (Recognition over recall)
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

                // Right arrow forward affordance
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
