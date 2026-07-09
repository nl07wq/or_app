import 'package:flutter/material.dart';

class SummaryCard extends StatelessWidget {
  final String summary;

  const SummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: const Text("Today's Summary"),
        subtitle: Text(summary),
      ),
    );
  }
}
