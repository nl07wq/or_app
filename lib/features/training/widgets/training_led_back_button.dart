import 'package:flutter/material.dart';

import 'training_dot_matrix_title.dart';

abstract final class TrainingLedBackGeometry {
  const TrainingLedBackGeometry._();

  static const matrixColumns = 9;
  static const matrixRows = 7;
  static const activeColumns = 6;
  static const dotPitch = 2.4;
  static const dotRadius = .78;
  static const pattern = <String>[
    '000001000',
    '000111000',
    '001111000',
    '111111000',
    '001111000',
    '000111000',
    '000001000',
  ];
}

/// A standard Back affordance rendered as a compact Training LED matrix.
///
/// Only activation of the visible AppBar control uses the scroll-out motion;
/// system and browser navigation keep Navigator's default behavior.
class TrainingLedBackButton extends StatefulWidget {
  const TrainingLedBackButton({
    super.key,
    this.activeColor = TrainingDotMatrixGeometry.normalActiveColor,
  });

  static const exitDuration = Duration(milliseconds: 200);

  final Color activeColor;

  @override
  State<TrainingLedBackButton> createState() => _TrainingLedBackButtonState();
}

class _TrainingLedBackButtonState extends State<TrainingLedBackButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _exitController;
  bool _popRequested = false;

  @override
  void initState() {
    super.initState();
    _exitController = AnimationController(
      vsync: this,
      duration: TrainingLedBackButton.exitDuration,
    );
  }

  void _handlePressed() {
    if (_popRequested || _exitController.isAnimating) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _popOnce();
      return;
    }
    _exitController.forward(from: 0).whenComplete(_popOnce);
  }

  void _popOnce() {
    if (!mounted || _popRequested) return;
    _popRequested = true;
    Navigator.maybePop(context);
  }

  @override
  void dispose() {
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tooltip = MaterialLocalizations.of(context).backButtonTooltip;
    return Semantics(
      button: true,
      label: tooltip,
      child: IconButton(
        key: const ValueKey('training-led-back'),
        tooltip: tooltip,
        onPressed: _handlePressed,
        icon: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _exitController,
            builder: (context, child) => ClipRect(
              key: const ValueKey('training-led-back-viewport'),
              child: Transform.translate(
                key: const ValueKey('training-led-back-scroll'),
                offset: Offset(-_exitController.value * _LedTriangle.width, 0),
                child: _LedTriangle(activeColor: widget.activeColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LedTriangle extends StatelessWidget {
  const _LedTriangle({required this.activeColor});

  static const width = 16.0;
  static const height = 18.0;

  final Color activeColor;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const ValueKey('training-led-back-triangle'),
    size: const Size(width, height),
    painter: _LedTrianglePainter(activeColor),
  );
}

class _LedTrianglePainter extends CustomPainter {
  const _LedTrianglePainter(this.activeColor);

  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    const pitch = TrainingLedBackGeometry.dotPitch;
    const radius = TrainingLedBackGeometry.dotRadius;
    final origin = Offset(
      (size.width - TrainingLedBackGeometry.activeColumns * pitch) / 2,
      (size.height - TrainingLedBackGeometry.matrixRows * pitch) / 2,
    );
    final bloom = Paint()..color = activeColor.withValues(alpha: .24);
    final body = Paint()..color = activeColor;
    final core = Paint()
      ..color = Color.lerp(activeColor, Colors.white, .72) ?? Colors.white;
    for (var row = 0; row < TrainingLedBackGeometry.pattern.length; row++) {
      for (
        var column = 0;
        column < TrainingLedBackGeometry.pattern[row].length;
        column++
      ) {
        if (TrainingLedBackGeometry.pattern[row][column] != '1') continue;
        final center = Offset(
          origin.dx + column * pitch + radius,
          origin.dy + row * pitch + radius,
        );
        canvas
          ..drawCircle(center, radius * 1.35, bloom)
          ..drawCircle(center, radius, body)
          ..drawCircle(center, radius * .38, core);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LedTrianglePainter oldDelegate) =>
      oldDelegate.activeColor != activeColor;
}
