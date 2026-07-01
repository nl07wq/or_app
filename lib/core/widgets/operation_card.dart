import 'package:flutter/material.dart';

class OperationCard extends StatelessWidget {
  final Widget child;

  const OperationCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      color:Theme.of(context).cardColor,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}
