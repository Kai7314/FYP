import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/colors.dart';
import '../../../services/checkin_service.dart';

class CheckinHistoryScreen extends StatelessWidget {
  CheckinHistoryScreen({super.key});

  final checkinService = CheckinService();

  Future<List<Map<String, dynamic>>> _loadCheckins() async {
    return checkinService.getCheckins(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadCheckins(),
      builder: (context, snapshot) {
        final horizontalPadding = MediaQuery.sizeOf(context).width < 360
            ? 14.0
            : 20.0;
        final rows = snapshot.data ?? [];
        final checkedDates = rows
            .map((row) => DateTime.tryParse(row['checkin_time'].toString()))
            .whereType<DateTime>()
            .toList();
        final thisMonth = checkedDates
            .where(
              (date) =>
                  date.month == DateTime.now().month &&
                  date.year == DateTime.now().year,
            )
            .length;
        final rate = checkedDates.isEmpty
            ? 0
            : ((thisMonth / DateTime.now().day) * 100).clamp(0, 100).round();
        final checkedToday = checkedDates.any(
          (date) => DateUtils.isSameDay(date, DateTime.now()),
        );

        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            24,
          ),
          children: [
            const Text(
              'Check-In History',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Your safety activity log',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    color: AppColors.primary,
                    icon: Icons.local_fire_department_outlined,
                    value: '${_streak(checkedDates)}',
                    label: 'Day Streak',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryCard(
                    iconColor: AppColors.accent,
                    icon: Icons.workspace_premium_outlined,
                    value: '$thisMonth',
                    label: 'This Month',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryCard(
                    iconColor: AppColors.blue,
                    icon: Icons.trending_up,
                    value: '$rate%',
                    label: 'Rate',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (snapshot.hasError)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Unable to load check-in history. Please try again later.',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: checkedToday
                      ? AppColors.primarySoft
                      : AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (checkedToday ? AppColors.primary : AppColors.accent)
                        .withValues(alpha: .4),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: checkedToday
                          ? AppColors.primary
                          : AppColors.accent,
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.check_circle_outline),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            checkedToday
                                ? 'Checked in today'
                                : 'Not checked in yet',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            checkedToday
                                ? 'Your daily safety heartbeat is complete.'
                                : 'Go home and pet Oren to check in!',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            _WeekCard(checkedDates: checkedDates),
            const SizedBox(height: 18),
            const _SectionLabel(
              icon: Icons.calendar_month_outlined,
              label: 'RECENT ACTIVITY',
            ),
            const SizedBox(height: 9),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (rows.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No check-ins yet. Pet Oren from Home to begin your history.',
                  ),
                ),
              )
            else
              ...rows.map((row) => _CheckinTile(row: row)),
          ],
        );
      },
    );
  }

  int _streak(List<DateTime> times) {
    final days =
        times
            .map((date) => DateTime(date.year, date.month, date.day))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    if (days.isEmpty) return 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    var result = 0;
    for (final day in days) {
      if (day == cursor ||
          (result == 0 && day == cursor.subtract(const Duration(days: 1)))) {
        result++;
        cursor = day.subtract(const Duration(days: 1));
      }
    }
    return result;
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.value,
    required this.label,
    this.color,
    this.iconColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final foreground = color == null ? AppColors.ink : Colors.white;
    return Container(
      height: 112,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: color == null ? Border.all(color: AppColors.border) : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color == null ? iconColor : Colors.white, size: 21),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color == null ? AppColors.muted : Colors.white,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.checkedDates});

  final List<DateTime> checkedDates;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = today.subtract(Duration(days: today.weekday - 1));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel(icon: Icons.trending_up, label: 'THIS WEEK'),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final dayWidth = constraints.maxWidth / 7;
                final radius = ((dayWidth - 8) / 2)
                    .clamp(12.0, 18.0)
                    .toDouble();

                return Row(
                  children: List.generate(7, (index) {
                    final date = start.add(Duration(days: index));
                    final checked = checkedDates.any(
                      (value) => DateUtils.isSameDay(value, date),
                    );
                    final isToday = DateUtils.isSameDay(date, today);
                    return SizedBox(
                      width: dayWidth,
                      child: Column(
                        children: [
                          Text(
                            DateFormat('E').format(date).substring(0, 1),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 7),
                          CircleAvatar(
                            radius: radius,
                            backgroundColor: checked
                                ? AppColors.primary
                                : isToday
                                ? AppColors.warningSoft
                                : AppColors.surface,
                            foregroundColor: checked
                                ? Colors.white
                                : isToday
                                ? AppColors.accent
                                : AppColors.muted,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${date.day}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckinTile extends StatelessWidget {
  const _CheckinTile({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final time = DateTime.tryParse(row['checkin_time'].toString());
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Card(
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: AppColors.primarySoft,
            child: Icon(Icons.check_circle_outline, color: AppColors.primary),
          ),
          title: Text(
            time == null
                ? 'Recorded check-in'
                : DateFormat('EEE, MMM d').format(time),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule, color: AppColors.muted, size: 14),
                const SizedBox(width: 4),
                Text(
                  time == null ? '--' : DateFormat('h:mm a').format(time),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
