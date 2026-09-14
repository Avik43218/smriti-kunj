import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_service.dart';
import '../theme/theme.dart';

/// Cleans a phone number string and launches the system dialer pre-filled with the URI `tel:<cleanNumber>`.
Future<bool> launchGuardianDialer({String? phoneNumber}) async {
  final rawPhone = phoneNumber ??
      SessionService.instance.guardianPhone ??
      SessionService.instance.emergencyContact?['phone']?.toString() ??
      '+91 98765 43210';

  // Keep leading '+' and all digits, stripping whitespace, hyphens, and parenthesis
  final cleanDigits = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
  final hasPlus = rawPhone.trim().startsWith('+');
  final cleanPhone = hasPlus ? '+$cleanDigits' : cleanDigits;

  final telUri = Uri(scheme: 'tel', path: cleanPhone);
  debugPrint('[SOS] Launching device dialer with guardian phone: $cleanPhone');

  try {
    if (await canLaunchUrl(telUri)) {
      return await launchUrl(telUri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback direct attempt
      return await launchUrl(telUri, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    debugPrint('[SOS] Could not launch dialer intent: $e');
    return false;
  }
}

class SosButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double size;
  final String? label;

  const SosButton({
    super.key,
    this.onPressed,
    this.size = 80.0,
    this.label,
  });

  void _triggerSos(BuildContext context) {
    debugPrint('[SOS ALERT] Emergency trigger dispatched at ${DateTime.now().toIso8601String()} for active patient session');

    // 1. Immediately launch system dialer pre-filled with guardian number
    launchGuardianDialer();

    // 2. Open full-screen confirmation screen with contact details and fallback dial action
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SosConfirmationScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final caption = label ?? 'Help';
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
              spreadRadius: 1,
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.phone_in_talk_rounded,
                  color: Colors.white,
                  size: size * 0.38,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      caption,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size * 0.18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
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
/// Shows guardian contact information, pre-fills device dialer, and provides quick call retry.
class SosConfirmationScreen extends StatefulWidget {
  const SosConfirmationScreen({super.key});

  @override
  State<SosConfirmationScreen> createState() => _SosConfirmationScreenState();
}

class _SosConfirmationScreenState extends State<SosConfirmationScreen> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final session = SessionService.instance;

    final guardianName = session.guardianName ??
        session.emergencyContact?['name']?.toString() ??
        'Primary Guardian';
    final guardianRelationship = session.guardianRelationship ??
        session.emergencyContact?['relationship']?.toString() ??
        'Emergency Contact';
    final guardianPhone = session.guardianPhone ??
        session.emergencyContact?['phone']?.toString() ??
        '+91 98765 43210';

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Alert icon badge
              Center(
                child: Container(
                  width: 104,
                  height: 104,
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
                    size: 54,
                    color: AppColors.alertRed,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Reassuring title
              Text(
                'Help is on the way',
                textAlign: TextAlign.center,
                style: textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  fontSize: 28,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),

              // Clear details in reassuring language
              Text(
                'Opening your phone dialer to reach your emergency contact.',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),

              // Guardian Contact Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.terracotta.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.alertRed.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.phone_in_talk_rounded,
                        color: AppColors.alertRed,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            guardianName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            guardianRelationship,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            guardianPhone,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.terracotta,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Please stay calm and seated. Someone is reaching out to you.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkSoft,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              const Spacer(),

              // Primary Action: Open Phone Dialer Again
              ElevatedButton.icon(
                onPressed: () => launchGuardianDialer(phoneNumber: guardianPhone),
                icon: const Icon(
                  Icons.phone_forwarded_rounded,
                  size: 26,
                  color: Colors.white,
                ),
                label: Text(
                  'Call $guardianName',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.alertRed,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 72),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 3,
                ),
              ),

              const SizedBox(height: 12),

              // Secondary Dismiss Action (Back to Home)
              OutlinedButton.icon(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 24,
                  color: AppColors.ink,
                ),
                label: const Text(
                  'I Understand (Back to Home)',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  side: BorderSide(
                    color: AppColors.ink.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                  minimumSize: const Size(double.infinity, 64),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
