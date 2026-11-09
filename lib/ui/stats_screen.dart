import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../state/habit_provider.dart';

/// Stats & history for a single habit.
class StatsScreen extends StatefulWidget {
  final Habit habit;
  final HabitProvider provider;

  const StatsScreen({super.key, required this.habit, required this.provider});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<_StatsData> _stats;

  @override
  void initState() {
    super.initState();
    _stats = _loadStats();
  }

  Future<_StatsData> _loadStats() async {
    final today = DateTime.now();
    final provider = widget.provider;
    final results = await Future.wait([
      provider.longestStreakFor(widget.habit.id),
      provider.completionRateFor(widget.habit.id, days: 30),
      provider.completionMapFor(
        widget.habit.id,
        _startOfWeek(today).subtract(const Duration(days: 7 * 11)),
        today,
      ),
      provider.historyFor(widget.habit.id),
    ]);
    return _StatsData(
      longestStreak: results[0] as int,
      completionRate30: results[1] as double,
      completionMap: results[2] as Map<DateTime, bool>,
      historyCount: (results[3] as List).length,
    );
  }

  /// Monday of the week containing [date].
  DateTime _startOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.habit.name)),
      body: FutureBuilder<_StatsData>(
        future: _stats,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load stats: ${snapshot.error}'));
          }
          final data = snapshot.data!;
          final streak = widget.provider.streakFor(widget.habit.id);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  _StatTile(
                    label: 'Current streak',
                    value: '$streak',
                    suffix: streak == 1 ? 'day' : 'days',
                    color: widget.habit.color,
                    icon: Icons.local_fire_department,
                  ),
                  const SizedBox(width: 12),
                  _StatTile(
                    label: 'Longest streak',
                    value: '${data.longestStreak}',
                    suffix: data.longestStreak == 1 ? 'day' : 'days',
                    color: theme.colorScheme.tertiary,
                    icon: Icons.emoji_events_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StatTile(
                label: 'Last 30 days',
                value: '${(data.completionRate30 * 100).round()}',
                suffix: '% completion',
                color: theme.colorScheme.primary,
                icon: Icons.donut_small,
                expanded: true,
              ),
              const SizedBox(height: 12),
              _StatTile(
                label: 'Total days logged',
                value: '${data.historyCount}',
                suffix: data.historyCount == 1 ? 'entry' : 'entries',
                color: theme.colorScheme.secondary,
                icon: Icons.history,
                expanded: true,
              ),
              const SizedBox(height: 24),
              Text('Last 12 weeks', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Heatmap(
                habitColor: widget.habit.color,
                completion: data.completionMap,
                startMonday: _startOfWeek(DateTime.now())
                    .subtract(const Duration(days: 7 * 11)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsData {
  final int longestStreak;
  final double completionRate30;
  final Map<DateTime, bool> completionMap;
  final int historyCount;

  const _StatsData({
    required this.longestStreak,
    required this.completionRate30,
    required this.completionMap,
    required this.historyCount,
  });
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  final Color color;
  final IconData icon;
  final bool expanded;

  const _StatTile({
    required this.label,
    required this.value,
    required this.suffix,
    required this.color,
    required this.icon,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
                Text(suffix, style: theme.textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: card) : Expanded(child: card);
  }
}

/// GitHub-style heatmap: one row per week, 7 cells per column (Mon–Sun).
class Heatmap extends StatelessWidget {
  final Color habitColor;
  final Map<DateTime, bool> completion;
  final DateTime startMonday;

  const Heatmap({
    super.key,
    required this.habitColor,
    required this.completion,
    required this.startMonday,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final emptyColor = theme.colorScheme.surfaceContainerHighest;

    Widget cell(DateTime day) {
      final isFuture = day.isAfter(today);
      final done = !isFuture && (completion[day] ?? false);
      return Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: done ? habitColor : emptyColor.withValues(alpha: isFuture ? 0.3 : 1),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    return SizedBox(
      height: 7 * 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var week = 0; week < 12; week++)
            Expanded(
              child: Column(
                children: [
                  for (var dayOfWeek = 0; dayOfWeek < 7; dayOfWeek++)
                    AspectRatio(
                      aspectRatio: 1,
                      child: cell(startMonday.add(Duration(days: week * 7 + dayOfWeek))),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
