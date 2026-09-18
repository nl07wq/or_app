import 'package:flutter/material.dart';

/// Compact, static LED-matrix primitives shared by the Training AppBars.
///
/// The entry screen supplies its own existing character-travel timing; these
/// primitives deliberately contain no ticker or animation state.
abstract final class TrainingDotMatrixGeometry {
  static const word = 'TRAINING';
  static const rowCount = 7;
  static const columnCount = 5;
  // Scale the complete matrix coherently so the title uses the AppBar's
  // available height without stretching the fixed 5 by 7 glyphs.
  static const dotPitch = 3.0;
  static const dotRadius = 1.0;
  // Narrow the static word margins without removing the physical board space.
  // The modestly wider inter-character pitch keeps the word centered in the
  // same 150px module instead of making either edge read as empty panel.
  static const characterGap = 16 / 7;
  static const horizontalPadding = 11.0;
  static const verticalPadding = 8.0;
  static const activeStagingRightInset = .2;

  static const glyphWidth = (columnCount - 1) * dotPitch + dotRadius * 2;
  static const glyphHeight = (rowCount - 1) * dotPitch + dotRadius * 2;
  static const characterAdvance = glyphWidth + characterGap;
  static const wordWidth =
      glyphWidth * word.length + characterGap * (word.length - 1);
  // Keep the panel clear of the mobile actions while increasing vertical LED
  // presence. The remaining right-side board space is the internal ACTIVE
  // staging region; animated LEDs never leave this physical panel.
  static const panelWidth = 150.0;
  static const panelHeight = glyphHeight + verticalPadding * 2;
  static const surfaceMatrixOriginX = 0.0;
  static const surfaceMatrixOriginY = 0.0;
  static const surfaceMatrixColumnCount = 50;
  static const surfaceMatrixRowCount = 12;
  static const inactiveSurfaceDotCount =
      surfaceMatrixColumnCount * surfaceMatrixRowCount;

  static const normalActiveColor = Color(0xFFF4F7FF);
  static const substrateColor = Color(0xFF17110E);

  static const glyphs = <String, List<String>>{
    'T': <String>[
      '11111',
      '00100',
      '00100',
      '00100',
      '00100',
      '00100',
      '00100',
    ],
    'R': <String>[
      '11110',
      '10001',
      '10001',
      '11110',
      '10100',
      '10010',
      '10001',
    ],
    'A': <String>[
      '01110',
      '10001',
      '10001',
      '11111',
      '10001',
      '10001',
      '10001',
    ],
    'I': <String>[
      '11111',
      '00100',
      '00100',
      '00100',
      '00100',
      '00100',
      '11111',
    ],
    'N': <String>[
      '10001',
      '11001',
      '11001',
      '10101',
      '10011',
      '10011',
      '10001',
    ],
    'G': <String>[
      '01110',
      '10001',
      '10000',
      '10111',
      '10001',
      '10001',
      '01110',
    ],
    'H': <String>[
      '10001',
      '10001',
      '10001',
      '11111',
      '10001',
      '10001',
      '10001',
    ],
    'C': <String>[
      '01111',
      '10000',
      '10000',
      '10000',
      '10000',
      '10000',
      '01111',
    ],
    'E': <String>[
      '11111',
      '10000',
      '10000',
      '11110',
      '10000',
      '10000',
      '11111',
    ],
    'L': <String>[
      '10000',
      '10000',
      '10000',
      '10000',
      '10000',
      '10000',
      '11111',
    ],
    'O': <String>[
      '01110',
      '10001',
      '10001',
      '10001',
      '10001',
      '10001',
      '01110',
    ],
    'P': <String>[
      '11110',
      '10001',
      '10001',
      '11110',
      '10000',
      '10000',
      '10000',
    ],
    'S': <String>[
      '01111',
      '10000',
      '10000',
      '01110',
      '00001',
      '00001',
      '11110',
    ],
    'Y': <String>[
      '10001',
      '10001',
      '01010',
      '00100',
      '00100',
      '00100',
      '00100',
    ],
    ' ': <String>[
      '00000',
      '00000',
      '00000',
      '00000',
      '00000',
      '00000',
      '00000',
    ],
  };

  static double glyphLeft(int index) =>
      horizontalPadding + characterAdvance * index;

  static double widthFor(String title) => title.isEmpty
      ? 0
      : glyphWidth * title.length + characterGap * (title.length - 1);
}

/// A single luminance hierarchy keeps every electronic part of a Training
/// display in the same hue family without brightening the physical board.
class TrainingDotMatrixPalette {
  const TrainingDotMatrixPalette({
    required this.active,
    required this.inactive,
    required this.frame,
  });

  final Color active;
  final Color inactive;
  final Color frame;

  factory TrainingDotMatrixPalette.fromActiveColor(Color active) =>
      TrainingDotMatrixPalette(
        active: active,
        inactive: Color.lerp(const Color(0xFF17110E), active, .22)!,
        frame: active.withValues(alpha: .34),
      );
}

/// The physical LED panel: a dark substrate plus every inactive matrix point.
class TrainingDotMatrixFrame extends StatelessWidget {
  const TrainingDotMatrixFrame({
    super.key,
    required this.child,
    this.palette = const TrainingDotMatrixPalette(
      active: TrainingDotMatrixGeometry.normalActiveColor,
      inactive: Color(0xFF4B4A4A),
      frame: Color(0x665C6066),
    ),
  });

  final Widget child;
  final TrainingDotMatrixPalette palette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: TrainingDotMatrixGeometry.panelWidth,
      height: TrainingDotMatrixGeometry.panelHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: TrainingDotMatrixGeometry.substrateColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: palette.frame),
          ),
          child: CustomPaint(
            painter: _InactiveTrainingMatrixPainter(palette.inactive),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A fixed physical LED panel for Training AppBars.
///
/// Short labels are centered and static.  Long labels retain the established
/// 5 by 7 scale and travel only inside the matrix, like a station board.
class TrainingDotMatrixTitle extends StatefulWidget {
  const TrainingDotMatrixTitle({
    super.key,
    this.title = TrainingDotMatrixGeometry.word,
    this.titleKey,
    this.activeColor = TrainingDotMatrixGeometry.normalActiveColor,
  });

  final String title;
  final Key? titleKey;
  final Color activeColor;

  @override
  State<TrainingDotMatrixTitle> createState() => _TrainingDotMatrixTitleState();
}

class _TrainingDotMatrixTitleState extends State<TrainingDotMatrixTitle>
    with SingleTickerProviderStateMixin {
  static const _startHold = Duration(milliseconds: 900);
  static const _streamGapColumns = 8;
  static const _pixelsPerSecond = 24.0;

  late final AnimationController _controller;
  bool? _marqueeEnabled;

  TrainingDotMatrixPalette get _palette =>
      TrainingDotMatrixPalette.fromActiveColor(widget.activeColor);

  bool get _isLong =>
      TrainingDotMatrixGeometry.widthFor(widget.title) >
      TrainingDotMatrixGeometry.panelWidth -
          TrainingDotMatrixGeometry.horizontalPadding * 2;

  double get _startLeft => TrainingDotMatrixGeometry.horizontalPadding;
  double get _streamGap =>
      _streamGapColumns * TrainingDotMatrixGeometry.dotPitch;
  double get _streamWidth =>
      TrainingDotMatrixGeometry.widthFor(widget.title) + _streamGap;

  Duration get _scrollDuration {
    return Duration(
      milliseconds: (_streamWidth / _pixelsPerSecond * 1000).round(),
    );
  }

  Duration get _cycleDuration => _startHold + _scrollDuration;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMarquee();
  }

  @override
  void didUpdateWidget(covariant TrainingDotMatrixTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) _syncMarquee(force: true);
  }

  void _syncMarquee({bool force = false}) {
    final enabled =
        _isLong && !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (!force && _marqueeEnabled == enabled) return;
    _marqueeEnabled = enabled;
    _controller
      ..stop()
      ..reset()
      ..duration = _cycleDuration;
    if (enabled) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _offsetFor(double progress) {
    final elapsed = progress * _cycleDuration.inMilliseconds;
    final startEnd = _startHold.inMilliseconds;
    if (elapsed <= startEnd) return 0;
    final t = (elapsed - startEnd) / _scrollDuration.inMilliseconds;
    return _streamWidth * t;
  }

  @override
  Widget build(BuildContext context) {
    final staticLeft = _isLong
        ? _startLeft
        : (TrainingDotMatrixGeometry.panelWidth -
                  TrainingDotMatrixGeometry.widthFor(widget.title)) /
              2;
    return Semantics(
      header: true,
      label: widget.title,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            key: widget.titleKey,
            width: TrainingDotMatrixGeometry.panelWidth,
            height: TrainingDotMatrixGeometry.panelHeight,
            child: TrainingDotMatrixFrame(
              palette: _palette,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  if (_marqueeEnabled ?? false)
                    AnimatedBuilder(
                      key: const ValueKey('training-dot-matrix-marquee'),
                      animation: _controller,
                      builder: (context, _) {
                        final left = _startLeft - _offsetFor(_controller.value);
                        return Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            Positioned(
                              left: left,
                              top: TrainingDotMatrixGeometry.verticalPadding,
                              child: _TitleGlyphRun(
                                title: widget.title,
                                activeColor: widget.activeColor,
                              ),
                            ),
                            Positioned(
                              left: left + _streamWidth,
                              top: TrainingDotMatrixGeometry.verticalPadding,
                              child: _TitleGlyphRun(
                                title: widget.title,
                                activeColor: widget.activeColor,
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  else
                    Positioned(
                      left: staticLeft,
                      top: TrainingDotMatrixGeometry.verticalPadding,
                      child: _TitleGlyphRun(
                        title: widget.title,
                        activeColor: widget.activeColor,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleGlyphRun extends StatelessWidget {
  const _TitleGlyphRun({required this.title, required this.activeColor});

  final String title;
  final Color activeColor;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: TrainingDotMatrixGeometry.widthFor(title),
    height: TrainingDotMatrixGeometry.glyphHeight,
    child: Stack(
      children: [
        for (var index = 0; index < title.length; index++)
          Positioned(
            left: TrainingDotMatrixGeometry.characterAdvance * index,
            child: TrainingDotMatrixGlyph(
              character: title[index],
              activeColor: activeColor,
            ),
          ),
      ],
    ),
  );
}

/// One foreground glyph. Dots are painted rather than represented as widgets.
class TrainingDotMatrixGlyph extends StatelessWidget {
  const TrainingDotMatrixGlyph({
    super.key,
    required this.character,
    this.activeColor = TrainingDotMatrixGeometry.normalActiveColor,
  });

  final String character;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: TrainingDotMatrixGeometry.glyphWidth,
      height: TrainingDotMatrixGeometry.glyphHeight,
      child: CustomPaint(
        painter: _ActiveTrainingGlyphPainter(character, activeColor),
      ),
    );
  }
}

class _InactiveTrainingMatrixPainter extends CustomPainter {
  const _InactiveTrainingMatrixPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (
      var row = 0;
      row < TrainingDotMatrixGeometry.surfaceMatrixRowCount;
      row++
    ) {
      for (
        var column = 0;
        column < TrainingDotMatrixGeometry.surfaceMatrixColumnCount;
        column++
      ) {
        canvas.drawCircle(
          Offset(
            TrainingDotMatrixGeometry.surfaceMatrixOriginX +
                column * TrainingDotMatrixGeometry.dotPitch,
            TrainingDotMatrixGeometry.surfaceMatrixOriginY +
                row * TrainingDotMatrixGeometry.dotPitch,
          ),
          TrainingDotMatrixGeometry.dotRadius * .72,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _InactiveTrainingMatrixPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ActiveTrainingGlyphPainter extends CustomPainter {
  const _ActiveTrainingGlyphPainter(this.character, this.activeColor);

  final String character;
  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = TrainingDotMatrixGeometry.glyphs[character];
    if (matrix == null) return;
    final bloom = Paint()..color = activeColor.withValues(alpha: .24);
    final body = Paint()..color = activeColor;
    final core = Paint()
      ..color = Color.lerp(activeColor, Colors.white, .72) ?? Colors.white;
    for (var row = 0; row < matrix.length; row++) {
      for (var column = 0; column < matrix[row].length; column++) {
        if (matrix[row][column] != '1') continue;
        final center = Offset(
          column * TrainingDotMatrixGeometry.dotPitch +
              TrainingDotMatrixGeometry.dotRadius,
          row * TrainingDotMatrixGeometry.dotPitch +
              TrainingDotMatrixGeometry.dotRadius,
        );
        canvas
          ..drawCircle(
            center,
            TrainingDotMatrixGeometry.dotRadius * 1.35,
            bloom,
          )
          ..drawCircle(center, TrainingDotMatrixGeometry.dotRadius, body)
          ..drawCircle(center, TrainingDotMatrixGeometry.dotRadius * .38, core);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ActiveTrainingGlyphPainter oldDelegate) =>
      oldDelegate.character != character ||
      oldDelegate.activeColor != activeColor;
}
