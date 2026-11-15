import 'package:flutter/material.dart';

import 'global_touch_ripple.dart';
import 'mixed_script_text.dart';
import 'operation_card.dart';

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
    final classicTerminal =
        Theme.of(
          context,
        ).extension<OperationSurfaceTheme>()?.useClassicTerminal ??
        false;
    final scheme = Theme.of(context).colorScheme;
    final themeStyle =
        Theme.of(context).textTheme.bodyMedium ??
        DefaultTextStyle.of(context).style;
    final correctedLabel =
        label != null &&
        label!.isNotEmpty &&
        MixedScriptTypography.shouldCorrect(label!, themeStyle);
    final correctedHint =
        hint != null &&
        hint!.isNotEmpty &&
        MixedScriptTypography.shouldCorrect(hint!, themeStyle);
    return InputFeedbackRegion(
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        keyboardType: keyboardType,
        minLines: minLines,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: correctedLabel || label == null || label!.isEmpty
              ? null
              : label,
          label: correctedLabel ? MixedScriptText(label!) : null,
          hintText: correctedHint ? null : hint,
          hint: correctedHint ? MixedScriptText(hint!) : null,
          filled: glass,
          fillColor: glass
              ? classicTerminal
                    ? scheme.surfaceContainer
                    : scheme.surface.withValues(alpha: .22)
              : null,
          enabledBorder: glass
              ? OutlineInputBorder(
                  borderSide: BorderSide(
                    color: classicTerminal
                        ? scheme.outline
                        : scheme.primary.withValues(alpha: .18),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
