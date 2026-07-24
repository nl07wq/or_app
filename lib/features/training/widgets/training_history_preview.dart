import 'package:flutter/material.dart';

import '../../../core/models/training_set.dart';
import '../../../core/theme/app_spacing.dart';
import '../services/training_history_preview_service.dart';

class TrainingHistoryPreview extends StatefulWidget {
  final TextEditingController exerciseController;

  const TrainingHistoryPreview({super.key, required this.exerciseController});

  @override
  State<TrainingHistoryPreview> createState() => _TrainingHistoryPreviewState();
}

class _TrainingHistoryPreviewState extends State<TrainingHistoryPreview> {
  late Future<List<TrainingSet>?> _history;

  @override
  void initState() {
    super.initState();
    widget.exerciseController.addListener(_refresh);
    _history = _load();
  }

  @override
  void didUpdateWidget(covariant TrainingHistoryPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.exerciseController, widget.exerciseController)) {
      return;
    }

    oldWidget.exerciseController.removeListener(_refresh);
    widget.exerciseController.addListener(_refresh);
    _history = _load();
  }

  @override
  void dispose() {
    widget.exerciseController.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Previous',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: FutureBuilder<List<TrainingSet>?>(
            future: _history,
            builder: (context, snapshot) {
              final sets = snapshot.data;
              final text = snapshot.connectionState == ConnectionState.waiting
                  ? 'Loading…'
                  : sets == null || sets.isEmpty
                  ? 'No previous record'
                  : sets.map(_formatSet).join(' / ');
              return Text(
                text,
                key: const Key('training-history-preview'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: color),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<List<TrainingSet>?> _load() {
    return TrainingHistoryPreviewService.load(widget.exerciseController.text);
  }

  void _refresh() {
    final history = _load();
    setState(() {
      _history = history;
    });
  }

  String _formatSet(TrainingSet set) {
    final weight = set.weight == set.weight.truncateToDouble()
        ? set.weight.toInt().toString()
        : set.weight.toString();
    return '${weight}kg × ${set.reps}';
  }
}
