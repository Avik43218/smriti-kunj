import 'package:flutter/material.dart';
import '../services/background_music_service.dart';
import '../theme/theme.dart';

class MuteToggle extends StatelessWidget {
  const MuteToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BackgroundMusicService.instance,
      builder: (context, _) {
        final isMuted = BackgroundMusicService.instance.isMuted;

        return Semantics(
          button: true,
          label: isMuted ? 'Unmute background sounds' : 'Mute background sounds',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                BackgroundMusicService.instance.toggleMute();
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      size: 22,
                      color: isMuted ? AppColors.inkSoft : AppColors.terracotta,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isMuted ? 'Muted' : 'Sound On',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: isMuted ? AppColors.inkSoft : AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
