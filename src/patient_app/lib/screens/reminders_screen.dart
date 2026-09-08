import 'package:flutter/material.dart';
import '../theme/theme.dart';

class ReminderItem {
  final String id;
  final String title;
  final String time;
  final IconData icon;
  final Color categoryColor;
  bool isCompleted;

  ReminderItem({
    required this.id,
    required this.title,
    required this.time,
    required this.icon,
    required this.categoryColor,
    this.isCompleted = false,
  });
}

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  // Mock data for today's reminders
  late final List<ReminderItem> _reminders;

  @override
  void initState() {
    super.initState();
    _reminders = [
      ReminderItem(
        id: 'rem_1',
        title: 'Morning Medicine',
        time: '8:00 AM',
        icon: Icons.medication_rounded,
        categoryColor: AppColors.terracotta,
        isCompleted: false,
      ),
      ReminderItem(
        id: 'rem_2',
        title: 'Glass of Warm Water',
        time: '10:30 AM',
        icon: Icons.water_drop_rounded,
        categoryColor: AppColors.mugaGold,
        isCompleted: false,
      ),
      ReminderItem(
        id: 'rem_3',
        title: 'Lunch & Fresh Fruits',
        time: '1:00 PM',
        icon: Icons.restaurant_rounded,
        categoryColor: AppColors.sageGreen,
        isCompleted: false,
      ),
      ReminderItem(
        id: 'rem_4',
        title: 'Evening Walk & Stretch',
        time: '5:00 PM',
        icon: Icons.directions_walk_rounded,
        categoryColor: AppColors.terracotta,
        isCompleted: false,
      ),
    ];
  }

  void _markAsDone(int index) {
    setState(() {
      _reminders[index].isCompleted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
          'Today\'s Reminders',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ),
      body: SafeArea(
        child: _reminders.isEmpty
            ? _buildEmptyState(context)
            : ListView.separated(
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
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
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
              'All Caught Up!',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No pending reminders for today. Rest well and have a wonderful day.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.inkSoft,
                height: 1.4,
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

          // Title & Scheduled Time
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
