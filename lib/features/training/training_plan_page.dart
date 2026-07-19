import 'package:flutter/material.dart';

import '../../core/data/default_training_templates.dart';
import '../../core/widgets/operation_card.dart';

class TrainingPlanPage extends StatelessWidget {
  final Function(List<String>) onSelect;

  const TrainingPlanPage({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Training Plan')),
      body: ListView.builder(
        itemCount: defaultTrainingTemplates.length,
        itemBuilder: (context, index) {
          final plan = defaultTrainingTemplates[index];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OperationCard(
              selectable: true,
              onTap: () async {
                final result = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('トレーニングプランを適用しますか？'),
                    content: const Text('現在の種目は置き換えられます。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('キャンセル'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('適用'),
                      ),
                    ],
                  ),
                );

                if (result != true) return;

                onSelect(plan.exercises);

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.fitness_center),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          plan.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),

                      Text(
                        '${plan.exercises.length} Exercises',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  ...plan.exercises.map(
                    (exercise) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $exercise'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'SELECT ▶',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
