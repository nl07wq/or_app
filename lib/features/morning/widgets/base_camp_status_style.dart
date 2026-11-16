import 'package:flutter/material.dart';

import '../../themes/base_camp/base_camp_presentation.dart';
import '../../themes/base_camp/base_camp_retro_theme.dart';
import '../../themes/base_camp/base_camp_retro_terminal.dart';

bool isBaseCampStatus(BuildContext context) =>
    BaseCampPresentation.isActive(context) &&
    BaseCampTerminalPaletteScope.maybeOf(context) != null;

TextStyle baseCampStatusReadoutStyle(
  BuildContext context,
  TextStyle? source, {
  double? fontSize,
  Color? color,
}) => (source ?? const TextStyle()).copyWith(
  fontFamily: baseCampPixelFontFamily,
  fontFamilyFallback: const <String>[baseCampJapaneseFontFallback],
  fontSize: fontSize,
  fontWeight: FontWeight.w700,
  height: 1.15,
  letterSpacing: 0,
  color: color ?? BaseCampTerminalPaletteScope.of(context).primaryText,
);

@immutable
class BaseCampStatusControlColors {
  const BaseCampStatusControlColors._({
    required this.background,
    required this.foreground,
    required this.border,
  });

  factory BaseCampStatusControlColors.resolve(
    BuildContext context, {
    required bool selected,
  }) {
    final palette = BaseCampTerminalPaletteScope.of(context);
    return BaseCampStatusControlColors._(
      background: selected ? palette.primaryText : palette.field,
      foreground: selected ? palette.background : palette.primaryText,
      border: selected ? palette.primaryText : palette.auxiliaryText,
    );
  }

  final Color background;
  final Color foreground;
  final Color border;
}

ChoiceChip baseCampStatusChoiceChip({
  required BuildContext context,
  required Widget label,
  required bool selected,
  required ValueChanged<bool> onSelected,
  EdgeInsetsGeometry? labelPadding,
}) {
  final colors = BaseCampStatusControlColors.resolve(
    context,
    selected: selected,
  );
  return ChoiceChip(
    label: DefaultTextStyle.merge(
      style: TextStyle(color: colors.foreground),
      child: label,
    ),
    selected: selected,
    onSelected: onSelected,
    labelPadding: labelPadding,
    backgroundColor: colors.background,
    selectedColor: colors.background,
    checkmarkColor: colors.foreground,
    side: BorderSide(color: colors.border),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    showCheckmark: false,
    labelStyle: TextStyle(color: colors.foreground),
    color: WidgetStatePropertyAll<Color>(colors.background),
  );
}
