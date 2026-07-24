import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/progression_result.dart';
import '../services/progression_service.dart';

class TrainingProgressionCard extends StatefulWidget {
  final TextEditingController exerciseController;
  final ValueNotifier<String?> equipmentController;

  const TrainingProgressionCard({
    super.key,
    required this.exerciseController,
    required this.equipmentController,
  });

  @override
  State<TrainingProgressionCard> createState() =>
      _TrainingProgressionCardState();
}

class _TrainingProgressionCardState extends State<TrainingProgressionCard> {
  late Future<ProgressionResult?> _result;

  @override
  void initState() {
    super.initState();
    widget.exerciseController.addListener(_refresh);
    widget.equipmentController.addListener(_refresh);
    _result = _load();
  }

  @override
  void didUpdateWidget(covariant TrainingProgressionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.exerciseController, widget.exerciseController)) {
      oldWidget.exerciseController.removeListener(_refresh);
      widget.exerciseController.addListener(_refresh);
    }
    if (!identical(oldWidget.equipmentController, widget.equipmentController)) {
      oldWidget.equipmentController.removeListener(_refresh);
      widget.equipmentController.addListener(_refresh);
    }
    _result = _load();
  }

  @override
  void dispose() {
    widget.exerciseController.removeListener(_refresh);
    widget.equipmentController.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: AppRadius.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progression', style: Theme.of(context).textTheme.titleSmall),
          AppSpacing.gapSM,
          FutureBuilder<ProgressionResult?>(
            future: _result,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Text(
                  'Loading…',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: secondaryColor),
                );
              }

              final result = snapshot.data;
              if (result == null) {
                return Text(
                  'No previous progression data.',
                  key: const Key('progression-empty'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: secondaryColor),
                );
              }

              return Column(
                key: const Key('progression-result'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _resultRow(
                    context,
                    label: 'Last',
                    value:
                        '${_formatWeight(result.lastWeight)}kg ×${result.lastReps}',
                  ),
                  AppSpacing.gapXS,
                  _resultRow(
                    context,
                    label: 'Suggested',
                    value:
                        '${_formatWeight(result.suggestedWeight)}kg '
                        '×${result.suggestedRepsMin}〜${result.suggestedRepsMax}',
                  ),
                  AppSpacing.gapXS,
                  Text(
                    'Reason  ${result.reason}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: secondaryColor),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _resultRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }

  Future<ProgressionResult?> _load() {
    return ProgressionService.loadLatest(
      exerciseName: widget.exerciseController.text,
      equipmentId: widget.equipmentController.value,
    );
  }

  void _refresh() {
    final result = _load();
    setState(() {
      _result = result;
    });
  }

  String _formatWeight(double weight) {
    return weight == weight.truncateToDouble()
        ? weight.toInt().toString()
        : weight.toString();
  }
}
