import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/patient_profile_status.dart';
import '../services/activity_database_service.dart';
import '../services/api_service.dart';
import '../services/app_strings.dart';
import '../services/locale_service.dart';
import '../services/session_service.dart';
import '../theme/theme.dart';

/// Read-only Profile Status screen displaying patient identity, caregiver info,
/// and tap-to-dial emergency contacts with Wi-Fi-only tablet fallback.
class ProfileStatusScreen extends StatefulWidget {
  final PatientProfileStatus? initialStatus;

  const ProfileStatusScreen({
    super.key,
    this.initialStatus,
  });

  @override
  State<ProfileStatusScreen> createState() => _ProfileStatusScreenState();
}

class _ProfileStatusScreenState extends State<ProfileStatusScreen> {
  PatientProfileStatus? _profileStatus;
  bool _isLaunchingDialer = false;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    if (widget.initialStatus != null) {
      _profileStatus = widget.initialStatus;
    } else {
      _loadLocalProfileImmediately();
      _refreshQuietlyInBackground();
    }
  }

  /// Instantly renders profile status from local SQLite / active SessionService.
  /// Zero blocking spinner: UI is populated on first frame.
  Future<void> _loadLocalProfileImmediately() async {
    final session = SessionService.instance;
    final cached = await ActivityDatabaseService.instance.getProfileStatus(
      pairingCode: session.pairingCode,
      patientId: session.patientId,
    );

    if (!mounted) return;

    if (cached != null && !cached.isEmpty) {
      setState(() {
        _profileStatus = cached;
      });
      return;
    }

    // Derive from active SessionService if local SQLite table has no dedicated record yet
    final List<ProfileEmergencyContact> contacts = [];
    if (session.guardianPhone != null && session.guardianPhone!.trim().isNotEmpty) {
      contacts.add(ProfileEmergencyContact(
        type: 'primary',
        name: session.guardianName ?? 'Primary Guardian',
        relationship: session.guardianRelationship ?? 'Primary Contact',
        phone: session.guardianPhone!,
      ));
    }

    final localCaregivers = session.caregivers.isNotEmpty
        ? session.caregivers
        : ((session.caregiverPhone != null || session.guardianPhone != null)
            ? [
                CaregiverContact(
                  name: session.caregiverName ?? session.guardianName ?? 'Caregiver',
                  phone: session.caregiverPhone ?? session.guardianPhone,
                  isPrimary: true,
                ),
              ]
            : (contacts.isNotEmpty
                ? [
                    CaregiverContact(
                      name: contacts.first.name,
                      phone: contacts.first.phone,
                      isPrimary: true,
                    ),
                  ]
                : <CaregiverContact>[]));

    final localFromSession = PatientProfileStatus(
      patientName: session.patientName,
      caregivers: localCaregivers,
      emergencyContacts: contacts,
      lastUpdated: DateTime.now(),
    );

    setState(() {
      _profileStatus = localFromSession;
    });
  }

  /// Quietly attempts background network refresh without blocking the UI.
  Future<void> _refreshQuietlyInBackground() async {
    final session = SessionService.instance;
    try {
      final fresh = await ApiService.instance.fetchPatientProfileStatus(
        pairingCode: session.pairingCode,
        token: session.authToken,
      );
      if (mounted) {
        setState(() {
          _profileStatus = fresh;
        });
      }
    } catch (_) {
      // Offline-first: silent skip if offline
    }
  }

  /// Debounced tap-to-dial handler launching `tel:<normalized_phone>` pre-filled.
  Future<void> _handleDialContact(
    ProfileEmergencyContact contact,
    AppStrings strings,
  ) async {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!).inMilliseconds < 800) {
      return; // Debounce double tap
    }
    _lastTapTime = now;

    if (_isLaunchingDialer) return;
    _isLaunchingDialer = true;

    final normalized = contact.normalizedDialNumber;
    final telUri = Uri(scheme: 'tel', path: normalized);

    try {
      final canLaunch = await canLaunchUrl(telUri);
      if (canLaunch) {
        final launched = await launchUrl(telUri, mode: LaunchMode.externalApplication);
        if (!launched && mounted) {
          _showTabletFallbackDialog(contact, strings);
        }
      } else {
        if (mounted) {
          _showTabletFallbackDialog(contact, strings);
        }
      }
    } catch (_) {
      if (mounted) {
        _showTabletFallbackDialog(contact, strings);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLaunchingDialer = false;
        });
      }
    }
  }

  /// Debounced tap-to-dial handler launching `tel:<normalized_phone>` pre-filled for Caregiver.
  Future<void> _handleDialCaregiver(
    CaregiverContact caregiver,
    AppStrings strings,
  ) async {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!).inMilliseconds < 800) {
      return; // Debounce double tap
    }
    _lastTapTime = now;

    if (_isLaunchingDialer) return;
    _isLaunchingDialer = true;

    final normalized = caregiver.normalizedDialNumber;
    if (normalized == null || normalized.isEmpty) {
      if (mounted) {
        setState(() => _isLaunchingDialer = false);
      }
      return;
    }

    final telUri = Uri(scheme: 'tel', path: normalized);

    try {
      final canLaunch = await canLaunchUrl(telUri);
      if (canLaunch) {
        final launched = await launchUrl(telUri, mode: LaunchMode.externalApplication);
        if (!launched && mounted) {
          _showTabletFallbackDialog(
            ProfileEmergencyContact(
              type: 'primary',
              name: caregiver.name,
              relationship: strings.caregiverLabel,
              phone: normalized,
            ),
            strings,
          );
        }
      } else {
        if (mounted) {
          _showTabletFallbackDialog(
            ProfileEmergencyContact(
              type: 'primary',
              name: caregiver.name,
              relationship: strings.caregiverLabel,
              phone: normalized,
            ),
            strings,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        _showTabletFallbackDialog(
          ProfileEmergencyContact(
            type: 'primary',
            name: caregiver.name,
            relationship: strings.caregiverLabel,
            phone: normalized,
          ),
          strings,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLaunchingDialer = false;
        });
      }
    }
  }

  /// Accessible modal dialog displayed on tablets/devices with no phone app.
  void _showTabletFallbackDialog(
    ProfileEmergencyContact contact,
    AppStrings strings,
  ) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {

        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border, width: 1.5),
          ),
          title: Text(
            contact.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${strings.profileNoDialSupport} ${contact.name}:',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                  color: AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: SelectableText(
                  contact.formattedDisplayNumber,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(100, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                strings.profileClose,
                style: const TextStyle(fontSize: 18, color: AppColors.inkSoft),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.terracotta,
                foregroundColor: Colors.white,
                minimumSize: const Size(160, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.copy_rounded, size: 22),
              label: Text(
                strings.profileCopyNumber,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: contact.normalizedDialNumber));
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        strings.profileNumberCopied,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                      backgroundColor: AppColors.sageGreen,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final locale = context.watch<LocaleService>();
    final strings = AppStrings(locale.lang);

    final status = _profileStatus;
    final isEmpty = status == null || status.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Semantics(
          button: true,
          label: 'Go back to Home',
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 32, color: AppColors.ink),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
          ),
        ),
        title: Text(
          strings.profileStatus,
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ),
      body: SafeArea(
        child: isEmpty
            ? _buildEmptyState(strings)
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. About Me Section
                    _buildAboutMeCard(status.patientName, strings),
                    const SizedBox(height: 16),

                    // 2. My Caregiver Section
                    _buildCaregiverCard(status.caregivers, strings),
                    const SizedBox(height: 16),

                    // 3. Emergency Contacts Section
                    _buildEmergencyContactsSection(status.emergencyContacts, strings),
                    const SizedBox(height: 24),

                    // Last updated indicator
                    if (status.lastUpdated != null) ...[
                      Center(
                        child: Text(
                          '${strings.profileLastUpdated}: ${_formatDate(status.lastUpdated!)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Calm guidance note
                    Center(
                      child: Text(
                        strings.profileAskCaregiver,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  /// Friendly empty state when no patient pairing/data exists yet.
  Widget _buildEmptyState(AppStrings strings) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.mugaGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 38,
                  color: AppColors.mugaGold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                strings.profileEmptyState,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Section 1: About Me card with big prominent patient name and avatar circle.
  Widget _buildAboutMeCard(String patientName, AppStrings strings) {
    final initial = patientName.trim().isNotEmpty
        ? patientName.trim().substring(0, 1).toUpperCase()
        : 'P';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.profileAboutMe,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.terracotta.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.terracotta, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.terracotta,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  patientName.isNotEmpty ? patientName : 'Patient',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Section 2: My Caregiver card. Displays assigned caregivers with phone number, tap-to-dial, or "Not available yet".
  Widget _buildCaregiverCard(List<CaregiverContact> caregivers, AppStrings strings) {
    final session = SessionService.instance;
    final resolvedCaregivers = caregivers.isNotEmpty
        ? caregivers
        : (session.caregivers.isNotEmpty
            ? session.caregivers
            : ((session.caregiverPhone != null || session.guardianPhone != null)
                ? [
                    CaregiverContact(
                      name: session.caregiverName ?? session.guardianName ?? strings.caregiverLabel,
                      phone: session.caregiverPhone ?? session.guardianPhone,
                      isPrimary: true,
                    ),
                  ]
                : <CaregiverContact>[]));

    final hasCaregivers = resolvedCaregivers.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            strings.profileMyCaregiver,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (hasCaregivers)
          ...resolvedCaregivers.map((cg) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildCaregiverTapCard(cg, strings),
              ))
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 24,
                  color: AppColors.inkSoft,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    strings.profileCaregiverNone,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Individual Caregiver Card: ≥ 88dp interactive target with phone display and tap-to-dial trigger.
  Widget _buildCaregiverTapCard(CaregiverContact cg, AppStrings strings) {
    final hasPhone = cg.phone != null && cg.phone!.trim().isNotEmpty;
    final formattedPhone = cg.formattedDisplayNumber ?? cg.phone ?? '';

    return Semantics(
      button: hasPhone,
      label: hasPhone
          ? 'Call Caregiver ${cg.name}. Opens dial pad with number $formattedPhone'
          : 'Caregiver ${cg.name}',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: hasPhone ? () => _handleDialCaregiver(cg, strings) : null,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: const BoxConstraints(minHeight: 88),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.sageGreen.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Sage green phone/caregiver icon circle
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.sageGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_in_talk_rounded,
                    size: 28,
                    color: AppColors.sageGreen,
                  ),
                ),
                const SizedBox(width: 16),

                // Name, Caregiver role badge & phone number
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.sageGreen,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              strings.caregiverLabel,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cg.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hasPhone) ...[
                        const SizedBox(height: 4),
                        Text(
                          formattedPhone,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.touch_app_rounded,
                              size: 18,
                              color: AppColors.sageGreen,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                strings.profileTapToDial,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.sageGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasPhone) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 20,
                    color: AppColors.sageGreen,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Section 3: Emergency Contacts section with cards meeting ≥ 88dp touch target rule.
  Widget _buildEmergencyContactsSection(
    List<ProfileEmergencyContact> contacts,
    AppStrings strings,
  ) {
    if (contacts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            strings.profileEmergencyTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...contacts.map((contact) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildContactTapCard(contact, strings),
            )),
      ],
    );
  }

  /// Individual Emergency Contact Card: ≥ 88dp interactive target with clear dialer trigger.
  Widget _buildContactTapCard(ProfileEmergencyContact contact, AppStrings strings) {
    final isPrimary = contact.isPrimary;
    final badgeLabel = isPrimary ? strings.profilePrimaryBadge : strings.profileAlternativeBadge;
    final badgeColor = isPrimary ? AppColors.terracotta : AppColors.mugaGold;

    return Semantics(
      button: true,
      label: 'Call ${contact.name}, ${contact.relationship}. Opens the dial pad with number ${contact.screenReaderSpokenDigits}',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _handleDialContact(contact, strings),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: const BoxConstraints(minHeight: 88),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPrimary ? AppColors.terracotta.withValues(alpha: 0.5) : AppColors.border,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Phone icon circle
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.phone_in_talk_rounded,
                    size: 28,
                    color: badgeColor,
                  ),
                ),
                const SizedBox(width: 16),

                // Name, relationship & phone number
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badgeLabel,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              contact.relationship,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: AppColors.inkSoft,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        contact.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contact.formattedDisplayNumber,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            size: 18,
                            color: badgeColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              strings.profileTapToDial,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 20,
                  color: AppColors.inkSoft.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
