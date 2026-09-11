import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reminder_item.dart';
import '../services/activity_database_service.dart';
import '../services/api_service.dart';
import '../services/app_strings.dart';
import '../services/locale_service.dart';
import '../services/reminder_database_service.dart';
import '../services/session_service.dart';
import '../theme/theme.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<ReminderItem> _reminders = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadLocalRemindersAndFetch();
  }

  /// 1. Immediately loads any previously cached reminders from local SQLite.
  /// 2. Asynchronously requests fresh reminders from backend MongoDB if paired.
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
          _statusMessage = 'Device not paired. Pair your tablet to receive caregiver reminders.';
        });
      }
    }
  }

  /// Sends request to backend, checks if pairing code exists, fetches reminders from MongoDB,
  /// and stores them into the local SQLite database.
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

      // Reload updated records from local SQLite
      final updatedLocal = await ReminderDatabaseService.instance.getReminders(
        pairingCode: pairingCode,
      );

      if (mounted) {
        setState(() {
          _reminders = updatedLocal;
          _isSyncing = false;
          _statusMessage = null;
        });

        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Updated ${_reminders.length} reminders from cloud',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppColors.sageGreen,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[RemindersScreen] Fetch error: $e');
      final errorClean = e.toString().replaceAll('Exception: ', '').trim();
      if (mounted) {
        setState(() {
          _isSyncing = false;
          if (_reminders.isEmpty) {
            _statusMessage = errorClean;
          }
        });

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
    }
  }

  /// Flushes the local SQLite table containing daily reminders.
  Future<void> _clearReminders() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear Reminders?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        content: const Text(
          'This will flush all reminders stored in your local tablet database.',
          style: TextStyle(fontSize: 18, color: AppColors.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 18, color: AppColors.inkSoft, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              foregroundColor: Colors.white,
              minimumSize: const Size(110, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              'Clear',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Flush the local SQLite table
      final deleted = await ReminderDatabaseService.instance.clearReminders();
      debugPrint('[RemindersScreen] Flushed $deleted reminders from local SQLite.');

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

  /// Marks a reminder as done both in memory and persists to SQLite.
  Future<void> _markAsDone(int index) async {
    final item = _reminders[index];
    setState(() {
      item.isCompleted = true;
    });

    try {
      await ReminderDatabaseService.instance.toggleReminderCompleted(item.id, true);
    } catch (e) {
      debugPrint('[RemindersScreen] Error updating reminder completion: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final locale = context.watch<LocaleService>();
    final s = AppStrings(locale.lang);
    final session = context.watch<SessionService>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
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
          // Refresh / Fetch button
          IconButton(
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

          // Clear Reminders button
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: OutlinedButton.icon(
              onPressed: _reminders.isEmpty ? null : _clearReminders,
              icon: const Icon(Icons.delete_sweep_rounded, size: 20, color: AppColors.alertRed),
              label: const Text(
                'Clear Reminders',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.alertRed,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: _reminders.isEmpty ? AppColors.border : AppColors.alertRed.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.terracotta),
              )
            : RefreshIndicator(
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
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        itemCount: _reminders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final item = _reminders[index];
                          return _ReminderCard(
                            item: item,
                            onDone: () => _markAsDone(index),
                          );
                        },
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

class _ReminderCard extends StatelessWidget {
  final ReminderItem item;
  final VoidCallback onDone;

  const _ReminderCard({
    required this.item,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = item.isCompleted;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDone ? AppColors.surface.withValues(alpha: 0.7) : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone ? AppColors.sageGreen.withValues(alpha: 0.5) : AppColors.border,
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
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: isDone
                  ? AppColors.sageGreen.withValues(alpha: 0.2)
                  : item.categoryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              size: 30,
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
                    fontSize: 22,
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
                        fontSize: 18,
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
                            fontSize: 14,
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

          // Action Target: "Done" button or "Completed" badge (Min 44px height)
          if (!isDone)
            ElevatedButton.icon(
              onPressed: onDone,
              icon: const Icon(
                Icons.check_rounded,
                size: 24,
                color: Colors.white,
              ),
              label: const Text(
                'Done',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.terracotta,
                foregroundColor: Colors.white,
                minimumSize: const Size(100, 52),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 1,
              ),
            )
          else
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.sageGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.sageGreen, width: 1.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.sageGreen,
                    size: 24,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.sageGreen,
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
