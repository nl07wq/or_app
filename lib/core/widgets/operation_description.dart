import 'package:flutter/material.dart';

class OperationDescription extends StatelessWidget {
  final String text;

  const OperationDescription({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.6),
    );
  }
}
