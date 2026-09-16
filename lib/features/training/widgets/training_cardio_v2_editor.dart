import 'package:flutter/material.dart';

import '../../../core/models/cardio_entry.dart';
import '../../../core/models/cardio_entry_v2.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/training_v2_form_controller.dart';
import '../services/training_cardio_calorie_calculator.dart';
import '../services/training_v2_form_mapper.dart';
import 'training_collapsible_card.dart';

class TrainingCardioV2Editor extends StatelessWidget {
  final int index;
  final TrainingV2CardioFormController controller;
  final bool expanded;
  final TrainingCardioCalorieResult calorieResult;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const TrainingCardioV2Editor({
    super.key,
    required this.index,
    required this.controller,
    required this.expanded,
    required this.calorieResult,
    required this.onToggle,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final title = controller.type == null
        ? 'CARDIO ${index + 1}'
        : _typeLabel(controller.type!);
    final useTwoColumns = MediaQuery.sizeOf(context).width >= 360;
    return TrainingCollapsibleCard(
      cardKey: ValueKey('training-cardio-card-$index'),
      icon: Icons.directions_run,
      title: title,
      summary: _summary(),
      isExpanded: expanded,
      onToggle: onToggle,
      headerKey: ValueKey('v2-cardio-header-${identityHashCode(controller)}'),
      contentKey: ValueKey('v2-cardio-content-${identityHashCode(controller)}'),
      semanticsLabel: '$title, ${expanded ? 'expanded' : 'collapsed'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<CardioType?>(
                  key: Key('v2-cardio-$index-type'),
                  initialValue: controller.type,
                  isExpanded: true,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: const InputDecoration(),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('SELECT CARDIO'),
                    ),
                    for (final type in CardioType.values)
                      DropdownMenuItem(
                        value: type,
                        child: Text(_typeLabel(type)),
                      ),
                  ],
                  onChanged: (value) {
                    controller.type = value;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                key: ValueKey('training-cardio-delete-$index'),
                icon: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                tooltip: 'Delete cardio',
                onPressed: onDelete,
              ),
            ],
          ),
          AppSpacing.gapXS,
          Container(
            key: ValueKey(
              useTwoColumns
                  ? 'training-cardio-two-column'
                  : 'training-cardio-one-column',
            ),
            child: Column(
              children: [
                _pair(
                  useTwoColumns,
                  _purposeField(context),
                  _durationField(context),
                ),
                AppSpacing.gapXS,
                _pair(
                  useTwoColumns,
                  _numberField(
                    controller.distance,
                    '距離',
                    suffix: 'km',
                    decimal: true,
                  ),
                  _numberField(controller.mets, 'METs', decimal: true),
                ),
                AppSpacing.gapXS,
                _pair(
                  useTwoColumns,
                  _numberField(
                    controller.averageHeartRate,
                    '平均心拍',
                    suffix: 'bpm',
                  ),
                  _numberField(
                    controller.maximumHeartRate,
                    '最大心拍',
                    suffix: 'bpm',
                  ),
                ),
                AppSpacing.gapXS,
                _pair(
                  useTwoColumns,
                  TextField(
                    controller: controller.averageSpeed,
                    decoration: const InputDecoration(
                      labelText: '平均速度',
                      suffixText: 'km/h',
                    ),
                    keyboardType: TextInputType.text,
                    onChanged: (_) => onChanged(),
                  ),
                  InputDecorator(
                    key: ValueKey('v2-cardio-$index-estimated-calories'),
                    decoration: const InputDecoration(labelText: '推定消費カロリー'),
                    child: Text(
                      calorieResult.isComputed
                          ? '${calorieResult.estimatedCaloriesKcal!.round()} kcal'
                          : 'Not calculated',
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapXS,
          Text(
            calorieResult.isComputed
                ? 'Calculated from METs, duration, and STATUS weight'
                : _calculationHelp(calorieResult.failureReason),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          AppSpacing.gapXS,
          TextField(
            controller: controller.notes,
            decoration: const InputDecoration(labelText: 'メモ'),
            minLines: 1,
            maxLines: 2,
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }

  Widget _pair(bool useTwoColumns, Widget first, Widget second) {
    if (!useTwoColumns) {
      return Column(children: [first, AppSpacing.gapXS, second]);
    }
    return Row(
      children: [
        Expanded(child: first),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: second),
      ],
    );
  }

  Widget _purposeField(BuildContext context) =>
      DropdownButtonFormField<CardioPurpose?>(
        key: Key('v2-cardio-$index-purpose'),
        initialValue: controller.purpose,
        isExpanded: true,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: const InputDecoration(),
        items: const [
          DropdownMenuItem(value: null, child: Text('SELECT PURPOSE')),
          DropdownMenuItem(value: CardioPurpose.warmUp, child: Text('WARM-UP')),
          DropdownMenuItem(value: CardioPurpose.main, child: Text('MAIN')),
          DropdownMenuItem(
            value: CardioPurpose.cooldown,
            child: Text('COOL-DOWN'),
          ),
        ],
        onChanged: (value) {
          controller.purpose = value;
          onChanged();
        },
      );

  Widget _durationField(BuildContext context) => TextField(
    key: Key('v2-cardio-$index-duration'),
    controller: controller.duration,
    readOnly: true,
    decoration: const InputDecoration(
      labelText: '時間',
      hintText: 'mm:ss',
      suffixIcon: Icon(Icons.timer_outlined),
    ),
    onTap: () => _pickDuration(context),
  );

  Future<void> _pickDuration(BuildContext context) async {
    final initialSeconds =
        TrainingV2FormMapper.tryParseDurationSeconds(
          controller.duration.text,
        ) ??
        0;
    final duration = await showDialog<Duration>(
      context: context,
      builder: (_) => _CardioDurationPicker(initialSeconds: initialSeconds),
    );
    if (duration == null) return;
    controller.duration.text = _formatDuration(duration);
    onChanged();
  }

  Widget _numberField(
    TextEditingController value,
    String label, {
    String? suffix,
    bool decimal = false,
  }) {
    return TextField(
      controller: value,
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      onChanged: (_) => onChanged(),
    );
  }

  String? _summary() {
    final duration = controller.duration.text.trim();
    if (duration.isEmpty) return 'Not configured';
    return '$duration'
        '${controller.distance.text.trim().isEmpty ? '' : '   ${controller.distance.text.trim()} km'}';
  }
}

class _CardioDurationPicker extends StatefulWidget {
  const _CardioDurationPicker({required this.initialSeconds});

  final int initialSeconds;

  @override
  State<_CardioDurationPicker> createState() => _CardioDurationPickerState();
}

class _CardioDurationPickerState extends State<_CardioDurationPicker> {
  late var _hours = widget.initialSeconds ~/ 3600;
  late var _minutes = (widget.initialSeconds % 3600) ~/ 60;
  late var _seconds = widget.initialSeconds % 60;

  Duration get _duration =>
      Duration(hours: _hours, minutes: _minutes, seconds: _seconds);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('CARDIO DURATION'),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hoursPicker(),
          const SizedBox(width: AppSpacing.sm),
          _unitPicker(
            label: 'MINUTES',
            value: _minutes,
            onChanged: (value) => setState(() => _minutes = value),
          ),
          const SizedBox(width: AppSpacing.sm),
          _unitPicker(
            label: 'SECONDS',
            value: _seconds,
            onChanged: (value) => setState(() => _seconds = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_duration),
          child: const Text('APPLY'),
        ),
      ],
    );
  }

  Widget _hoursPicker() => Semantics(
    label: 'Hours',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('HOURS'),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Decrease hours',
              onPressed: _hours == 0 ? null : () => setState(() => _hours -= 1),
              icon: const Icon(Icons.remove),
            ),
            Text('$_hours', key: const ValueKey('cardio-duration-hours')),
            IconButton(
              tooltip: 'Increase hours',
              onPressed: () => setState(() => _hours += 1),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _unitPicker({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    final fieldKey = 'cardio-duration-${label.toLowerCase()}';
    return SizedBox(
      key: ValueKey(fieldKey),
      width: 64,
      child: DropdownButtonFormField<int>(
        key: ValueKey('$fieldKey-value-$value'),
        initialValue: value,
        isExpanded: true,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(labelText: label),
        items: [
          for (var unit = 0; unit < 60; unit++)
            DropdownMenuItem(
              value: unit,
              child: Text(unit.toString().padLeft(2, '0')),
            ),
        ],
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return duration.inHours > 0
      ? '${duration.inHours}:$minutes:$seconds'
      : '${duration.inMinutes}:$seconds';
}

String _calculationHelp(TrainingCardioCalculationFailure? reason) {
  return switch (reason) {
    TrainingCardioCalculationFailure.missingMets ||
    TrainingCardioCalculationFailure.invalidMets => 'METs is required',
    TrainingCardioCalculationFailure.missingDuration ||
    TrainingCardioCalculationFailure.invalidDuration => 'Duration is required',
    TrainingCardioCalculationFailure.missingStatusWeight ||
    TrainingCardioCalculationFailure.invalidWeight =>
      'STATUS Weight is required',
    null => 'Not calculated',
  };
}

String _typeLabel(CardioType type) => switch (type) {
  CardioType.walking => 'ウォーキング',
  CardioType.running => 'ランニング',
  CardioType.exerciseBike => 'エアロバイク',
  CardioType.elliptical => 'エリプティカル／クロストレーナー',
  CardioType.treadmillWalking => 'トレッドミル・ウォーキング',
  CardioType.treadmillRunning => 'トレッドミル・ランニング',
};
