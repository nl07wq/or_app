import 'package:flutter/material.dart';

import 'mixed_script_text.dart';

class OperationDescription extends StatelessWidget {
  final String text;

  const OperationDescription({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return MixedScriptText(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.6),
    );
  }
}
