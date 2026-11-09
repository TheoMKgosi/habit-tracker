import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../state/habit_provider.dart';
import 'habit_form.dart';
import 'stats_screen.dart';

/// Today's view: list of habit cards with quick actions.
class HomeScreen extends StatefulWidget {
  final HabitProvider provider;

  const HomeScreen({super.key, required this.provider});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    widget.provider.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        final habits = widget.provider.habits;
        final done = widget.provider.completedToday;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Habit Tracker'),
          ),
          body: !widget.provider.loaded
              ? const Center(child: CircularProgressIndicator())
              : habits.isEmpty
                  ? _EmptyState(onAdd: _openAddForm)
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _TodayHeader(
                          date: DateTime.now(),
                          done: done,
                          total: habits.length,
                        ),
                        const SizedBox(height: 12),
                        for (final habit in habits)
                          _HabitCard(
                            habit: habit,
                            provider: widget.provider,
                            onOpenStats: () => _openStats(habit),
                            onEdit: () => _openEditForm(habit),
                            onDelete: () => _confirmDelete(habit),
                          ),
                      ],
                    ),
          floatingActionButton: FloatingActionButton(
            onPressed: _openAddForm,
            tooltip: 'Add habit',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Future<void> _openAddForm() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => HabitForm(provider: widget.provider),
    );
  }

  Future<void> _openEditForm(Habit habit) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => HabitForm(provider: widget.provider, existing: habit),
    );
  }

  void _openStats(Habit habit) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StatsScreen(habit: habit, provider: widget.provider),
    ));
  }

  Future<void> _confirmDelete(Habit habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete habit?'),
        content: Text('"${habit.name}" and all its history will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.provider.deleteHabit(habit.id);
    }
  }
}

class _TodayHeader extends StatelessWidget {
  final DateTime date;
  final int done;
  final int total;

  const _TodayHeader({required this.date, required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = total == 0 ? 0.0 : done / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_formatDate(date), style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          total == 0 ? 'No habits yet' : '$done of $total completed today',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: total == 0 ? 0 : progress, minHeight: 6, borderRadius: BorderRadius.circular(3)),
      ],
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.track_changes, size: 72, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('No habits yet', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first habit',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add a habit')),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final Habit habit;
  final HabitProvider provider;
  final VoidCallback onOpenStats;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HabitCard({
    required this.habit,
    required this.provider,
    required this.onOpenStats,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = provider.entryFor(habit.id);
    final complete = habit.isEntryComplete(entry);
    final streak = provider.streakFor(habit.id);
    final color = habit.color;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: complete ? color : theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpenStats,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(habit.icon, color: color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(habit.name, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          _subtitle(streak),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'), contentPadding: EdgeInsets.zero, dense: true)),
                      PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete'), contentPadding: EdgeInsets.zero, dense: true)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (habit.type == HabitType.checkoff)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: complete ? color : theme.colorScheme.surfaceContainerHighest,
                      foregroundColor: complete ? Colors.white : theme.colorScheme.onSurface,
                    ),
                    onPressed: () => provider.toggleCheckoff(habit.id),
                    icon: Icon(complete ? Icons.check_circle : Icons.circle_outlined, size: 18),
                    label: Text(complete ? 'Done today' : 'Mark done'),
                  ),
                )
              else
                _QuantifiedControls(habit: habit, entry: entry, provider: provider),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(int streak) {
    if (streak > 0) {
      return streak == 1 ? '1 day streak' : '$streak day streak';
    }
    return 'No streak yet';
  }
}

class _QuantifiedControls extends StatelessWidget {
  final Habit habit;
  final HabitEntryData entry;
  final HabitProvider provider;

  const _QuantifiedControls({required this.habit, required this.entry, required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = habit.target ?? 1;
    final progress = (entry.value / target).clamp(0.0, 1.0);
    final complete = habit.isEntryComplete(entry);

    return Row(
      children: [
        IconButton(
          onPressed: () => provider.adjustValue(habit.id, -1),
          icon: const Icon(Icons.remove_circle_outline),
          tooltip: 'Decrease',
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${entry.value.toStringAsFixed(entry.value == entry.value.roundToDouble() ? 0 : 1)} / ${target.toStringAsFixed(target == target.roundToDouble() ? 0 : 1)} ${habit.unit ?? ''}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
                color: complete ? habit.color : theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => provider.adjustValue(habit.id, 1),
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'Increase',
        ),
      ],
    );
  }
}
