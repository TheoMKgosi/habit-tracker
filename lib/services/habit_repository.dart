import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../data/database.dart';
import '../models/habit.dart';

/// All data operations: habits, entries, streaks and history.
class HabitRepository {
  final DatabaseHelper _dbHelper;

  HabitRepository([DatabaseHelper? dbHelper]) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  // ---------- Habits ----------

  Future<List<Habit>> getHabits({bool includeArchived = false}) async {
    final db = await _dbHelper.database;
    final rows = await db.query('habits', orderBy: 'createdAt ASC');
    final habits = rows.map(Habit.fromMap).toList();
    return includeArchived ? habits : habits.where((h) => !h.archived).toList();
  }

  Future<Habit?> getHabit(String id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('habits', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Habit.fromMap(rows.first);
  }

  Future<void> insertHabit(Habit habit) async {
    final db = await _dbHelper.database;
    await db.insert('habits', habit.toMap());
  }

  Future<void> updateHabit(Habit habit) async {
    final db = await _dbHelper.database;
    await db.update('habits', habit.toMap(), where: 'id = ?', whereArgs: [habit.id]);
  }

  Future<void> deleteHabit(String id) async {
    final db = await _dbHelper.database;
    await db.delete('entries', where: 'habitId = ?', whereArgs: [id]);
    await db.delete('habits', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Entries ----------

  Future<HabitEntryData?> getEntry(String habitId, DateTime date) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'entries',
      where: 'habitId = ? AND date = ?',
      whereArgs: [habitId, dateKey(dateOnly(date))],
      limit: 1,
    );
    return rows.isEmpty ? null : HabitEntryData.fromMap(rows.first);
  }

  /// Insert or replace the entry for one day.
  Future<void> upsertEntry(HabitEntryData entry) async {
    final db = await _dbHelper.database;
    await db.insert(
      'entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteEntry(String habitId, DateTime date) async {
    final db = await _dbHelper.database;
    await db.delete(
      'entries',
      where: 'habitId = ? AND date = ?',
      whereArgs: [habitId, dateKey(dateOnly(date))],
    );
  }

  Future<List<HabitEntryData>> getEntriesForHabit(String habitId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'entries',
      where: 'habitId = ?',
      whereArgs: [habitId],
      orderBy: 'date ASC',
    );
    return rows.map(HabitEntryData.fromMap).toList();
  }

  /// Today's entry for a habit, or a blank one if none exists yet.
  Future<HabitEntryData> todayEntry(Habit habit, DateTime today) async {
    return await getEntry(habit.id, today) ??
        HabitEntryData(habitId: habit.id, date: dateOnly(today), completed: false, value: 0);
  }

  // ---------- Stats ----------

  /// Whether the habit counts as completed on the given date.
  Future<bool> isCompleteOn(Habit habit, DateTime date) async {
    final entry = await getEntry(habit.id, date);
    if (entry == null) return false;
    return habit.isEntryComplete(entry);
  }

  /// Current streak: consecutive completed days ending today (or yesterday if
  /// today isn't done yet).
  Future<int> currentStreak(Habit habit, DateTime today) async {
    final t = dateOnly(today);
    var day = t;
    if (!await isCompleteOn(habit, day)) {
      day = t.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (await isCompleteOn(habit, day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Longest run of completed days in the habit's entire history.
  Future<int> longestStreak(Habit habit) async {
    final entries = await getEntriesForHabit(habit.id);
    if (entries.isEmpty) return 0;

    var longest = 0;
    var run = 0;
    DateTime? prev;
    for (final entry in entries) {
      if (!habit.isEntryComplete(entry)) {
        run = 0;
        prev = null;
        continue;
      }
      final d = dateOnly(entry.date);
      run = (prev != null && d.difference(prev).inDays == 1) ? run + 1 : 1;
      if (run > longest) longest = run;
      prev = d;
    }
    return longest;
  }

  /// Fraction of the last [days] days (since the habit was created) that were
  /// completed. Returns 0 when the habit is brand new.
  Future<double> completionRate(Habit habit, DateTime today, {int days = 30}) async {
    final t = dateOnly(today);
    final start = dateOnly(habit.createdAt).isAfter(t.subtract(Duration(days: days)))
        ? dateOnly(habit.createdAt)
        : t.subtract(Duration(days: days));
    final totalDays = t.difference(start).inDays + 1;
    if (totalDays <= 0) return 0;

    var completed = 0;
    var day = start;
    while (!day.isAfter(t)) {
      if (await isCompleteOn(habit, day)) completed++;
      day = day.add(const Duration(days: 1));
    }
    return completed / totalDays;
  }

  /// Entries for a habit between [start] and [end] inclusive, keyed by date.
  Future<Map<DateTime, HabitEntryData>> entriesBetween(
    String habitId,
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'entries',
      where: 'habitId = ? AND date >= ? AND date <= ?',
      whereArgs: [habitId, dateKey(dateOnly(start)), dateKey(dateOnly(end))],
      orderBy: 'date ASC',
    );
    return {
      for (final row in rows.map(HabitEntryData.fromMap)) dateOnly(row.date): row,
    };
  }
}

/// Small id generator: timestamp + random suffix, good enough locally.
String newId() {
  final rnd = Random();
  final suffix = List.generate(8, (_) => rnd.nextInt(16).toRadixString(16)).join();
  return DateTime.now().microsecondsSinceEpoch.toRadixString(36) + suffix;
}
