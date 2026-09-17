import 'package:flutter/material.dart';

import '../../../core/models/training_set_v2.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../models/training_v2_form_controller.dart';

class TrainingSetV2Editor extends StatelessWidget {
  final TrainingV2ExerciseFormController controller;
  final Color activeBase;
  final VoidCallback onChanged;

  const TrainingSetV2Editor({
    super.key,
    required this.controller,
    required this.activeBase,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (index, set) in controller.sets.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _SetEditor(
              key: ValueKey('training-set-card-$index'),
              index: index,
              activeBase: activeBase,
              set: set,
              previous: index == 0 ? null : controller.sets[index - 1],
              onDelete: () => _confirmDelete(context, set),
              onChanged: onChanged,
            ),
          ),
        SizedBox(
          height: 44,
          child: OperationButton(
            icon: Icons.add,
            text: 'ADD SET',
            onPressed: () {
              controller.addSet();
              onChanged();
            },
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TrainingV2SetFormController set,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('このセットを削除しますか？'),
        content: const Text(
          'このセットの実施入力を削除します。\n元のトレーニングプランは保持されます。\n\nこの操作は取り消せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    controller.removeSet(set);
    onChanged();
  }
}

class _SetEditor extends StatelessWidget {
  static const _setTypeSlotWidth = 112.0;
  static const _headerActionSlotWidth = 48.0;
  static const _wideTitleSlotMaximum = 96.0;

  final int index;
  final Color activeBase;
  final TrainingV2SetFormController set;
  final TrainingV2SetFormController? previous;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _SetEditor({
    super.key,
    required this.index,
    required this.activeBase,
    required this.set,
    required this.previous,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: activeBase.withValues(alpha: 0.04),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final title = Text(
                  'SET ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                );
                final setType = _setTypeField(context);
                if (constraints.maxWidth < 320) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: title),
                          _deleteSlot(context),
                        ],
                      ),
                      AppSpacing.gapXS,
                      Row(
                        children: [
                          SizedBox(width: _setTypeSlotWidth, child: setType),
                          const Spacer(),
                          _copyWeightSlot(),
                          _copyRepsSlot(),
                        ],
                      ),
                    ],
                  );
                }
                final titleSlotWidth =
                    (constraints.maxWidth -
                            _setTypeSlotWidth -
                            (_headerActionSlotWidth * 3))
                        .clamp(0.0, _wideTitleSlotMaximum)
                        .toDouble();
                return Row(
                  children: [
                    SizedBox(width: titleSlotWidth, child: title),
                    SizedBox(width: _setTypeSlotWidth, child: setType),
                    _copyWeightSlot(),
                    _copyRepsSlot(),
                    _deleteSlot(context),
                  ],
                );
              },
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final weight = _numberField(
                  key: Key('v2-set-$index-weight'),
                  controller: set.weight,
                  label: 'WEIGHT',
                  suffix: 'kg',
                  decimal: true,
                );
                final reps = _numberField(
                  key: Key('v2-set-$index-reps'),
                  controller: set.reps,
                  label: 'REPS',
                );
                return Row(
                  children: [
                    Expanded(child: weight),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: reps),
                  ],
                );
              },
            ),
            if (set.plannedWeightKg != null || set.targetMinReps != null) ...[
              AppSpacing.gapSM,
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.xs,
                children: [
                  if (set.plannedWeightKg != null)
                    Text(
                      'PLAN  ${_formatDouble(set.plannedWeightKg!)} kg',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (set.targetMinReps != null)
                    Text(
                      'TARGET  ${_targetLabel(set)}',
                      key: Key('v2-set-$index-target'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
            AppSpacing.gapSM,
            LayoutBuilder(
              builder: (context, constraints) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _AdjustmentGrid(
                          key: Key('v2-set-$index-weight-adjustments'),
                          values: const [-10, -5, -2.5, 2.5, 5, 10],
                          onSelected: (value) {
                            final current =
                                double.tryParse(set.weight.text.trim()) ?? 0;
                            set.weight.text = _formatDouble(
                              (current + value).clamp(0, double.infinity),
                            );
                            onChanged();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      children: [
                        _AdjustmentGrid(
                          key: Key('v2-set-$index-reps-adjustments'),
                          values: const [-10, -5, -1, 1, 5, 10],
                          onSelected: (value) {
                            final current =
                                int.tryParse(set.reps.text.trim()) ?? 0;
                            set.reps.text =
                                '${(current + value.toInt()).clamp(0, 1 << 31)}';
                            onChanged();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.gapSM,
            LayoutBuilder(
              builder: (context, constraints) {
                final rpe = DropdownButtonFormField<int?>(
                  key: Key('v2-set-$index-rpe'),
                  initialValue: set.rpe,
                  isExpanded: true,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: const InputDecoration(labelText: 'RPE'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('NOT RECORDED'),
                    ),
                    for (var value = 1; value <= 10; value++)
                      DropdownMenuItem(value: value, child: Text('$value')),
                  ],
                  selectedItemBuilder: (context) => [
                    const Text('NOT RECORDED', overflow: TextOverflow.ellipsis),
                    for (var value = 1; value <= 10; value++) Text('$value'),
                  ],
                  onChanged: (value) {
                    set.rpe = value;
                    onChanged();
                  },
                );
                final rest = _numberField(
                  key: Key('v2-set-$index-rest'),
                  controller: set.rest,
                  label: 'REST',
                  suffix: 'sec',
                );
                return constraints.maxWidth < 300
                    ? Column(children: [rpe, AppSpacing.gapSM, rest])
                    : Row(
                        children: [
                          Expanded(child: rpe),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: rest),
                        ],
                      );
              },
            ),
            AppSpacing.gapXS,
            Row(
              children: [
                for (final seconds in const [30, 45, 60, 90, 120])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs / 2,
                      ),
                      child: OutlinedButton(
                        style: _controlButtonStyle(
                          context,
                          selected: set.rest.text.trim() == '$seconds',
                        ),
                        onPressed: () {
                          set.rest.text = '$seconds';
                          onChanged();
                        },
                        child: Text('$seconds'),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField({
    required Key key,
    required TextEditingController controller,
    required String label,
    String? suffix,
    bool decimal = false,
  }) {
    return TextField(
      key: key,
      controller: controller,
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      onChanged: (_) => onChanged(),
    );
  }

  Widget _setTypeField(BuildContext context) =>
      DropdownButtonFormField<TrainingSetType>(
        key: Key('v2-set-$index-type'),
        initialValue: set.setType,
        isExpanded: true,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: const InputDecoration(
          labelText: 'SET TYPE',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        ),
        items: const [
          DropdownMenuItem(
            value: TrainingSetType.warmUp,
            child: Text('WARM-UP'),
          ),
          DropdownMenuItem(value: TrainingSetType.main, child: Text('MAIN')),
        ],
        onChanged: (value) {
          if (value == null) return;
          set.setType = value;
          onChanged();
        },
      );

  Widget _copyWeightSlot() => SizedBox(
    width: _headerActionSlotWidth,
    height: _headerActionSlotWidth,
    child: previous == null
        ? null
        : IconButton(
            icon: const Icon(Icons.monitor_weight_outlined),
            tooltip: 'Copy previous weight',
            onPressed: () => _copy(previous!.weight, set.weight),
          ),
  );

  Widget _copyRepsSlot() => SizedBox(
    width: _headerActionSlotWidth,
    height: _headerActionSlotWidth,
    child: previous == null
        ? null
        : IconButton(
            icon: const Icon(Icons.repeat),
            tooltip: 'Copy previous reps',
            onPressed: () => _copy(previous!.reps, set.reps),
          ),
  );

  Widget _deleteSlot(BuildContext context) => SizedBox(
    width: _headerActionSlotWidth,
    height: _headerActionSlotWidth,
    child: IconButton(
      key: Key('v2-set-$index-delete'),
      color: Theme.of(context).colorScheme.error,
      icon: const Icon(Icons.delete_outline),
      tooltip: 'Delete set',
      onPressed: onDelete,
    ),
  );

  void _copy(TextEditingController source, TextEditingController target) {
    target.text = source.text;
    target.selection = TextSelection.collapsed(offset: target.text.length);
    onChanged();
  }
}

class _AdjustmentGrid extends StatelessWidget {
  final List<double> values;
  final ValueChanged<double> onSelected;

  const _AdjustmentGrid({
    super.key,
    required this.values,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) AppSpacing.gapXS,
          Row(
            children: [
              for (var column = 0; column < 3; column++) ...[
                if (column > 0) const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: OutlinedButton(
                    style: _controlButtonStyle(context),
                    onPressed: () => onSelected(values[(row * 3) + column]),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(_adjustmentLabel(values[(row * 3) + column])),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

ButtonStyle _controlButtonStyle(BuildContext context, {bool selected = false}) {
  final colors = Theme.of(context).colorScheme;
  return OutlinedButton.styleFrom(
    minimumSize: const Size(0, 38),
    padding: EdgeInsets.zero,
    textStyle: const TextStyle(fontSize: 13),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    backgroundColor: selected ? colors.primaryContainer : null,
    foregroundColor: selected ? colors.onPrimaryContainer : null,
    side: BorderSide(color: selected ? colors.primary : colors.outline),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
  );
}

String _adjustmentLabel(double value) =>
    value > 0 ? '+${_formatDouble(value)}' : _formatDouble(value);

String _formatDouble(double value) {
  return value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);
}

String _targetLabel(TrainingV2SetFormController set) {
  final minimum = set.targetMinReps!;
  final maximum = set.targetMaxReps ?? minimum;
  return minimum == maximum ? '$minimum' : '$minimum–$maximum';
}
