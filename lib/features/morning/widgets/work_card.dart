import 'package:flutter/material.dart';

import '../../../core/models/work_type.dart';
import '../../../core/models/shift_preset.dart';
import '../../../core/services/shift_preset_preferences.dart';
import '../../../core/widgets/inputs/time/time_input_card.dart';
import '../../../core/widgets/inputs/wheel/wheel_selector_card.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/services/work_calculator.dart';

class WorkCard extends StatefulWidget {
  final WorkType workType;

  final ValueChanged<WorkType> onChanged;

  final TextEditingController startController;
  final TextEditingController endController;
  final TextEditingController breakController;

  const WorkCard({
    super.key,
    required this.workType,
    required this.onChanged,
    required this.startController,
    required this.endController,
    required this.breakController,
  });

  @override
  State<WorkCard> createState() => _WorkCardState();
}

class _WorkCardState extends State<WorkCard> {
  List<ShiftPreset> _presets = const [];
  bool _loadingPresets = true;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final presets = await ShiftPresetPreferences.load();
    if (!mounted) return;
    setState(() {
      _presets = presets;
      _loadingPresets = false;
    });
  }

  void _applyPreset(ShiftPreset preset) {
    widget.startController.text = preset.startTime;
    widget.endController.text = preset.endTime;
    widget.breakController.text = preset.breakTime;

    setState(() {});
  }

  Future<void> _savePresets(List<ShiftPreset> values) async {
    final ordered = [
      for (var index = 0; index < values.length; index++)
        values[index].copyWith(order: index),
    ];
    await ShiftPresetPreferences.save(ordered);
    if (!mounted) return;
    setState(() => _presets = ordered);
  }

  Future<void> _showPresetSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> refresh(List<ShiftPreset> values) async {
                await _savePresets(values);
                if (context.mounted) setSheetState(() {});
              }

              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SHIFT PRESETS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final preset in _presets)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(preset.name),
                          subtitle: Text(
                            '${preset.startTime} → ${preset.endTime}',
                          ),
                          onTap: () async {
                            final result = await _showPresetEditor(
                              context,
                              preset: preset,
                            );
                            if (result == null) return;
                            final next = [
                              for (final value in _presets)
                                if (value.id == preset.id) result else value,
                            ];
                            await refresh(next);
                          },
                          trailing: IconButton(
                            tooltip: 'DELETE PRESET',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await refresh(
                                _presets
                                    .where((value) => value.id != preset.id)
                                    .toList(),
                              );
                            },
                          ),
                        ),
                      if (_presets.length < ShiftPresetPreferences.maxPresets)
                        TextButton.icon(
                          onPressed: () async {
                            final result = await _showPresetEditor(context);
                            if (result == null) return;
                            await refresh([..._presets, result]);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('追加'),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<ShiftPreset?> _showPresetEditor(
    BuildContext context, {
    ShiftPreset? preset,
  }) {
    return showDialog<ShiftPreset>(
      context: context,
      builder: (_) =>
          _ShiftPresetEditorDialog(preset: preset, presets: _presets),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.work, title: "WORK"),

          const SizedBox(height: 20),

          WheelSelectorCard<WorkType>(
            title: "Work Type",
            value: widget.workType,
            values: WorkType.values,
            labels: const {
              WorkType.work: "出勤",
              WorkType.holiday: "公休日",
              WorkType.paidLeave: "有給休暇",
              WorkType.halfDay: "半休",
              WorkType.other: "その他",
            },
            onChanged: widget.onChanged,
          ),

          if (widget.workType == WorkType.work ||
              widget.workType == WorkType.halfDay) ...[
            const SizedBox(height: 20),

            Row(
              children: [
                const Text(
                  "Shift",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'EDIT SHIFT PRESETS',
                  onPressed: _loadingPresets ? null : _showPresetSettings,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),

            const SizedBox(height: 12),

            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 280;
                final itemWidth = twoColumns
                    ? (constraints.maxWidth - 8) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in _presets)
                      SizedBox(
                        width: itemWidth,
                        child: ChoiceChip(
                          label: Text(
                            preset.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                          selected: false,
                          onSelected: (_) => _applyPreset(preset),
                        ),
                      ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            TimeInputCard(
              title: "Start Time",
              controller: widget.startController,
              minuteStep: 15,
              initialHour: 11,
              initialMinute: 0,
            ),

            const SizedBox(height: 20),

            TimeInputCard(
              title: "End Time",
              controller: widget.endController,
              minuteStep: 15,
              initialHour: 18,
              initialMinute: 0,
            ),

            const SizedBox(height: 20),

            TimeInputCard(
              title: "Break Time",
              controller: widget.breakController,
              minuteStep: 15,
              initialHour: 1,
              initialMinute: 0,
            ),

            const SizedBox(height: 20),

            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.startController,
              builder: (_, _, _) {
                return ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.endController,
                  builder: (_, _, _) {
                    return ValueListenableBuilder<TextEditingValue>(
                      valueListenable: widget.breakController,
                      builder: (_, _, _) {
                        final workHours = WorkCalculator.calculate(
                          start: widget.startController.text,
                          end: widget.endController.text,
                          workBreak: widget.breakController.text,
                        );

                        return Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                "WORK HOURS",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                WorkCalculator.format(workHours),
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ShiftPresetEditorDialog extends StatefulWidget {
  const _ShiftPresetEditorDialog({required this.preset, required this.presets});

  final ShiftPreset? preset;
  final List<ShiftPreset> presets;

  @override
  State<_ShiftPresetEditorDialog> createState() =>
      _ShiftPresetEditorDialogState();
}

class _ShiftPresetEditorDialogState extends State<_ShiftPresetEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.preset?.name ?? '');
    _startController = TextEditingController(
      text: widget.preset?.startTime ?? '',
    );
    _endController = TextEditingController(text: widget.preset?.endTime ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final start = _startController.text.trim();
    final end = _endController.text.trim();
    if (!ShiftPresetPreferences.isValidEditablePreset(
      name: name,
      startTime: start,
      endTime: end,
      existing: widget.presets,
      editingId: widget.preset?.id,
    )) {
      setState(() => _errorText = 'Enter a unique name and valid times.');
      return;
    }
    Navigator.pop(
      context,
      ShiftPreset(
        id:
            widget.preset?.id ??
            'shift_custom_${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        startTime: start,
        endTime: end,
        breakTime: widget.preset?.breakTime ?? '01:00',
        order: widget.preset?.order ?? widget.presets.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.preset == null ? 'ADD SHIFT PRESET' : 'EDIT SHIFT PRESET',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            maxLength: 24,
            decoration: const InputDecoration(labelText: 'Preset Name'),
          ),
          TextField(
            controller: _startController,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(labelText: 'Start Time (HH:mm)'),
          ),
          TextField(
            controller: _endController,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(labelText: 'End Time (HH:mm)'),
          ),
          if (_errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _errorText!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        TextButton(onPressed: _save, child: const Text('SAVE')),
      ],
    );
  }
}
