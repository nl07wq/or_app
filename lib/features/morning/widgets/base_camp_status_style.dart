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

/// Fixed-range horizontal instrument used by BASE CAMP STATUS editors.
///
/// The frame and scale never move. Only the fill and index needle follow the
/// normalized value, so adjacent edits cannot visually rebase the instrument.
class BaseCampInstrumentGauge extends StatelessWidget {
  const BaseCampInstrumentGauge({
    super.key,
    required this.position,
    required this.semanticLabel,
    this.onChanged,
    this.markerKey,
    this.divisions = 10,
    this.selectionKeyPrefix,
  });

  final double position;
  final String semanticLabel;
  final ValueChanged<double>? onChanged;
  final Key? markerKey;
  final int divisions;
  final String? selectionKeyPrefix;

  void _update(double dx, double width) {
    if (onChanged == null || width <= 0) return;
    const horizontalInset = 7.0;
    final usableWidth = width - horizontalInset * 2;
    final normalized = usableWidth <= 0
        ? 0.0
        : ((dx - horizontalInset) / usableWidth).clamp(0.0, 1.0);
    onChanged!(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final palette = BaseCampTerminalPaletteScope.of(context);
    final normalized = position.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const horizontalInset = 7.0;
        final needleLeft =
            horizontalInset + normalized * (width - horizontalInset * 2) - 1.5;
        return Semantics(
          slider: onChanged != null,
          label: semanticLabel,
          value: '${(normalized * 100).round()}%',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: onChanged == null
                ? null
                : (details) => _update(details.localPosition.dx, width),
            onHorizontalDragUpdate: onChanged == null
                ? null
                : (details) => _update(details.localPosition.dx, width),
            child: SizedBox(
              height: 34,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BaseCampInstrumentGaugePainter(
                        palette: palette,
                        position: normalized,
                        divisions: divisions,
                      ),
                    ),
                  ),
                  if (selectionKeyPrefix != null)
                    Positioned.fill(
                      left: horizontalInset,
                      right: horizontalInset,
                      child: Row(
                        children: List<Widget>.generate(divisions, (index) {
                          final level = index + 1;
                          return Expanded(
                            child: Semantics(
                              button: true,
                              selected: normalized >= level / divisions,
                              label: '$semanticLabel $level',
                              child: GestureDetector(
                                key: ValueKey('$selectionKeyPrefix-$level'),
                                behavior: HitTestBehavior.translucent,
                                onTap: onChanged == null
                                    ? null
                                    : () => onChanged!(level / divisions),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  Positioned(
                    key: markerKey,
                    left: needleLeft,
                    top: 4,
                    width: 3,
                    height: 26,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: palette.primaryText),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BaseCampInstrumentGaugePainter extends CustomPainter {
  const _BaseCampInstrumentGaugePainter({
    required this.palette,
    required this.position,
    required this.divisions,
  });

  final BaseCampTerminalPalette palette;
  final double position;
  final int divisions;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(3),
    );
    canvas.drawRRect(frame, Paint()..color = palette.background);
    canvas.drawRRect(
      frame.deflate(.75),
      Paint()
        ..color = palette.auxiliaryText
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final track = Rect.fromLTRB(7, 9, size.width - 7, size.height - 9);
    canvas.drawRect(track, Paint()..color = palette.field);
    final fillWidth = track.width * position;
    if (fillWidth > 0) {
      canvas.drawRect(
        Rect.fromLTWH(track.left, track.top, fillWidth, track.height),
        Paint()..color = palette.auxiliaryText,
      );
    }
    canvas.drawRect(
      track,
      Paint()
        ..color = palette.primaryText
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final tickPaint = Paint()
      ..color = palette.primaryText.withValues(alpha: .58)
      ..strokeWidth = 1;
    for (var index = 0; index <= divisions; index++) {
      final x = track.left + track.width * index / divisions;
      final major = index == 0 || index == divisions || index.isEven;
      canvas.drawLine(
        Offset(x, major ? 4 : 6),
        Offset(x, track.top - 1),
        tickPaint,
      );
      canvas.drawLine(
        Offset(x, track.bottom + 1),
        Offset(x, major ? size.height - 4 : size.height - 6),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BaseCampInstrumentGaugePainter oldDelegate) =>
      oldDelegate.position != position ||
      oldDelegate.divisions != divisions ||
      oldDelegate.palette != palette;
}
