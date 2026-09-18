import 'package:flutter/material.dart';

/// Compact, static LED-matrix primitives shared by the Training AppBars.
///
/// The entry screen supplies its own existing character-travel timing; these
/// primitives deliberately contain no ticker or animation state.
abstract final class TrainingDotMatrixGeometry {
  static const word = 'TRAINING';
  static const rowCount = 7;
  static const columnCount = 5;
  static const dotPitch = 2.0;
  static const dotRadius = 0.68;
  static const characterGap = 2.5;
  static const horizontalPadding = 4.0;
  static const verticalPadding = 3.0;

  static const glyphWidth = (columnCount - 1) * dotPitch + dotRadius * 2;
  static const glyphHeight = (rowCount - 1) * dotPitch + dotRadius * 2;
  static const characterAdvance = glyphWidth + characterGap;
  static const wordWidth =
      glyphWidth * word.length + characterGap * (word.length - 1);
  static const panelWidth = wordWidth + horizontalPadding * 2;
  static const panelHeight = glyphHeight + verticalPadding * 2;

  static const activeBodyColor = Color(0xFFFF9E3D);
  static const activeCoreColor = Color(0xFFFFD49A);
  static const activeBloomColor = Color(0x3DFF8C2E);
  static const inactiveDotColor = Color(0xFF4B2B1B);
  static const substrateColor = Color(0xFF17110E);
  static const substrateBorderColor = Color(0xFF4A2A1B);

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
  };

  static double glyphLeft(int index) =>
      horizontalPadding + characterAdvance * index;
}

/// The physical LED panel: a dark substrate plus every inactive matrix point.
class TrainingDotMatrixFrame extends StatelessWidget {
  const TrainingDotMatrixFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: TrainingDotMatrixGeometry.panelWidth,
      height: TrainingDotMatrixGeometry.panelHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: TrainingDotMatrixGeometry.substrateColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: TrainingDotMatrixGeometry.substrateBorderColor,
          ),
        ),
        child: CustomPaint(
          painter: const _InactiveTrainingMatrixPainter(),
          child: child,
        ),
      ),
    );
  }
}

/// Stable, accessibility-labelled Training title for non-active entry views.
class TrainingDotMatrixTitle extends StatelessWidget {
  const TrainingDotMatrixTitle({super.key, this.titleKey});

  final Key? titleKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: TrainingDotMatrixGeometry.word,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            key: titleKey,
            width: TrainingDotMatrixGeometry.panelWidth,
            height: TrainingDotMatrixGeometry.panelHeight,
            child: TrainingDotMatrixFrame(
              child: Stack(
                children: [
                  for (
                    var index = 0;
                    index < TrainingDotMatrixGeometry.word.length;
                    index++
                  )
                    Positioned(
                      left: TrainingDotMatrixGeometry.glyphLeft(index),
                      top: TrainingDotMatrixGeometry.verticalPadding,
                      child: TrainingDotMatrixGlyph(
                        character: TrainingDotMatrixGeometry.word[index],
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

/// One foreground glyph. Dots are painted rather than represented as widgets.
class TrainingDotMatrixGlyph extends StatelessWidget {
  const TrainingDotMatrixGlyph({super.key, required this.character});

  final String character;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: TrainingDotMatrixGeometry.glyphWidth,
      height: TrainingDotMatrixGeometry.glyphHeight,
      child: CustomPaint(painter: _ActiveTrainingGlyphPainter(character)),
    );
  }
}

class _InactiveTrainingMatrixPainter extends CustomPainter {
  const _InactiveTrainingMatrixPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = TrainingDotMatrixGeometry.inactiveDotColor;
    for (
      var glyph = 0;
      glyph < TrainingDotMatrixGeometry.word.length;
      glyph++
    ) {
      final left = TrainingDotMatrixGeometry.glyphLeft(glyph);
      for (var row = 0; row < TrainingDotMatrixGeometry.rowCount; row++) {
        for (
          var column = 0;
          column < TrainingDotMatrixGeometry.columnCount;
          column++
        ) {
          canvas.drawCircle(
            Offset(
              left +
                  column * TrainingDotMatrixGeometry.dotPitch +
                  TrainingDotMatrixGeometry.dotRadius,
              TrainingDotMatrixGeometry.verticalPadding +
                  row * TrainingDotMatrixGeometry.dotPitch +
                  TrainingDotMatrixGeometry.dotRadius,
            ),
            TrainingDotMatrixGeometry.dotRadius * .72,
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _InactiveTrainingMatrixPainter oldDelegate) =>
      false;
}

class _ActiveTrainingGlyphPainter extends CustomPainter {
  const _ActiveTrainingGlyphPainter(this.character);

  final String character;

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = TrainingDotMatrixGeometry.glyphs[character];
    if (matrix == null) return;
    final bloom = Paint()..color = TrainingDotMatrixGeometry.activeBloomColor;
    final body = Paint()..color = TrainingDotMatrixGeometry.activeBodyColor;
    final core = Paint()..color = TrainingDotMatrixGeometry.activeCoreColor;
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
      oldDelegate.character != character;
}
