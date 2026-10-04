import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A single, non-interactive background layer for the Calendar and Reminder
/// display planes. Its sparse geometry is intentionally independent from the
/// foreground layout so it remains a spatial depth cue rather than a grid.
class HolographicAmbientBackground extends StatefulWidget {
  const HolographicAmbientBackground({super.key});

  @override
  State<HolographicAmbientBackground> createState() =>
      _HolographicAmbientBackgroundState();
}

class _HolographicAmbientBackgroundState
    extends State<HolographicAmbientBackground> {
  static const _period = Duration(seconds: 180);
  static const _step = Duration(milliseconds: 750);

  Timer? _driftTimer;
  double _phase = .18;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configureDrift(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
  }

  void _configureDrift(bool staticMode) {
    _driftTimer?.cancel();
    _driftTimer = null;
    if (staticMode) return;
    _setPhase();
    _driftTimer = Timer.periodic(_step, (_) {
      if (mounted) _setPhase();
    });
  }

  void _setPhase() {
    final elapsed = DateTime.now().microsecondsSinceEpoch;
    final period = _period.inMicroseconds;
    setState(() => _phase = (elapsed % period) / period);
  }

  @override
  void dispose() {
    _driftTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        key: const ValueKey('holographic-ambient-background'),
        painter: _AmbientGeometryPainter(
          color: Theme.of(context).colorScheme.primary,
          phase: _phase,
        ),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _AmbientGeometryPainter extends CustomPainter {
  const _AmbientGeometryPainter({required this.color, required this.phase});

  final Color color;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final wave = phase * math.pi * 2;
    final driftX = math.sin(wave) * size.width * .035;
    final driftY = math.cos(wave) * size.height * .018;
    canvas.save();
    canvas.translate(driftX, driftY);

    final faint = Paint()
      ..color = color.withValues(alpha: .045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final accent = Paint()
      ..color = color.withValues(alpha: .075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15;

    final first = Path()
      ..moveTo(-size.width * .18, size.height * .18)
      ..lineTo(size.width * .16, size.height * .08)
      ..lineTo(size.width * .42, size.height * .30)
      ..lineTo(size.width * 1.12, size.height * .14);
    final second = Path()
      ..moveTo(size.width * .72, -size.height * .12)
      ..lineTo(size.width * .57, size.height * .26)
      ..lineTo(size.width * .86, size.height * .48)
      ..lineTo(size.width * 1.16, size.height * .42);
    final third = Path()
      ..moveTo(-size.width * .12, size.height * .74)
      ..lineTo(size.width * .24, size.height * .62)
      ..lineTo(size.width * .47, size.height * .88)
      ..lineTo(size.width * .78, size.height * 1.08);
    final fourth = Path()
      ..moveTo(size.width * .24, size.height * 1.10)
      ..lineTo(size.width * .50, size.height * .72)
      ..lineTo(size.width * 1.14, size.height * .82);

    canvas.drawPath(first, faint);
    canvas.drawPath(second, faint);
    canvas.drawPath(third, faint);
    canvas.drawPath(fourth, accent);
    final junction = Paint()..color = color.withValues(alpha: .09);
    canvas.drawCircle(
      Offset(size.width * .42, size.height * .30),
      1.4,
      junction,
    );
    canvas.drawCircle(
      Offset(size.width * .57, size.height * .26),
      1.2,
      junction,
    );
    canvas.drawCircle(
      Offset(size.width * .24, size.height * .62),
      1.2,
      junction,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AmbientGeometryPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.phase != phase;
}
