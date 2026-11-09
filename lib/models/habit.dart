import 'package:flutter/material.dart';

/// How a habit is completed each day.
enum HabitType { checkoff, quantified }

/// A habit the user wants to track.
class Habit {
  final String id;
  final String name;
  final HabitType type;

  /// Material icon code point, persisted to the database.
  final int iconCodePoint;

  /// Color value, persisted to the database.
  final int colorValue;

  /// Daily target for quantified habits (null for check-off habits).
  final double? target;

  /// Unit label for quantified habits, e.g. "glasses", "minutes".
  final String? unit;

  /// Archived habits stay in the database (to keep history) but are hidden.
  final bool archived;

  final DateTime createdAt;

  const Habit({
    required this.id,
    required this.name,
    required this.type,
    required this.iconCodePoint,
    required this.colorValue,
    this.target,
    this.unit,
    this.archived = false,
    required this.createdAt,
  });

  Color get color => Color(colorValue);

  /// Icon choices offered when creating a habit.
  static const List<IconData> iconChoices = [
    Icons.directions_run,
    Icons.local_drink,
    Icons.menu_book,
    Icons.fitness_center,
    Icons.self_improvement,
    Icons.bedtime,
    Icons.music_note,
    Icons.brush,
    Icons.cleaning_services,
    Icons.eco,
    Icons.laptop_mac,
    Icons.savings,
  ];

  /// Resolves the stored code point back to an icon, safe for any value.
  IconData get icon {
    for (final choice in iconChoices) {
      if (choice.codePoint == iconCodePoint) return choice;
    }
    return Icons.track_changes;
  }

  /// Whether the given entry counts as "done" for this habit.
  bool isEntryComplete(HabitEntryData entry) {
    if (type == HabitType.checkoff) return entry.completed;
    return entry.value >= (target ?? 1);
  }

  Habit copyWith({
    String? name,
    HabitType? type,
    int? iconCodePoint,
    int? colorValue,
    double? target,
    String? unit,
    bool? archived,
  }) {
    return Habit(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      target: target ?? this.target,
      unit: unit ?? this.unit,
      archived: archived ?? this.archived,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type == HabitType.checkoff ? 'checkoff' : 'quantified',
      'icon': iconCodePoint,
      'color': colorValue,
      'target': target,
      'unit': unit,
      'archived': archived ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static Habit fromMap(Map<String, Object?> map) {
    return Habit(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] == 'quantified' ? HabitType.quantified : HabitType.checkoff,
      iconCodePoint: map['icon'] as int,
      colorValue: map['color'] as int,
      target: (map['target'] as num?)?.toDouble(),
      unit: map['unit'] as String?,
      archived: (map['archived'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

/// A single day's record for one habit.
class HabitEntryData {
  final String habitId;
  final DateTime date;
  final bool completed;
  final double value;

  const HabitEntryData({
    required this.habitId,
    required this.date,
    required this.completed,
    required this.value,
  });

  HabitEntryData copyWith({bool? completed, double? value}) {
    return HabitEntryData(
      habitId: habitId,
      date: date,
      completed: completed ?? this.completed,
      value: value ?? this.value,
    );
  }

  Map<String, Object> toMap() {
    return {
      'habitId': habitId,
      'date': dateKey(date),
      'completed': completed ? 1 : 0,
      'value': value,
    };
  }

  static HabitEntryData fromMap(Map<String, Object?> map) {
    return HabitEntryData(
      habitId: map['habitId'] as String,
      date: parseDateKey(map['date'] as String),
      completed: (map['completed'] as int? ?? 0) == 1,
      value: (map['value'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Normalizes a date to midnight local time so entries always match.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Stable string key for a date, e.g. "2026-11-06".
String dateKey(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// Parses a date key back into a local DateTime.
DateTime parseDateKey(String key) {
  final parts = key.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}
