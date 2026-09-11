import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/theme.dart';

class SosButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double size;

  const SosButton({
    super.key,
    this.onPressed,
    this.size = 96.0,
  });

  void _triggerSos(BuildContext context) {
    // 1. Immediately mock-trigger alert (log/print) with zero confirmation friction
    debugPrint('[SOS ALERT] Emergency trigger dispatched at ${DateTime.now().toIso8601String()} for active patient session');

    // 2. Open full-screen "Help is on the way" confirmation screen with auto-dismiss
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SosConfirmationScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Emergency Help Button. Immediately notifies your caregiver.',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.alertRed.withValues(alpha: 0.35),
              blurRadius: 14,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: AppColors.alertRed,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed ?? () => _triggerSos(context),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.phone_in_talk_rounded,
                  color: Colors.white,
                  size: 34,
                ),
                SizedBox(height: 2),
                Text(
                  'Help',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
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

/// Full-screen confirmation displayed immediately upon tapping the SOS button.
/// Auto-dismisses back to Home after a few seconds or when dismissed manually.
class SosConfirmationScreen extends StatefulWidget {
  const SosConfirmationScreen({super.key});

  @override
  State<SosConfirmationScreen> createState() => _SosConfirmationScreenState();
}

class _SosConfirmationScreenState extends State<SosConfirmationScreen> {
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    // Auto-dismiss after 4 seconds
    _autoDismissTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Alert icon badge
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.alertRed.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.alertRed.withValues(alpha: 0.3),
                      width: 2.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    size: 64,
                    color: AppColors.alertRed,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Reassuring title
              Text(
                'Help is on the way',
                textAlign: TextAlign.center,
                style: textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 16),

              // Clear details in reassuring language
              Text(
                'Your caregiver and emergency contacts have been alerted.',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                'Please stay calm and seated. Someone is reaching out to you.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkSoft,
                  height: 1.4,
                ),
              ),

              const Spacer(),

              // Dismiss button (≥ 88dp height target per patient accessibility standard)
              ElevatedButton.icon(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 28,
                  color: Colors.white,
                ),
                label: const Text(
                  'I Understand (Back to Home)',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.terracotta,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 88),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
