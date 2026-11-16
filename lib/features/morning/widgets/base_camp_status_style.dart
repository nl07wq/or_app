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

Widget baseCampStatusChoiceChip({
  required BuildContext context,
  required Widget label,
  required bool selected,
  required ValueChanged<bool> onSelected,
  EdgeInsetsGeometry? labelPadding,
  double? height,
}) {
  final colors = BaseCampStatusControlColors.resolve(
    context,
    selected: selected,
  );
  return BaseCampMechanicalButton(
    selected: selected,
    onPressed: () => onSelected(!selected),
    height: height,
    padding:
        labelPadding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    child: DefaultTextStyle.merge(
      style: TextStyle(color: colors.foreground),
      child: label,
    ),
  );
}

/// Recessed numeric/status window used only by BASE CAMP STATUS readouts.
/// The 4px LCD texture is owned by this boundary and never covers controls.
class BaseCampStatusLcdWindow extends StatelessWidget {
  const BaseCampStatusLcdWindow({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    this.height,
    this.width,
    this.finishedValue = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? height;
  final double? width;
  final bool finishedValue;

  static double finishedValueWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 375 ? 120 : 136;

  @override
  Widget build(BuildContext context) {
    final palette = BaseCampTerminalPaletteScope.of(context);
    return SizedBox(
      width: finishedValue ? finishedValueWidth(context) : width,
      height: finishedValue ? 42 : height,
      child: BaseCampLcdSurface(
        palette: palette,
        padding: padding,
        child: Center(child: child),
      ),
    );
  }
}

/// A single-line readout that measures the actual pixel-font glyphs and only
/// reduces the requested size when the LCD aperture cannot contain them.
class BaseCampStatusFittedReadout extends StatelessWidget {
  const BaseCampStatusFittedReadout({
    super.key,
    required this.text,
    required this.style,
    this.minimumFontSize = 8,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final TextStyle style;
  final double minimumFontSize;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      var fontSize = style.fontSize ?? 14;
      final direction = Directionality.of(context);
      while (fontSize > minimumFontSize) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: style.copyWith(fontSize: fontSize),
          ),
          maxLines: 1,
          textDirection: direction,
        )..layout(maxWidth: constraints.maxWidth);
        if (!painter.didExceedMaxLines &&
            painter.width <= constraints.maxWidth &&
            painter.height <= constraints.maxHeight) {
          break;
        }
        fontSize -= .5;
      }
      return Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        textAlign: textAlign,
        style: style.copyWith(fontSize: fontSize.clamp(minimumFontSize, 100)),
      );
    },
  );
}

/// STATUS ENTRY content sits on the terminal chassis. It is intentionally not
/// an LCD surface; individual [BaseCampStatusLcdWindow] instances own all grid
/// rendering.
class BaseCampStatusEntrySurface extends StatelessWidget {
  const BaseCampStatusEntrySurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      BaseCampTerminalPaletteScope.maybeOf(context) == null
      ? child
      : Padding(
          key: const ValueKey('status-entry-physical-content'),
          padding: const EdgeInsets.all(8),
          child: child,
        );
}

/// Physical STATUS control. Momentary controls sink while held; mutually
/// exclusive controls remain sunk while their existing selected state is true.
class BaseCampMechanicalButton extends StatefulWidget {
  const BaseCampMechanicalButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.selected = false,
    this.width,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool selected;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;

  @override
  State<BaseCampMechanicalButton> createState() =>
      _BaseCampMechanicalButtonState();
}

class _BaseCampMechanicalButtonState extends State<BaseCampMechanicalButton> {
  bool _held = false;

  void _setHeld(bool value) {
    if (_held != value && mounted) setState(() => _held = value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = BaseCampTerminalPaletteScope.of(context);
    final enabled = widget.onPressed != null;
    final depressed = enabled && (widget.selected || _held);
    final colors = BaseCampStatusControlColors.resolve(
      context,
      selected: widget.selected,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: BaseCampTerminalPalette.housingShadow,
            border: Border.all(color: BaseCampTerminalPalette.housingEdge),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(0, depressed ? 2 : 0, 0),
              decoration: BoxDecoration(
                color: enabled ? colors.background : palette.auxiliaryText,
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(2),
                boxShadow: depressed
                    ? <BoxShadow>[
                        BoxShadow(
                          color: BaseCampTerminalPalette.housingShadow
                              .withValues(alpha: .45),
                          blurRadius: 1,
                          spreadRadius: 1,
                          blurStyle: BlurStyle.inner,
                        ),
                      ]
                    : <BoxShadow>[
                        const BoxShadow(
                          color: BaseCampTerminalPalette.housingShadow,
                          offset: Offset(0, 2),
                        ),
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onPressed,
                  onHighlightChanged: enabled ? _setHeld : null,
                  child: Padding(
                    padding: widget.padding,
                    child: IconTheme.merge(
                      data: IconThemeData(
                        color: enabled ? colors.foreground : palette.background,
                      ),
                      child: DefaultTextStyle.merge(
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: enabled
                              ? colors.foreground
                              : palette.background,
                        ),
                        child: Center(child: widget.child),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BaseCampStatusCompletionButton extends StatelessWidget {
  const BaseCampStatusCompletionButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => BaseCampMechanicalButton(
    onPressed: onPressed,
    width: 112,
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.lock_outline, size: 15),
        SizedBox(width: 5),
        Text('完了'),
      ],
    ),
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
