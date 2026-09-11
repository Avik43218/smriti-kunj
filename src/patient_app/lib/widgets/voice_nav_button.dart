import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/speech_recognition_service.dart';
import '../theme/theme.dart';

/// Accessible Voice Navigation toggle button.
/// Pressing it toggles continuous microphone listening ON / OFF without any pop-up menu.
class VoiceNavButton extends StatefulWidget {
  final double size;
  final String? tooltip;
  final VoidCallback? onCustomTap;

  const VoiceNavButton({
    super.key,
    this.size = 76.0,
    this.tooltip,
    this.onCustomTap,
  });

  @override
  State<VoiceNavButton> createState() => _VoiceNavButtonState();
}

class _VoiceNavButtonState extends State<VoiceNavButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SpeechRecognitionService.instance,
      builder: (context, _) {
        final speech = SpeechRecognitionService.instance;
        final isActive = speech.isAlwaysActive;
        if (isActive) {
          if (!_pulseController.isAnimating) {
            _pulseController.repeat(reverse: true);
          }
        } else {
          if (_pulseController.isAnimating) {
            _pulseController.stop();
            _pulseController.reset();
          }
        }
        final buttonColor = isActive ? const Color(0xFF2E6F40) : AppColors.terracotta;
        final size = widget.size;

        return Semantics(
          button: true,
          label: widget.tooltip ??
              (isActive
                  ? 'Voice Navigation: Active and Listening. Tap to pause.'
                  : 'Voice Navigation: Paused. Tap to start listening.'),
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Animated glowing pulse ripple when microphone is active
                if (isActive)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: buttonColor.withValues(alpha: 0.28),
                          ),
                        ),
                      );
                    },
                  ),

                // Primary Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onCustomTap ??
                        () => speech.toggleAlwaysActive(context: context),
                    borderRadius: BorderRadius.circular(size / 2),
                    child: Ink(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: buttonColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: buttonColor.withValues(alpha: isActive ? 0.55 : 0.35),
                            blurRadius: isActive ? 16 : 12,
                            spreadRadius: isActive ? 3 : 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isActive ? Icons.mic_rounded : Icons.mic_none_rounded,
                            size: size * 0.38,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Text(
                                isActive ? 'Active' : 'Voice',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: size * 0.16,
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
              ],
            ),
          ),
        );
      },
    );
  }
}
