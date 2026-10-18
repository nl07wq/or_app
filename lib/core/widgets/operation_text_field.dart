import 'package:flutter/material.dart';

import 'global_touch_ripple.dart';

class OperationTextField extends StatelessWidget {
  final TextEditingController controller;

  final String? label;
  final String? hint;

  final TextInputType keyboardType;
  final int? minLines;
  final int maxLines;
  final FocusNode? focusNode;

  final ValueChanged<String>? onChanged;

  /// Applies the established translucent input surface without changing the
  /// input's focus, error, or keyboard contract.
  final bool glass;

  const OperationTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.minLines,
    this.maxLines = 1,
    this.focusNode,
    this.onChanged,
    this.glass = false,
  });

  @override
  Widget build(BuildContext context) {
    return InputFeedbackRegion(
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        keyboardType: keyboardType,
        minLines: minLines,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: (label == null || label!.isEmpty) ? null : label,
          hintText: hint,
          filled: glass,
          fillColor: glass
              ? Theme.of(context).colorScheme.surface.withValues(alpha: .22)
              : null,
          enabledBorder: glass
              ? OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .18),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
