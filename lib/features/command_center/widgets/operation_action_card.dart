import 'package:flutter/material.dart';

class OperationActionCard extends StatelessWidget {
  final String? action;

  const OperationActionCard({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    if (action == null || action!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Action',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(action!),
          ],
        ),
      ),
    );
  }
}
