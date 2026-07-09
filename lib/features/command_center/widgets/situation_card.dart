import 'package:flutter/material.dart';

class SituationCard extends StatelessWidget {
  final String situation;

  const SituationCard({
    super.key,
    required this.situation,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: const Text('Situation'),
        subtitle: Text(situation),
      ),
    );
  }
}