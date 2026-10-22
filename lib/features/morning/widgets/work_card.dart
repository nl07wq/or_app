import 'package:flutter/material.dart';

import 'package:or_app/core/widgets/global_touch_ripple.dart';

import '../../../core/models/work_type.dart';
import '../../../core/models/shift_preset.dart';
import '../../../core/services/shift_preset_preferences.dart';
import '../../../core/widgets/inputs/wheel/wheel_selector_card.dart';
import '../../../core/widgets/dashboard_glass_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/services/work_calculator.dart';
import '../../schedule/widgets/shared_time_picker.dart';

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
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: _presets.length,
                        onReorderItem: (oldIndex, newIndex) async {
                          final next = List<ShiftPreset>.of(_presets);
                          final preset = next.removeAt(oldIndex);
                          next.insert(newIndex, preset);
                          await refresh(next);
                        },
                        itemBuilder: (context, index) {
                          final preset = _presets[index];
                          return KeyedSubtree(
                            key: ValueKey(preset.id),
                            child: ListTile(
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
                                    if (value.id == preset.id)
                                      result
                                    else
                                      value,
                                ];
                                await refresh(next);
                              },
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'DELETE PRESET',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      await refresh(
                                        _presets
                                            .where(
                                              (value) => value.id != preset.id,
                                            )
                                            .toList(),
                                      );
                                    },
                                  ).actionableFeedback(),
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Icon(Icons.drag_handle),
                                    ),
                                  ),
                                ],
                              ),
                            ).actionableFeedback(enabled: true),
                          );
                        },
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
                        ).actionableFeedback(),
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
    return DashboardGlassCard(
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
                ).actionableFeedback(),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                for (var index = 0; index < _presets.length; index++) ...[
                  if (index > 0) const SizedBox(width: 4),
                  Expanded(
                    child: ChoiceChip(
                      label: Text(
                        _presets[index].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      selected: false,
                      onSelected: (_) => _applyPreset(_presets[index]),
                    ).inputFeedback(),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 20),

            _WorkClockRow(
              key: const ValueKey('work-start-orbital-picker'),
              title: 'Start Time',
              controller: widget.startController,
            ),

            const SizedBox(height: 20),

            _WorkClockRow(
              key: const ValueKey('work-end-orbital-picker'),
              title: 'End Time',
              controller: widget.endController,
            ),

            const SizedBox(height: 20),

            _BreakTimeStepper(
              key: const ValueKey('work-break-stepper'),
              controller: widget.breakController,
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

class _WorkClockRow extends StatefulWidget {
  const _WorkClockRow({
    super.key,
    required this.title,
    required this.controller,
  });
  final String title;
  final TextEditingController controller;
  @override
  State<_WorkClockRow> createState() => _WorkClockRowState();
}

class _WorkClockRowState extends State<_WorkClockRow> {
  late bool _collapsed;
  @override
  void initState() {
    super.initState();
    _collapsed = _isValidTime(widget.controller.text);
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant _WorkClockRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  TimeOfDay get _time {
    final p = widget.controller.text.split(':');
    return TimeOfDay(
      hour: (int.tryParse(p.first) ?? 0).clamp(0, 23),
      minute: (p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0).clamp(0, 59),
    );
  }

  Future<void> _pick() async {
    final result = await showSharedTimePicker(context, initialTime: _time);
    if (result != null) {
      widget.controller.text =
          '${result.hour.toString().padLeft(2, '0')}:${result.minute.toString().padLeft(2, '0')}';
      if (mounted) setState(() => _collapsed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_collapsed && _isValidTime(widget.controller.text)) {
      return Semantics(
        button: true,
        label: '${widget.title} ${widget.controller.text} 再編集',
        child: InkWell(
          onTap: _pick,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 54,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  widget.controller.text,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: cs.primary,
                    fontFamily: 'ShareTechMono',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(Icons.edit_outlined, size: 18, color: cs.primary),
              ],
            ),
          ),
        ).actionableFeedback(),
      );
    }
    return Semantics(
      button: true,
      label: '${widget.title} ${widget.controller.text}',
      child: InkWell(
        onTap: _pick,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: cs.surfaceContainer.withValues(alpha: .28),
            border: Border.all(color: cs.primary.withValues(alpha: .35)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(Icons.schedule, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                widget.controller.text,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFamily: 'ShareTechMono',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: cs.primary),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ).actionableFeedback(),
    );
  }
}

bool _isValidTime(String value) {
  final p = value.split(':');
  if (p.length != 2) return false;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  return h != null && m != null && h >= 0 && h <= 23 && m >= 0 && m <= 59;
}

class _BreakTimeStepper extends StatefulWidget {
  const _BreakTimeStepper({super.key, required this.controller});
  final TextEditingController controller;
  @override
  State<_BreakTimeStepper> createState() => _BreakTimeStepperState();
}

class _BreakTimeStepperState extends State<_BreakTimeStepper> {
  late bool _editing;
  int get _minutes {
    final p = widget.controller.text.split(':');
    final h = int.tryParse(p.first) ?? 0;
    final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
    return (h * 60 + m).clamp(0, 23 * 60 + 45);
  }

  String get _label =>
      '${_minutes ~/ 60}:${(_minutes % 60).toString().padLeft(2, '0')}';
  @override
  void initState() {
    super.initState();
    _editing = widget.controller.text.isEmpty;
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _step(int delta) {
    final next = (_minutes + delta).clamp(0, 23 * 60 + 45);
    widget.controller.text =
        '${next ~/ 60}:${(next % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    if (!_editing && widget.controller.text.isNotEmpty) {
      return Semantics(
        button: true,
        label: 'Break Time $_label 再編集',
        child: InkWell(
          key: const ValueKey('work-break-collapsed'),
          onTap: () => setState(() => _editing = true),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 54,
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Break Time',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  _label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontFamily: 'ShareTechMono',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(Icons.edit_outlined, size: 18, color: color),
              ],
            ),
          ),
        ).actionableFeedback(),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainer.withValues(alpha: .28),
      ),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Break Time',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _label,
            key: const ValueKey('work-break-value'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 30,
              fontFamily: 'ShareTechMono',
              fontWeight: FontWeight.w800,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: const ValueKey('work-break-minus'),
                icon: const Icon(Icons.remove),
                onPressed: _minutes <= 0 ? null : () => _step(-15),
              ),
              const SizedBox(width: 36),
              IconButton(
                key: const ValueKey('work-break-plus'),
                icon: const Icon(Icons.add),
                onPressed: _minutes >= 23 * 60 + 45 ? null : () => _step(15),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey('work-break-done'),
              onPressed: () => setState(() => _editing = false),
              child: const Text('完了'),
            ).actionableFeedback(),
          ),
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
          ).inputFeedback(),
          TextField(
            controller: _startController,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(labelText: 'Start Time (HH:mm)'),
          ).inputFeedback(),
          TextField(
            controller: _endController,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(labelText: 'End Time (HH:mm)'),
          ).inputFeedback(),
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
        ).actionableFeedback(),
        TextButton(
          onPressed: _save,
          child: const Text('SAVE'),
        ).actionableFeedback(),
      ],
    );
  }
}
