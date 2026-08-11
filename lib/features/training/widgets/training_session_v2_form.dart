import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/training_session_v2.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/operation_flip_tile.dart';
import '../../../core/widgets/section_header.dart';
import '../models/training_v2_form_controller.dart';

class TrainingSessionV2Form extends StatelessWidget {
  final TrainingV2FormController controller;
  final VoidCallback onChanged;
  final DateTime Function() now;
  final Future<void> Function()? onStartTraining;
  final Future<void> Function()? onEndTraining;
  final Future<void> Function()? onUndoEnd;
  final Future<void> Function(TimeOfDay value)? onEditStartTime;
  final Future<void> Function(TimeOfDay value)? onEditEndTime;

  const TrainingSessionV2Form({
    super.key,
    required this.controller,
    required this.onChanged,
    DateTime Function()? now,
    this.onStartTraining,
    this.onEndTraining,
    this.onUndoEnd,
    this.onEditStartTime,
    this.onEditEndTime,
  }) : now = now ?? DateTime.now;

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(icon: Icons.event_note, title: 'SESSION'),
          AppSpacing.gapMD,
          _TrainingTimeActions(
            controller: controller,
            onChanged: onChanged,
            now: now,
            onStartTraining: onStartTraining,
            onEndTraining: onEndTraining,
            onUndoEnd: onUndoEnd,
            onEditStartTime: onEditStartTime,
            onEditEndTime: onEditEndTime,
          ),
          AppSpacing.gapSM,
          TextField(
            controller: controller.sessionName,
            decoration: const InputDecoration(labelText: 'Session Name'),
          ),
          AppSpacing.gapSM,
          DropdownButtonFormField<TrainingSessionGrade?>(
            initialValue: controller.sessionGrade,
            decoration: const InputDecoration(labelText: 'Session Grade'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Not recorded')),
              for (final grade in TrainingSessionGrade.values)
                DropdownMenuItem(value: grade, child: Text(grade.displayLabel)),
            ],
            onChanged: (value) {
              controller.sessionGrade = value;
              onChanged();
            },
          ),
          AppSpacing.gapSM,
          TextField(
            controller: controller.sessionMemo,
            decoration: const InputDecoration(labelText: 'Session Memo'),
            minLines: 2,
            maxLines: 3,
          ),
          AppSpacing.gapSM,
          _TriStateField(
            label: 'Dynamic Stretch',
            value: controller.dynamicStretchCompleted,
            onChanged: (value) {
              controller.dynamicStretchCompleted = value;
              onChanged();
            },
          ),
          AppSpacing.gapSM,
          _TriStateField(
            label: 'Cooldown Stretch',
            value: controller.cooldownStretchCompleted,
            onChanged: (value) {
              controller.cooldownStretchCompleted = value;
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

class _TrainingTimeActions extends StatefulWidget {
  final TrainingV2FormController controller;
  final VoidCallback onChanged;
  final DateTime Function() now;
  final Future<void> Function()? onStartTraining;
  final Future<void> Function()? onEndTraining;
  final Future<void> Function()? onUndoEnd;
  final Future<void> Function(TimeOfDay value)? onEditStartTime;
  final Future<void> Function(TimeOfDay value)? onEditEndTime;

  const _TrainingTimeActions({
    required this.controller,
    required this.onChanged,
    required this.now,
    required this.onStartTraining,
    required this.onEndTraining,
    required this.onUndoEnd,
    required this.onEditStartTime,
    required this.onEditEndTime,
  });

  @override
  State<_TrainingTimeActions> createState() => _TrainingTimeActionsState();
}

class _TrainingTimeActionsState extends State<_TrainingTimeActions> {
  Timer? _timer;
  late DateTime _currentTime;

  @override
  void initState() {
    super.initState();
    _currentTime = widget.now();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant _TrainingTimeActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    _currentTime = widget.now();
    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    final active =
        widget.controller.startTime != null &&
        widget.controller.endTime == null;
    if (active && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _currentTime = widget.now());
      });
    } else if (!active && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.controller.startTime;
    final end = widget.controller.endTime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TimeField(
          label: 'Start Time',
          value: _displayTime(start),
          onEdit: start == null ? null : () => _editStart(context, start),
        ),
        AppSpacing.gapSM,
        OutlinedButton.icon(
          onPressed: start == null
              ? () async {
                  final action = widget.onStartTraining;
                  if (action != null) {
                    await action();
                  } else {
                    widget.controller.startTraining(widget.now());
                    widget.onChanged();
                  }
                }
              : null,
          icon: const Icon(Icons.play_arrow),
          label: const Text('START TRAINING'),
        ),
        AppSpacing.gapSM,
        _TimeField(
          label: 'End Time',
          value: _displayTime(end, startTime: start),
          onEdit: end == null ? null : () => _editEnd(context, end),
        ),
        AppSpacing.gapSM,
        if (start != null && end == null) ...[
          _DurationField(
            label: 'ELAPSED',
            value: _elapsed(start, _currentTime),
          ),
          AppSpacing.gapSM,
          OutlinedButton.icon(
            onPressed: () async {
              final action = widget.onEndTraining;
              if (action != null) {
                await action();
              } else {
                widget.controller.endTraining(widget.now());
                widget.onChanged();
              }
            },
            icon: const Icon(Icons.stop),
            label: const Text('END TRAINING'),
          ),
        ] else if (start != null && end != null) ...[
          _DurationField(label: 'DURATION', value: _duration(start, end)),
          AppSpacing.gapSM,
          OutlinedButton.icon(
            onPressed: () async {
              final action = widget.onUndoEnd;
              if (action != null) {
                await action();
              } else {
                widget.controller.undoEnd();
                widget.onChanged();
              }
            },
            icon: const Icon(Icons.undo),
            label: const Text('RESUME TRAINING'),
          ),
        ],
      ],
    );
  }

  Future<void> _editStart(BuildContext context, String source) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _timeOfDay(source),
    );
    if (selected == null || !context.mounted) return;
    try {
      final action = widget.onEditStartTime;
      if (action != null) {
        await action(selected);
      } else {
        widget.controller.editStartTime(selected, now: widget.now());
        widget.onChanged();
      }
    } on TrainingTimeValidationException catch (error) {
      if (!context.mounted) return;
      _showError(context, error.message);
    }
  }

  Future<void> _editEnd(BuildContext context, String source) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _timeOfDay(source),
    );
    if (selected == null || !context.mounted) return;
    try {
      final action = widget.onEditEndTime;
      if (action != null) {
        await action(selected);
      } else {
        widget.controller.editEndTime(selected);
        widget.onChanged();
      }
    } on TrainingTimeValidationException catch (error) {
      if (!context.mounted) return;
      _showError(context, error.message);
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onEdit;

  const _TimeField({
    required this.label,
    required this.value,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: TextStyle(color: Theme.of(context).primaryColor)),
        if (onEdit != null) ...[
          AppSpacing.gapSM,
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('EDIT'),
          ),
        ],
      ],
    );
  }
}

class _DurationField extends StatelessWidget {
  final String label;
  final String value;

  const _DurationField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        AppSpacing.gapSM,
        _FlipTimer(label: label, value: value),
      ],
    );
  }
}

class _FlipTimer extends StatelessWidget {
  static const _digitGap = 4.0;
  static const _separatorWidth = 14.0;

  final String label;
  final String value;

  const _FlipTimer({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (!RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(value)) {
      return Semantics(
        key: ValueKey('flip-timer-$label'),
        label: '$label $value',
        child: ExcludeSemantics(
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      );
    }
    final digits = value.replaceAll(':', '').split('');
    return Semantics(
      key: ValueKey('flip-timer-$label'),
      label: '$label $value',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 280.0;
            final fixedWidth = _digitGap * 3 + _separatorWidth * 2;
            final cellWidth = ((availableWidth - fixedWidth) / 6).clamp(
              28.0,
              38.0,
            );
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FlipCell(index: 0, digit: digits[0], width: cellWidth),
                const SizedBox(width: _digitGap),
                _FlipCell(index: 1, digit: digits[1], width: cellWidth),
                const _FlipSeparator(),
                _FlipCell(index: 2, digit: digits[2], width: cellWidth),
                const SizedBox(width: _digitGap),
                _FlipCell(index: 3, digit: digits[3], width: cellWidth),
                const _FlipSeparator(),
                _FlipCell(index: 4, digit: digits[4], width: cellWidth),
                const SizedBox(width: _digitGap),
                _FlipCell(index: 5, digit: digits[5], width: cellWidth),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FlipCell extends StatelessWidget {
  final int index;
  final String digit;
  final double width;

  const _FlipCell({
    required this.index,
    required this.digit,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return OperationFlipTile(
      key: ValueKey('flip-cell-$index'),
      value: digit,
      valueKey: ValueKey('flip-digit-$index-$digit'),
      width: width,
      height: (width * 1.35).clamp(42.0, 52.0),
      textStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
        height: 1,
      ),
    );
  }
}

class _FlipSeparator extends StatelessWidget {
  const _FlipSeparator();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: _FlipTimer._separatorWidth,
    child: Center(
      child: Text(
        ':',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

TimeOfDay _timeOfDay(String source) => TimeOfDay(
  hour: int.parse(source.substring(11, 13)),
  minute: int.parse(source.substring(14, 16)),
);

String _displayTime(String? value, {String? startTime}) {
  if (value == null) return 'NOT RECORDED';
  final time = value.substring(11, 16);
  if (startTime == null ||
      value.substring(0, 10) == startTime.substring(0, 10)) {
    return time;
  }
  final startDate = DateTime.parse(startTime.substring(0, 10));
  final valueDate = DateTime.parse(value.substring(0, 10));
  if (valueDate.difference(startDate).inDays == 1) return '翌 $time';
  return '${value.substring(5, 10).replaceFirst('-', '/')} $time';
}

String _elapsed(String start, DateTime now) {
  final duration = now.difference(DateTime.parse(start));
  return duration.isNegative ? 'NOT AVAILABLE' : _formatDuration(duration);
}

String _duration(String start, String end) =>
    _formatDuration(DateTime.parse(end).difference(DateTime.parse(start)));

String _formatDuration(Duration value) {
  final hours = value.inHours.toString().padLeft(2, '0');
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

class _TriStateField extends StatelessWidget {
  final String label;
  final bool? value;
  final ValueChanged<bool?> onChanged;

  const _TriStateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: switch (value) {
        true => 'completed',
        false => 'notCompleted',
        null => 'notRecorded',
      },
      decoration: InputDecoration(labelText: label),
      items: const [
        DropdownMenuItem(value: 'notRecorded', child: Text('Not recorded')),
        DropdownMenuItem(value: 'completed', child: Text('Completed')),
        DropdownMenuItem(value: 'notCompleted', child: Text('Not completed')),
      ],
      onChanged: (value) => onChanged(switch (value) {
        'completed' => true,
        'notCompleted' => false,
        _ => null,
      }),
    );
  }
}
