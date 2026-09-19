import 'package:flutter/material.dart';

/// The shared FOOD AppBar instrument display. Its self-test is presentation
/// only and intentionally has no connection to Food state or measurements.
class FoodVfdScaleDisplayTitle extends StatefulWidget {
  const FoodVfdScaleDisplayTitle({super.key});

  static const width = 134.0;
  static const height = 35.0;
  static const selfTestDuration = Duration(milliseconds: 760);

  @override
  State<FoodVfdScaleDisplayTitle> createState() =>
      _FoodVfdScaleDisplayTitleState();
}

class _FoodVfdScaleDisplayTitleState extends State<FoodVfdScaleDisplayTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _selfTestController;
  bool _selfTestRequested = false;

  @override
  void initState() {
    super.initState();
    _selfTestController = AnimationController(
      vsync: this,
      duration: FoodVfdScaleDisplayTitle.selfTestDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _selfTestController.value = 1;
      return;
    }
    if (_selfTestRequested) return;
    _selfTestRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selfTestController.forward();
    });
  }

  @override
  void dispose() {
    _selfTestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'FOOD',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            key: const ValueKey('food-vfd-scale-title'),
            width: FoodVfdScaleDisplayTitle.width,
            height: FoodVfdScaleDisplayTitle.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF12191A),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: const Color(0xFF536568), width: .8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: ClipRRect(
                  key: const ValueKey('food-vfd-glass'),
                  borderRadius: BorderRadius.circular(1.5),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF102426),
                          Color(0xFF071113),
                          Color(0xFF050A0B),
                        ],
                        stops: [0, .5, 1],
                      ),
                    ),
                    child: AnimatedBuilder(
                      animation: _selfTestController,
                      builder: (context, _) => Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(
                            key: const ValueKey('food-vfd-inactive-structure'),
                            painter: _FoodVfdDisplayPainter(
                              selfTest: _selfTestController.value,
                            ),
                          ),
                          if (_selfTestController.value < 1)
                            const SizedBox(key: ValueKey('food-vfd-self-test')),
                        ],
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

class _FoodVfdDisplayPainter extends CustomPainter {
  const _FoodVfdDisplayPainter({required this.selfTest});

  final double selfTest;

  @override
  void paint(Canvas canvas, Size size) {
    const glyphs = ['F', 'O', 'O', 'D'];
    const inactive = Color(0x2C55B5A7);
    const bloom = Color(0x4539E0C7);
    const active = Color(0xFF78E9D5);
    final phase = ((selfTest - .3) / .55).clamp(0.0, 1.0);
    final structureBoost = ((selfTest - .1) / .2).clamp(0.0, 1.0);
    final cellWidth = size.width / glyphs.length;
    final glyphHeight = size.height * .68;
    final glyphTop = (size.height - glyphHeight) / 2;

    for (var index = 0; index < glyphs.length; index++) {
      final rect = Rect.fromLTWH(
        index * cellWidth + cellWidth * .18,
        glyphTop,
        cellWidth * .64,
        glyphHeight,
      );
      final allSegments = _segmentsFor('8', rect);
      for (final segment in allSegments) {
        canvas.drawPath(
          segment,
          Paint()
            ..color = inactive.withValues(alpha: .75 + structureBoost * .25),
        );
      }
      final glyphProgress = (phase * glyphs.length - index).clamp(0.0, 1.0);
      if (glyphProgress == 0) continue;
      final opacity = Curves.easeOut.transform(glyphProgress);
      for (final segment in _segmentsFor(glyphs[index], rect)) {
        canvas.drawPath(
          segment,
          Paint()
            ..color = bloom.withValues(alpha: opacity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
        );
        canvas.drawPath(
          segment,
          Paint()..color = active.withValues(alpha: opacity),
        );
      }
    }
  }

  List<Path> _segmentsFor(String glyph, Rect rect) {
    final segments = <String, Path>{
      'a': _horizontal(rect.left, rect.top, rect.width),
      'b': _diagonal(rect.right - rect.width * .18, rect.top, rect.height / 2),
      'c': _diagonal(
        rect.right - rect.width * .18,
        rect.center.dy,
        rect.height / 2,
      ),
      'd': _horizontal(rect.left, rect.bottom - rect.height * .12, rect.width),
      'e': _vertical(rect.left, rect.center.dy, rect.height / 2),
      'f': _vertical(rect.left, rect.top, rect.height / 2),
      'g': _horizontal(
        rect.left,
        rect.center.dy - rect.height * .06,
        rect.width * .72,
      ),
    };
    final enabled = switch (glyph) {
      'F' => const ['a', 'f', 'g', 'e'],
      'O' => const ['a', 'b', 'c', 'd', 'e', 'f'],
      'D' => const ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
      _ => const ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
    };
    return enabled.map((key) => segments[key]!).toList(growable: false);
  }

  Path _horizontal(double left, double top, double width) {
    const thickness = 1.7;
    const bevel = 1.5;
    return Path()
      ..moveTo(left + bevel, top)
      ..lineTo(left + width - bevel, top)
      ..lineTo(left + width, top + thickness / 2)
      ..lineTo(left + width - bevel, top + thickness)
      ..lineTo(left + bevel, top + thickness)
      ..lineTo(left, top + thickness / 2)
      ..close();
  }

  Path _vertical(double left, double top, double height) {
    const thickness = 1.7;
    const bevel = 1.3;
    return Path()
      ..moveTo(left, top + bevel)
      ..lineTo(left + thickness / 2, top)
      ..lineTo(left + thickness, top + bevel)
      ..lineTo(left + thickness, top + height - bevel)
      ..lineTo(left + thickness / 2, top + height)
      ..lineTo(left, top + height - bevel)
      ..close();
  }

  Path _diagonal(double left, double top, double height) {
    const thickness = 1.7;
    return Path()
      ..moveTo(left, top + 1)
      ..lineTo(left + thickness, top)
      ..lineTo(left + thickness, top + height - 1)
      ..lineTo(left, top + height)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _FoodVfdDisplayPainter oldDelegate) =>
      oldDelegate.selfTest != selfTest;
}
