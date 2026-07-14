import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'hud_state.dart';

class HUDScalePainter extends CustomPainter {
  final double value;
  final double animation;
  final HUDState state;

  const HUDScalePainter({
    required this.value,
    required this.animation,
    this.state = HUDState.idle,
  });

  static const double majorSpacing = 140.0;
  static const double minorSpacing = majorSpacing / 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    const centerY = 100.0;

    final majorPaint = Paint()..strokeCap = StrokeCap.round;
    final minorPaint = Paint()..strokeCap = StrokeCap.round;

    final fractional = value - value.floorToDouble();
    final pixelOffset = fractional * majorSpacing;

    final startMajor = value.floor() - 5;
    final endMajor = value.floor() + 5;

    //========================
    // SCALE
    //========================

    for (int major = startMajor; major <= endMajor; major++) {
      final majorX =
          centerX + ((major - value.floor()) * majorSpacing) - pixelOffset;

      if (majorX < -majorSpacing || majorX > size.width + majorSpacing) {
        continue;
      }

      final distance = (majorX - centerX).abs();

      double opacity = 1.0 - (distance / (size.width / 2));

      opacity = opacity.clamp(0.05, 1.0);

      final isCenter = distance < (majorSpacing / 2);

      majorPaint
        ..color = isCenter
            ? Color.lerp(Colors.cyanAccent, Colors.white, 1 - animation)!
            : Colors.white.withValues(alpha: opacity)
        ..strokeWidth = isCenter ? 3.8 : 2.2;

      canvas.drawLine(
        Offset(majorX, centerY - (isCenter ? 32 : 22)),
        Offset(majorX, centerY + (isCenter ? 32 : 20)),
        majorPaint,
      );

      //========================
      // Center Pulse
      //========================

      if (isCenter) {
        final pulse =
            (0.5 +
                    0.5 *
                        (1 +
                            math.sin(
                              DateTime.now().millisecondsSinceEpoch / 220,
                            )))
                .clamp(0.0, 1.0);

        final cursorWidth = switch (state) {
          HUDState.idle => 5.0,
          HUDState.drag => 8.0 + pulse * 2,
          HUDState.locked => 10.0 + pulse * 3,
        };

        final cursorLength = switch (state) {
          HUDState.idle => 78.0,
          HUDState.drag => 92.0 + pulse * 8,
          HUDState.locked => 104.0 + pulse * 10,
        };

        final highlight = Paint()
          ..color = switch (state) {
            HUDState.idle => Colors.white.withValues(alpha: .45),

            HUDState.drag => Colors.white.withValues(alpha: .85),

            HUDState.locked => Colors.greenAccent.withValues(alpha: .95),
          }
          ..strokeWidth = cursorWidth
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(
          Offset(majorX, centerY - cursorLength / 2),
          Offset(majorX, centerY + cursorLength / 2),
          highlight,
        );

        final coreHeight = switch (state) {
          HUDState.idle => 22.0,
          HUDState.drag => 32.0,
          HUDState.locked => 40.0,
        };

        final corePaint = Paint()
          ..color = Colors.white
          ..strokeWidth = cursorWidth * 0.45
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(
          Offset(majorX, centerY - coreHeight / 2),
          Offset(majorX, centerY + coreHeight / 2),
          corePaint,
        );
        if (state == HUDState.drag) {
          final trail = Paint()
            ..color = Colors.white.withValues(alpha: .12)
            ..strokeWidth = cursorWidth * .75
            ..strokeCap = StrokeCap.round;

          for (int i = 1; i <= 4; i++) {
            final offset = i * 14.0;

            canvas.drawLine(
              Offset(majorX, centerY - coreHeight / 2 - offset),
              Offset(majorX, centerY + coreHeight / 2 - offset),
              trail,
            );

            canvas.drawLine(
              Offset(majorX, centerY - coreHeight / 2 + offset),
              Offset(majorX, centerY + coreHeight / 2 + offset),
              trail,
            );
          }
        }
      }

      double textOpacity = opacity;

      if (isCenter) {
        textOpacity = 1.0;
      }

      final tp = TextPainter(
        text: TextSpan(
          text: major.toString(),
          style: TextStyle(
            color: isCenter
                ? Colors.cyanAccent
                : Colors.white.withValues(
                    alpha:
                        textOpacity *
                        (0.35 +
                            (1 - (distance / (size.width * .5))).clamp(
                                  0.0,
                                  1.0,
                                ) *
                                0.65),
                  ),
            fontSize: isCenter
                ? 18
                : (12 +
                      (1 - (distance / (size.width * .5))).clamp(0.0, 1.0) * 4),
            fontWeight: isCenter ? FontWeight.bold : FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      tp.layout();

      tp.paint(canvas, Offset(majorX - tp.width / 2, centerY - 68));

      for (int i = 1; i < 10; i++) {
        final x = majorX + i * minorSpacing;

        if (x < -40 || x > size.width + 40) {
          continue;
        }

        final d = (x - centerX).abs();

        double alpha = 1.0 - (d / (size.width / 2));

        alpha = alpha.clamp(0.05, 1.0);

        final distanceToCursor = (x - centerX).abs();

        final nearCursor = distanceToCursor < minorSpacing * 3.2;

        final depth = (1.0 - (d / (size.width * 0.45))).clamp(0.0, 1.0);

        final length = nearCursor ? 42 + animation * 10 : 22 + depth * 14;

        minorPaint
          ..color = nearCursor
              ? Colors.white.withValues(alpha: .85)
              : Colors.white70.withValues(alpha: alpha)
          ..strokeWidth = nearCursor ? 2.3 : 1.1;

        canvas.drawLine(
          Offset(x, centerY - length * .45),
          Offset(x, centerY + length * .55),
          minorPaint,
        );
      }
    }

    //========================
    // ORLO HUD FRAME
    //========================
    final lockOffset = (1.0 - animation) * 12;

    final frameOffset = switch (state) {
      HUDState.idle => 0.0,
      HUDState.drag => -2.0,
      HUDState.locked => -1.0,
    };
    final expand = Curves.easeOut.transform(animation) * 18;

    final hud = Paint()
      ..color = switch (state) {
        HUDState.idle => Colors.cyanAccent,
        HUDState.drag => Colors.white,
        HUDState.locked => Colors.greenAccent,
      }
      ..strokeWidth = switch (state) {
        HUDState.idle => 2.8 + animation * 1.4,
        HUDState.drag => 4.2 + animation * 1.6,
        HUDState.locked => 3.8,
      }
      ..strokeCap = StrokeCap.round;

    final frameWidth = 340.0 + expand;
    final frameHeight = 170.0 + expand;

    final corner = switch (state) {
      HUDState.idle => 58.0,

      HUDState.drag => 74.0,

      HUDState.locked => 94.0,
    };

    final left = centerX - frameWidth / 2;
    final right = centerX + frameWidth / 2;
    final top = centerY - frameHeight / 2 + frameOffset;
    final bottom = centerY + frameHeight / 2 + frameOffset;

    // Left Top
    canvas.drawLine(
      Offset(left + lockOffset, top),
      Offset(left + corner + lockOffset + animation * 10, top),
      hud,
    );

    canvas.drawLine(
      Offset(left + lockOffset, top),
      Offset(left + lockOffset, top + corner + animation * 10),
      hud,
    );

    // Left Bottom
    canvas.drawLine(
      Offset(left + lockOffset, bottom),
      Offset(left + corner + lockOffset + animation * 10, bottom),
      hud,
    );

    canvas.drawLine(
      Offset(left + lockOffset, bottom),
      Offset(left + lockOffset, bottom - corner - animation * 10),
      hud,
    );

    // Right Top
    canvas.drawLine(
      Offset(right - lockOffset, top),
      Offset(right - corner - lockOffset - animation * 10, top),
      hud,
    );

    canvas.drawLine(
      Offset(right - lockOffset, top),
      Offset(right - lockOffset, top + corner + animation * 10),
      hud,
    );

    // Right Bottom
    canvas.drawLine(
      Offset(right - lockOffset, bottom),
      Offset(right - corner - lockOffset - animation * 10, bottom),
      hud,
    );

    canvas.drawLine(
      Offset(right - lockOffset, bottom),
      Offset(right - lockOffset, bottom - corner - animation * 10),
      hud,
    );

    // Center Vertical
    canvas.drawLine(
      Offset(centerX, top - 24),
      Offset(centerX, bottom + 24),
      hud,
    );

    //========================
    // LOCK RETICLE
    //========================

    final gap = 10 - animation * 4;
    final arm = 18 + animation * 10;

    canvas.drawLine(
      Offset(centerX - arm, centerY),
      Offset(centerX - gap, centerY),
      hud,
    );

    canvas.drawLine(
      Offset(centerX + gap, centerY),
      Offset(centerX + arm, centerY),
      hud,
    );

    // Lock Brackets

    final blink = state == HUDState.locked
        ? (math.sin(DateTime.now().millisecondsSinceEpoch / 80) + 1) / 2
        : 1.0;

    final lock = Paint()
      ..color = switch (state) {
        HUDState.idle => Colors.cyanAccent.withValues(
          alpha: .25 + animation * .45,
        ),

        HUDState.drag => Colors.white.withValues(alpha: .65),

        HUDState.locked => Colors.greenAccent.withValues(
          alpha: .35 + blink * .45,
        ),
      }
      ..strokeWidth = switch (state) {
        HUDState.idle => 1.6,
        HUDState.drag => 2.2,
        HUDState.locked => 2.6,
      };

    final b = switch (state) {
      HUDState.idle => 12.0,
      HUDState.drag => 14.0,
      HUDState.locked => 18.0,
    };

    canvas.drawLine(
      Offset(centerX - (42 - animation * 6), centerY - b),
      Offset(centerX - (42 - animation * 6), centerY + b),
      lock,
    );

    canvas.drawLine(
      Offset(centerX + (42 - animation * 6), centerY - b),
      Offset(centerX + (42 - animation * 6), centerY + b),
      lock,
    );

    //========================
    // OUTER GUIDE
    //========================

    final guide = Paint()
      ..color = Colors.cyanAccent.withValues(
        alpha: 0.10 + Curves.easeOut.transform(animation) * 0.18,
      )
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, centerY), Offset(left - 18, centerY), guide);

    canvas.drawLine(
      Offset(right + 18, centerY),
      Offset(size.width, centerY),
      guide,
    );

    canvas.save();

    canvas.clipRect(Rect.fromLTRB(left, top, right, bottom));

    //========================
    // SCAN LINE
    //========================

    final scan = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: animation * 0.06)
      ..strokeWidth = .8;

    for (double y = top; y <= bottom; y += 12) {
      canvas.drawLine(Offset(left + 12, y), Offset(right - 12, y), scan);
    }

    // Moving Sweep

    final sweepSpeed = switch (state) {
      HUDState.idle => 28.0,
      HUDState.drag => 10.0,
      HUDState.locked => 6.0,
    };

    final sweepY =
        top +
        ((DateTime.now().millisecondsSinceEpoch / sweepSpeed) %
            (frameHeight + 40));

    final sweep = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.cyanAccent.withValues(alpha: .05 + animation * .10),
          Colors.cyanAccent.withValues(alpha: .35 + animation * .25),
          Colors.cyanAccent.withValues(alpha: .05 + animation * .10),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(left, sweepY - 18, frameWidth, 36));

    canvas.drawRect(Rect.fromLTWH(left, sweepY - 18, frameWidth, 36), sweep);

    //========================
    // GLOW
    //========================
    double lockPulse = 0;

    if (state == HUDState.locked) {
      lockPulse =
          (math.sin(DateTime.now().millisecondsSinceEpoch / 55) + 1) * .5;
    }

    final glow = Paint()
      ..color = switch (state) {
        HUDState.idle => Colors.cyanAccent.withValues(alpha: 0.10),

        HUDState.drag => Colors.white.withValues(alpha: 0.28),

        HUDState.locked => Colors.greenAccent.withValues(
          alpha: .18 + lockPulse * .12,
        ),
      }
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        24 + Curves.easeOut.transform(animation) * 18 + lockPulse * 8,
      );

    canvas.drawCircle(
      Offset(centerX, centerY),
      22 + Curves.easeOut.transform(animation) * 16,
      glow,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HUDScalePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.animation != animation;
  }
}
