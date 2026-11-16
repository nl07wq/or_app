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

/// Fixed-geometry LCD ruler shared by BASE CAMP STATUS instruments.
/// Only the marker moves; the ruler never fills from one side.
class BaseCampLcdRuler extends StatelessWidget {
  const BaseCampLcdRuler({
    super.key,
    required this.position,
    this.segmentCount = 20,
    this.markerKey,
  });

  final double position;
  final int segmentCount;
  final Key? markerKey;

  @override
  Widget build(BuildContext context) {
    final palette = BaseCampTerminalPaletteScope.of(context);
    final markerIndex = (position.clamp(0.0, 1.0) * (segmentCount - 1)).round();
    return SizedBox(
      height: 22,
      child: Row(
        children: List<Widget>.generate(segmentCount, (index) {
          final marker = index == markerIndex;
          return Expanded(
            child: Container(
              key: marker ? markerKey : null,
              height: index % 5 == 0 ? 22 : 17,
              margin: EdgeInsets.only(right: index == segmentCount - 1 ? 0 : 2),
              decoration: BoxDecoration(
                color: marker ? palette.primaryText : palette.background,
                border: Border.all(color: palette.auxiliaryText, width: .8),
              ),
            ),
          );
        }),
      ),
    );
  }
}
