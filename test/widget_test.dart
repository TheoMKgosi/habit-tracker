import 'package:flutter_test/flutter_test.dart';

import 'package:habit_tracker/models/habit.dart';

void main() {
  final testDate = DateTime(2026, 1, 2, 15, 30);

  Habit habit({
    HabitType type = HabitType.checkoff,
    double? target,
  }) {
    return Habit(
      id: 'h1',
      name: 'Test habit',
      type: type,
      iconCodePoint: Habit.iconChoices.first.codePoint,
      colorValue: 0xFF009688,
      target: target,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  HabitEntryData entry({bool completed = false, double value = 0}) {
    return HabitEntryData(
      habitId: 'h1',
      date: testDate,
      completed: completed,
      value: value,
    );
  }

  group('isEntryComplete', () {
    test('check-off habit is complete only when flagged', () {
      final h = habit();
      expect(h.isEntryComplete(entry(completed: true)), isTrue);
      expect(h.isEntryComplete(entry(completed: false)), isFalse);
    });

    test('quantified habit is complete when value reaches target', () {
      final h = habit(type: HabitType.quantified, target: 8);
      expect(h.isEntryComplete(entry(value: 8)), isTrue);
      expect(h.isEntryComplete(entry(value: 9)), isTrue);
      expect(h.isEntryComplete(entry(value: 3)), isFalse);
      expect(h.isEntryComplete(entry(completed: true, value: 0)), isFalse);
    });
  });

  group('date helpers', () {
    test('dateKey produces a stable sortable key', () {
      expect(dateKey(DateTime(2026, 11, 6)), '2026-11-06');
      expect(dateKey(DateTime(2026, 1, 2)), '2026-01-02');
    });

    test('dateOnly strips the time component', () {
      final d = dateOnly(testDate);
      expect(d.hour, 0);
      expect(d.minute, 0);
      expect(d.day, 2);
    });

    test('parseDateKey round-trips through dateKey', () {
      final parsed = parseDateKey(dateKey(testDate));
      expect(parsed.year, testDate.year);
      expect(parsed.month, testDate.month);
      expect(parsed.day, testDate.day);
    });
  });

  group('serialization', () {
    test('Habit round-trips through its map', () {
      final h = habit(
        type: HabitType.quantified,
        target: 5,
      );
      final restored = Habit.fromMap(h.toMap());
      expect(restored.id, h.id);
      expect(restored.name, h.name);
      expect(restored.type, h.type);
      expect(restored.iconCodePoint, h.iconCodePoint);
      expect(restored.colorValue, h.colorValue);
      expect(restored.target, h.target);
      expect(restored.createdAt, h.createdAt);
    });

    test('HabitEntryData round-trips through its map', () {
      final e = entry(completed: true, value: 3.5);
      final restored = HabitEntryData.fromMap(e.toMap());
      expect(restored.habitId, e.habitId);
      expect(dateKey(restored.date), dateKey(e.date));
      expect(restored.completed, e.completed);
      expect(restored.value, e.value);
    });
  });
}
