import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/reminder_item.dart';
import '../services/activity_database_service.dart';
import '../services/api_service.dart';
import '../services/app_strings.dart';
import '../services/device_alarm_service.dart';
import '../services/locale_service.dart';
import '../services/reminder_database_service.dart';
import '../services/session_service.dart';
import '../theme/theme.dart';
import '../widgets/app_background.dart';

const _kAlarmChannel = MethodChannel('com.smritikunj.patient_app/alarm');

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> with WidgetsBindingObserver {
  List<ReminderItem> _reminders = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _statusMessage;
  bool? _alarmPermsGranted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _kAlarmChannel.setMethodCallHandler(_handleAlarmChannelCall);
    _checkPermissions();
    _loadLocalRemindersAndFetch();
  }

  Future<void> _checkPermissions() async {
    try {
      final res = await _kAlarmChannel.invokeMapMethod<String, dynamic>('checkPermissions');
      final allGranted = res?['allGranted'] as bool? ?? false;
      if (mounted) {
        setState(() => _alarmPermsGranted = allGranted);
      }
      if (!allGranted) {
        // Trigger onboarding flow on first open if permissions are missing
        await _kAlarmChannel.invokeMethod<void>('requestPermissions');
      }
    } catch (e) {
      debugPrint('[RemindersScreen] Error checking permissions: $e');
    }
  }

  Future<void> _handleAlarmChannelCall(MethodCall call) async {
    if (call.method == 'onPermissionsStatus') {
      final allGranted = (call.arguments as Map?)?['allGranted'] as bool? ?? false;
      if (mounted) {
        setState(() => _alarmPermsGranted = allGranted);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
      _loadLocalRemindersAndFetch();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _kAlarmChannel.setMethodCallHandler(null);
    super.dispose();
  }

  /// 1. Loads cached reminders from local SQLite.
  /// 2. Fetches fresh reminders from backend MongoDB if paired.
  Future<void> _loadLocalRemindersAndFetch() async {
    setState(() {
      _isLoading = true;
    });

    final session = Provider.of<SessionService>(context, listen: false);
    String? pairingCode = session.pairingCode;
    pairingCode ??= await ActivityDatabaseService.instance.getActivePairingCode();

    // 1. Load from local SQLite database first
    try {
      final localItems = await ReminderDatabaseService.instance.getReminders(
        pairingCode: pairingCode,
      );
      if (mounted) {
        setState(() {
          _reminders = localItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[RemindersScreen] Error loading local SQLite reminders: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

    // 2. Fetch from backend if pairing code is present
    if (pairingCode != null && pairingCode.trim().isNotEmpty) {
      await _fetchFromBackend(pairingCode.trim(), showFeedback: false);
    } else {
      if (mounted && _reminders.isEmpty) {
        setState(() {
          _statusMessage = 'Device not paired. Pair your device to receive caregiver reminders.';
        });
      }
    }
  }

  /// Sends request to backend, updates local SQLite database, and synchronizes device alarms.
  Future<void> _fetchFromBackend(String pairingCode, {bool showFeedback = true}) async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _statusMessage = null;
    });

    try {
      final remoteItems = await ApiService.instance.fetchPatientReminders(pairingCode);

      // Save into local SQLite database
      await ReminderDatabaseService.instance.saveReminders(remoteItems, pairingCode: pairingCode);

      // Synchronize everyday alarms in the device
      int alarmsScheduled = 0;
      try {
        alarmsScheduled = await DeviceAlarmService.instance.syncRemindersToDeviceAlarms(remoteItems);
      } catch (alarmErr) {
        debugPrint('[RemindersScreen] Error syncing to device alarms: $alarmErr');
      }

      // Reload updated records from local SQLite
      final updatedLocal = await ReminderDatabaseService.instance.getReminders(
        pairingCode: pairingCode,
      );

      if (mounted) {
        setState(() {
          _reminders = updatedLocal;
          _statusMessage = null;
        });

        if (showFeedback) {
          final alarmNotice = alarmsScheduled > 0
              ? ' • $alarmsScheduled everyday alarms set'
              : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Updated ${_reminders.length} reminders from cloud$alarmNotice',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppColors.sageGreen,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[RemindersScreen] Fetch error: $e');
      final errorClean = e.toString().replaceAll('Exception: ', '').trim();
      if (mounted) {
        if (_reminders.isEmpty) {
          setState(() {
            _statusMessage = errorClean;
          });
        }
        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorClean,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppColors.terracotta,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } finally {
      // Guarantees the refresh spinner never gets stuck circling
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  /// Flushes the local SQLite table for reminders.
  Future<void> _clearLocalReminders() async {
    final session = Provider.of<SessionService>(context, listen: false);
    String? pairingCode = session.pairingCode;
    pairingCode ??= await ActivityDatabaseService.instance.getActivePairingCode();

    try {
      await ReminderDatabaseService.instance.clearReminders(pairingCode: pairingCode);
      if (mounted) {
        setState(() {
          _reminders = [];
          _statusMessage = 'All reminders cleared from local storage.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Local reminders flushed successfully.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.terracotta,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[RemindersScreen] Error clearing SQLite table: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final locale = context.watch<LocaleService>();
    final s = AppStrings(locale.lang);
    final session = context.watch<SessionService>();

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 32, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back to Home',
        ),
        title: Text(
          s.reminders,
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        actions: [
          // Refresh / Fetch from Server button
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: _isSyncing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.terracotta,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 28, color: AppColors.terracotta),
              tooltip: 'Fetch Reminders from Server',
              onPressed: _isSyncing
                  ? null
                  : () async {
                      String? code = session.pairingCode;
                      code ??= await ActivityDatabaseService.instance.getActivePairingCode();
                      if (!context.mounted) return;
                      if (code != null && code.isNotEmpty) {
                        await _fetchFromBackend(code, showFeedback: true);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please pair device first to fetch reminders.'),
                            backgroundColor: AppColors.terracotta,
                          ),
                        );
                      }
                    },
            ),
          ),
          // Clear Reminders menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 28, color: AppColors.inkSoft),
            tooltip: 'Options',
            onSelected: (value) {
              if (value == 'clear') {
                _clearLocalReminders();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: AppColors.alertRed, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Clear Local Reminders',
                      style: TextStyle(color: AppColors.alertRed, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.terracotta),
              )
            : Column(
                children: [
                  // Stepwise permission warning banner
                  if (_alarmPermsGranted == false)
                    _AlarmPermBanner(
                      onRetry: () async {
                        await _kAlarmChannel.invokeMethod<void>('requestPermissions');
                      },
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.terracotta,
                      onRefresh: () async {
                        String? code = session.pairingCode;
                        code ??= await ActivityDatabaseService.instance.getActivePairingCode();
                        if (code != null && code.isNotEmpty) {
                          await _fetchFromBackend(code, showFeedback: true);
                        }
                      },
                      child: _reminders.isEmpty
                          ? _buildEmptyState(context, session)
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                              itemCount: _reminders.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final item = _reminders[index];
                                return _ReminderCard(item: item);
                              },
                            ),
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}

  Widget _buildEmptyState(BuildContext context, SessionService session) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.sageGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 56,
                color: AppColors.sageGreen,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Pending Reminders',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _statusMessage ??
                  'No reminders currently in local storage. Rest well or tap below to fetch the latest schedule.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.inkSoft,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _isSyncing
                  ? null
                  : () async {
                      String? code = session.pairingCode;
                      code ??= await ActivityDatabaseService.instance.getActivePairingCode();
                      if (!context.mounted) return;
                      if (code != null && code.isNotEmpty) {
                        await _fetchFromBackend(code, showFeedback: true);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Device is not paired. Please pair first.'),
                            backgroundColor: AppColors.terracotta,
                          ),
                        );
                      }
                    },
              icon: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_download_rounded, size: 24, color: Colors.white),
              label: Text(
                _isSyncing ? 'Fetching...' : 'Fetch Reminders from Server',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.terracotta,
                foregroundColor: Colors.white,
                minimumSize: const Size(260, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Strictly read-only ReminderCard per specifications:
/// - No tap handlers anywhere on the card or badge.
/// - Status badge reflects done, upcoming, or missed from SQLite.
class _ReminderCard extends StatelessWidget {
  final ReminderItem item;

  const _ReminderCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final status = item.status;
    final isDone = item.isCompleted || status == 'done';
    final isMissed = status == 'missed';

    final Color badgeBg;
    final Color badgeBorder;
    final Color badgeFg;
    final IconData badgeIcon;
    final String badgeText;

    if (isDone) {
      badgeBg = AppColors.sageGreen.withValues(alpha: 0.15);
      badgeBorder = AppColors.sageGreen;
      badgeFg = AppColors.sageGreen;
      badgeIcon = Icons.check_circle_rounded;
      badgeText = 'Done';
    } else if (isMissed) {
      badgeBg = AppColors.terracotta.withValues(alpha: 0.15);
      badgeBorder = AppColors.terracotta;
      badgeFg = AppColors.terracotta;
      badgeIcon = Icons.alarm_off_rounded;
      badgeText = 'Missed';
    } else {
      badgeBg = AppColors.mugaGold.withValues(alpha: 0.15);
      badgeBorder = AppColors.mugaGold;
      badgeFg = AppColors.mugaGold;
      badgeIcon = Icons.schedule_rounded;
      badgeText = 'Upcoming';
    }

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDone ? AppColors.surface.withValues(alpha: 0.7) : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone ? AppColors.sageGreen.withValues(alpha: 0.4) : AppColors.border,
          width: isDone ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Category Icon
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: isDone
                  ? AppColors.sageGreen.withValues(alpha: 0.2)
                  : item.categoryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              size: 28,
              color: isDone ? AppColors.sageGreen : item.categoryColor,
            ),
          ),
          const SizedBox(width: 16),

          // Title, Scheduled Time & Dosage
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDone ? AppColors.inkSoft : AppColors.ink,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.inkSoft,
                    decorationThickness: 2,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 18,
                      color: isDone ? AppColors.sageGreen : AppColors.inkSoft,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.time,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: isDone ? AppColors.sageGreen : AppColors.inkSoft,
                      ),
                    ),
                    if (item.dosage != null && item.dosage!.trim().isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.categoryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.dosage!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: item.categoryColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Strictly Read-Only Status Badge
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: badgeBorder, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  badgeIcon,
                  color: badgeFg,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: badgeFg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Persistent (non-nagging) one-line banner shown when alarm permissions are missing.
// ─────────────────────────────────────────────────────────────────────────────
class _AlarmPermBanner extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _AlarmPermBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.mugaGold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.mugaGold.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.mugaGold, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Reminders need permissions to ring. Tap Fix to grant.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.terracotta,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Fix this',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
