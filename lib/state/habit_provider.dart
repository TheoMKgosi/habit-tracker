import 'package:flutter/foundation.dart';

import '../models/habit.dart';
import '../services/habit_repository.dart';

/// Central state for the app: habits + today's entries, cached stats.
class HabitProvider extends ChangeNotifier {
  final HabitRepository _repository;

  List<Habit> _habits = [];
  final Map<String, HabitEntryData> _todayEntries = {};
  final Map<String, int> _streaks = {};

  bool _loaded = false;

  HabitProvider(this._repository);

  List<Habit> get habits => List.unmodifiable(_habits);
  bool get loaded => _loaded;

  /// Today's entry for a habit (blank entry if none yet).
  HabitEntryData entryFor(String habitId) {
    final t = _todayEntries[habitId];
    if (t != null) return t;
    return HabitEntryData(
      habitId: habitId,
      date: DateTime.now(),
      completed: false,
      value: 0,
    );
  }

  int streakFor(String habitId) => _streaks[habitId] ?? 0;

  /// How many habits are completed today.
  int get completedToday {
    var count = 0;
    for (final habit in _habits) {
      final entry = _todayEntries[habit.id];
      if (entry != null && habit.isEntryComplete(entry)) count++;
    }
    return count;
  }

  Future<void> load({bool includeArchived = false}) async {
    final today = DateTime.now();
    _habits = await _repository.getHabits(includeArchived: includeArchived);
    _todayEntries.clear();
    _streaks.clear();
    for (final habit in _habits) {
      final entry = await _repository.todayEntry(habit, today);
      _todayEntries[habit.id] = entry;
      _streaks[habit.id] = await _repository.currentStreak(habit, today);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> addHabit(Habit habit) async {
    await _repository.insertHabit(habit);
    await load();
  }

  Future<void> updateHabit(Habit habit) async {
    await _repository.updateHabit(habit);
    await load();
  }

  Future<void> deleteHabit(String id) async {
    await _repository.deleteHabit(id);
    await load();
  }

  /// Check-off habit: toggle today's completion.
  Future<void> toggleCheckoff(String habitId) async {
    final habit = _habits.where((h) => h.id == habitId).firstOrNull;
    if (habit == null || habit.type != HabitType.checkoff) return;
    final entry = entryFor(habitId);
    await _repository.upsertEntry(entry.copyWith(completed: !entry.completed));
    await _refreshHabit(habit);
  }

  /// Quantified habit: add [delta] to today's value, clamped at >= 0.
  Future<void> adjustValue(String habitId, double delta) async {
    final habit = _habits.where((h) => h.id == habitId).firstOrNull;
    if (habit == null || habit.type != HabitType.quantified) return;
    final entry = entryFor(habitId);
    final newValue = (entry.value + delta).clamp(0, double.infinity).toDouble();
    await _repository.upsertEntry(entry.copyWith(value: newValue));
    await _refreshHabit(habit);
  }

  /// Set the exact value for a quantified habit.
  Future<void> setValue(String habitId, double value) async {
    final habit = _habits.where((h) => h.id == habitId).firstOrNull;
    if (habit == null || habit.type != HabitType.quantified) return;
    final entry = entryFor(habitId);
    await _repository.upsertEntry(entry.copyWith(value: value.clamp(0, double.infinity).toDouble()));
    await _refreshHabit(habit);
  }

  Future<void> _refreshHabit(Habit habit) async {
    final today = DateTime.now();
    _todayEntries[habit.id] = await _repository.todayEntry(habit, today);
    _streaks[habit.id] = await _repository.currentStreak(habit, today);
    notifyListeners();
  }

  /// Full history for the stats screen.
  Future<List<HabitEntryData>> historyFor(String habitId) {
    return _repository.getEntriesForHabit(habitId);
  }

  Future<int> longestStreakFor(String habitId) async {
    final habit = _habits.where((h) => h.id == habitId).firstOrNull;
    if (habit == null) return 0;
    return _repository.longestStreak(habit);
  }

  Future<double> completionRateFor(String habitId, {int days = 30}) async {
    final habit = _habits.where((h) => h.id == habitId).firstOrNull;
    if (habit == null) return 0;
    return _repository.completionRate(habit, DateTime.now(), days: days);
  }

  /// Day-by-day completion for a heatmap between two dates.
  Future<Map<DateTime, bool>> completionMapFor(
    String habitId,
    DateTime start,
    DateTime end,
  ) async {
    final habit = _habits.where((h) => h.id == habitId).firstOrNull;
    if (habit == null) return {};
    final entries = await _repository.entriesBetween(habitId, start, end);
    final result = <DateTime, bool>{};
    var day = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!day.isAfter(last)) {
      final entry = entries[day];
      result[day] = entry != null && habit.isEntryComplete(entry);
      day = day.add(const Duration(days: 1));
    }
    return result;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
