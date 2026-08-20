import 'package:flutter/material.dart';

import '../../../core/models/cardio_entry.dart';
import '../../../core/models/cardio_entry_v2.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/training_v2_form_controller.dart';
import '../services/training_cardio_calorie_calculator.dart';
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
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete cardio',
              onPressed: onDelete,
            ),
          ),
          DropdownButtonFormField<CardioType?>(
            key: Key('v2-cardio-$index-type'),
            initialValue: controller.type,
            isExpanded: true,
            decoration: const InputDecoration(),
            items: [
              const DropdownMenuItem(value: null, child: Text('Select Cardio')),
              for (final type in CardioType.values)
                DropdownMenuItem(value: type, child: Text(_typeLabel(type))),
            ],
            onChanged: (value) {
              controller.type = value;
              onChanged();
            },
          ),
          AppSpacing.gapSM,
          DropdownButtonFormField<CardioPurpose?>(
            key: Key('v2-cardio-$index-purpose'),
            initialValue: controller.purpose,
            isExpanded: true,
            decoration: const InputDecoration(),
            items: const [
              DropdownMenuItem(value: null, child: Text('Select Purpose')),
              DropdownMenuItem(
                value: CardioPurpose.warmUp,
                child: Text('Warm-up'),
              ),
              DropdownMenuItem(value: CardioPurpose.main, child: Text('Main')),
              DropdownMenuItem(
                value: CardioPurpose.cooldown,
                child: Text('Cool-down'),
              ),
            ],
            onChanged: (value) {
              controller.purpose = value;
              onChanged();
            },
          ),
          AppSpacing.gapSM,
          TextField(
            key: Key('v2-cardio-$index-duration'),
            controller: controller.duration,
            decoration: const InputDecoration(
              labelText: '時間',
              hintText: 'mm:ss',
            ),
            keyboardType: TextInputType.text,
            onChanged: (_) => onChanged(),
          ),
          AppSpacing.gapSM,
          LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                _pair(
                  constraints.maxWidth,
                  _numberField(
                    controller.distance,
                    '距離',
                    suffix: 'km',
                    decimal: true,
                  ),
                  _numberField(controller.mets, 'METs', decimal: true),
                ),
                AppSpacing.gapSM,
                _pair(
                  constraints.maxWidth,
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
                AppSpacing.gapSM,
                TextField(
                  controller: controller.averageSpeed,
                  decoration: const InputDecoration(
                    labelText: '平均速度',
                    suffixText: 'km/h',
                  ),
                  keyboardType: TextInputType.text,
                  onChanged: (_) => onChanged(),
                ),
              ],
            ),
          ),
          AppSpacing.gapSM,
          InputDecorator(
            decoration: const InputDecoration(labelText: '推定消費カロリー'),
            child: Text(
              calorieResult.isComputed
                  ? '${calorieResult.estimatedCaloriesKcal!.round()} kcal'
                  : 'Not calculated',
            ),
          ),
          AppSpacing.gapXS,
          Text(
            calorieResult.isComputed
                ? 'Calculated from METs, duration, and STATUS weight'
                : _calculationHelp(calorieResult.failureReason),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          AppSpacing.gapSM,
          TextField(
            controller: controller.notes,
            decoration: const InputDecoration(labelText: 'メモ'),
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }

  Widget _pair(double width, Widget first, Widget second) {
    if (width < 520) {
      return Column(children: [first, AppSpacing.gapSM, second]);
    }
    return Row(
      children: [
        Expanded(child: first),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: second),
      ],
    );
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
