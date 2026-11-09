import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../services/habit_repository.dart';
import '../state/habit_provider.dart';

/// Bottom-sheet form to create or edit a habit.
class HabitForm extends StatefulWidget {
  final HabitProvider provider;

  /// When non-null the form edits this habit; otherwise it creates a new one.
  final Habit? existing;

  const HabitForm({super.key, required this.provider, this.existing});

  @override
  State<HabitForm> createState() => _HabitFormState();
}

class _HabitFormState extends State<HabitForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late final TextEditingController _unitController;

  late HabitType _type;
  late IconData _icon;
  late Color _color;

  static const _iconChoices = <IconData>[
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

  static const _colorChoices = <Color>[
    Colors.teal,
    Colors.indigo,
    Colors.purple,
    Colors.pink,
    Colors.orange,
    Colors.amber,
    Colors.green,
    Colors.blue,
    Colors.red,
  ];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _targetController =
        TextEditingController(text: existing?.target?.toString() ?? '1');
    _unitController = TextEditingController(text: existing?.unit ?? '');
    _type = existing?.type ?? HabitType.checkoff;
    _icon = existing?.icon ?? _iconChoices.first;
    _color = existing?.color ?? _colorChoices.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Edit habit' : 'New habit',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _nameController,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Habit name',
                border: OutlineInputBorder(),
                hintText: 'e.g. Drink water, Read, Exercise',
              ),
            ),
            const SizedBox(height: 16),

            // Type selector
            SegmentedButton<HabitType>(
              segments: const [
                ButtonSegment(
                  value: HabitType.checkoff,
                  icon: Icon(Icons.check_circle_outline),
                  label: Text('Check-off'),
                ),
                ButtonSegment(
                  value: HabitType.quantified,
                  icon: Icon(Icons.pin),
                  label: Text('Quantified'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) =>
                  setState(() => _type = selection.first),
            ),
            const SizedBox(height: 16),

            // Target + unit (quantified only)
            if (_type == HabitType.quantified) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _targetController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Daily target',
                        border: OutlineInputBorder(),
                        hintText: 'e.g. 8',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _unitController,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                        hintText: 'e.g. glasses',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            Text('Icon', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final icon in _iconChoices)
                  _IconChoice(
                    icon: icon,
                    selected: icon == _icon,
                    onTap: () => setState(() => _icon = icon),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            Text('Color', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final color in _colorChoices)
                  _ColorChoice(
                    color: color,
                    selected: color == _color,
                    onTap: () => setState(() => _color = color),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(_isEditing ? 'Save changes' : 'Create habit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please give the habit a name')),
      );
      return;
    }

    double? target;
    if (_type == HabitType.quantified) {
      final parsed = double.tryParse(_targetController.text.trim());
      if (parsed == null || parsed <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Target must be a positive number')),
        );
        return;
      }
      target = parsed;
    }

    final unit = _unitController.text.trim();

    final existing = widget.existing;
    final habit = existing == null
        ? Habit(
            id: newId(),
            name: name,
            type: _type,
            iconCodePoint: _icon.codePoint,
            colorValue: _color.toARGB32(),
            target: target,
            unit: unit.isEmpty ? null : unit,
            createdAt: DateTime.now(),
          )
        : existing.copyWith(
            name: name,
            type: _type,
            iconCodePoint: _icon.codePoint,
            colorValue: _color.toARGB32(),
            target: target,
            unit: unit.isEmpty ? null : unit,
          );

    if (_isEditing) {
      await widget.provider.updateHabit(habit);
    } else {
      await widget.provider.addHabit(habit);
    }

    if (mounted) Navigator.of(context).pop();
  }
}

class _IconChoice extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _IconChoice({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Icon(icon, size: 22),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
              : null,
        ),
        child: selected ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
      ),
    );
  }
}
