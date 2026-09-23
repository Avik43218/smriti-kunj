import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/activity_database_service.dart';
import '../services/app_strings.dart';
import '../services/session_service.dart';
import '../theme/theme.dart';

/// Launches the device dialer pre-filled with the target caregiver or emergency contact number.
/// Follows the 5-tier fallback priority chain in [SessionService.activeSosTarget].
Future<bool> launchCaregiverDialer({String? phoneNumber, String? contactName}) async {
  final target = SessionService.instance.activeSosTarget;
  final rawPhone = phoneNumber ?? target.phone;
  final name = contactName ?? (target.name.isNotEmpty ? target.name : 'Caregiver');

  if (rawPhone == null || rawPhone.trim().isEmpty) {
    debugPrint('[SOS] No phone number configured for active SOS target ($name).');
    unawaited(ActivityDatabaseService.instance.recordSosEvent(
      targetName: name,
      targetPhone: null,
      status: 'no_phone_configured',
    ));
    return false;
  }

  // Keep leading '+' and all digits, stripping whitespace, hyphens, and parentheses
  final cleanDigits = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
  final hasPlus = rawPhone.trim().startsWith('+');
  final cleanPhone = hasPlus ? '+$cleanDigits' : cleanDigits;

  if (cleanPhone.isEmpty) {
    debugPrint('[SOS] Phone number is invalid for $name.');
    unawaited(ActivityDatabaseService.instance.recordSosEvent(
      targetName: name,
      targetPhone: rawPhone,
      status: 'invalid_phone_number',
    ));
    return false;
  }

  final telUri = Uri(scheme: 'tel', path: cleanPhone);
  debugPrint('[SOS] Launching device dialer for $name with phone: $cleanPhone');

  try {
    bool launched = false;
    if (await canLaunchUrl(telUri)) {
      launched = await launchUrl(telUri, mode: LaunchMode.externalApplication);
    } else {
      // Direct external attempt as fallback
      launched = await launchUrl(telUri, mode: LaunchMode.externalApplication);
    }

    unawaited(ActivityDatabaseService.instance.recordSosEvent(
      targetName: name,
      targetPhone: cleanPhone,
      status: launched ? 'dialer_launched' : 'dialer_launch_failed',
    ));
    return launched;
  } catch (e) {
    debugPrint('[SOS] Could not launch dialer intent: $e');
    unawaited(ActivityDatabaseService.instance.recordSosEvent(
      targetName: name,
      targetPhone: cleanPhone,
      status: 'dialer_launch_error',
    ));
    return false;
  }
}

/// Backwards-compatible alias for [launchCaregiverDialer].
Future<bool> launchGuardianDialer({String? phoneNumber}) =>
    launchCaregiverDialer(phoneNumber: phoneNumber);

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

    // 1. Immediately launch system dialer pre-filled with caregiver number
    launchCaregiverDialer();

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
    final strings = AppStrings.of(context);
    final caption = label ?? strings.helpButton;

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
/// Shows caregiver / emergency contact information, pre-fills device dialer,
/// supports tablet copy-to-clipboard fallback, and displays a calm empty state if no phone is saved.
class SosConfirmationScreen extends StatefulWidget {
  const SosConfirmationScreen({super.key});

  @override
  State<SosConfirmationScreen> createState() => _SosConfirmationScreenState();
}

class _SosConfirmationScreenState extends State<SosConfirmationScreen> {
  bool _dialerFailed = false;
  bool _copied = false;

  void _copyToClipboard(String phoneNumber, String message) {
    Clipboard.setData(ClipboardData(text: phoneNumber));
    setState(() {
      _copied = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: AppColors.sageGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final strings = AppStrings.of(context);
    final session = SessionService.instance;
    final target = session.activeSosTarget;

    // ── Priority 5: Empty state (No number saved across entire chain) ─────────
    if (target.isEmpty) {
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

                Center(
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: AppColors.terracotta.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.terracotta.withValues(alpha: 0.3),
                        width: 2.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.contact_phone_outlined,
                      size: 54,
                      color: AppColors.terracotta,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  strings.sosEmptyStateTitle,
                  textAlign: TextAlign.center,
                  style: textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    fontSize: 26,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  strings.sosEmptyStateMessage,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                    fontSize: 17,
                    height: 1.4,
                  ),
                ),

                const Spacer(),

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
                  label: Text(
                    strings.sosDismissAction,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    side: BorderSide(
                      color: AppColors.ink.withValues(alpha: 0.25),
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

    // ── Valid SOS Target Screen ──────────────────────────────────────────────
    final targetName = target.name.isNotEmpty ? target.name : strings.caregiverLabel;
    final targetRole = target.isCaregiver ? strings.caregiverLabel : target.relationship;
    final displayPhone = target.formattedPhone ?? target.phone ?? '';
    final rawPhone = target.phone ?? '';

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
                strings.sosScreenTitle,
                textAlign: TextAlign.center,
                style: textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  fontSize: 28,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),

              // Clear subtitle indicating caregiver/contact dialing
              Text(
                target.isCaregiver
                    ? strings.sosCallingCaregiverIntro
                    : strings.sosCallingEmergencyIntro,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),

              // Target Contact Card
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
                            targetName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            targetRole,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            displayPhone,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.terracotta,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Copy button on card for quick access / tablets
                    IconButton(
                      tooltip: strings.sosCopyNumber,
                      onPressed: () => _copyToClipboard(rawPhone, strings.sosNumberCopied),
                      icon: Icon(
                        _copied ? Icons.check_rounded : Icons.copy_rounded,
                        color: _copied ? AppColors.sageGreen : AppColors.inkSoft,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),

              // Tablet fallback card if dialer launch failed
              if (_dialerFailed) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.terracotta.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.terracotta.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        strings.sosTabletNoDialer,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _copyToClipboard(rawPhone, strings.sosNumberCopied),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: Text(
                          strings.sosCopyNumber,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              Text(
                strings.sosStayCalm,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkSoft,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              const Spacer(),

              // Primary Action: Call Target
              ElevatedButton.icon(
                onPressed: () async {
                  final launched = await launchCaregiverDialer(
                    phoneNumber: rawPhone,
                    contactName: targetName,
                  );
                  if (!launched && mounted) {
                    setState(() {
                      _dialerFailed = true;
                    });
                  }
                },
                icon: const Icon(
                  Icons.phone_forwarded_rounded,
                  size: 26,
                  color: Colors.white,
                ),
                label: Text(
                  strings.sosCallAction(targetName),
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
                label: Text(
                  strings.sosDismissAction,
                  style: const TextStyle(
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
