import 'dart:math' as math;

import 'package:flutter/material.dart';

enum BaseCampWalkerDirection { front, back, left, right }

/// A reusable, scale-independent military walker prototype.  Its local origin
/// is the midpoint between the feet; negative Y values extend upward.
class BaseCampMilitaryWalker extends StatefulWidget {
  const BaseCampMilitaryWalker({
    super.key,
    required this.direction,
    required this.walking,
    this.scale = 1,
  });

  final BaseCampWalkerDirection direction;
  final bool walking;
  final double scale;

  @override
  State<BaseCampMilitaryWalker> createState() => _BaseCampMilitaryWalkerState();
}

class _BaseCampMilitaryWalkerState extends State<BaseCampMilitaryWalker>
    with TickerProviderStateMixin {
  late final AnimationController _cycle;
  late final AnimationController _motionMix;

  @override
  void initState() {
    super.initState();
    _cycle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
    _motionMix = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: widget.walking ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant BaseCampMilitaryWalker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.walking == widget.walking) return;
    _motionMix.animateTo(widget.walking ? 1 : 0, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _cycle.dispose();
    _motionMix.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_cycle, _motionMix]),
      builder: (context, _) => CustomPaint(
        key: ValueKey('base-camp-walker-${widget.direction.name}'),
        painter: BaseCampMilitaryWalkerPainter(
          direction: widget.direction,
          phase: _cycle.value * math.pi * 2,
          walkMix: MediaQuery.disableAnimationsOf(context)
              ? 0
              : _motionMix.value,
          scale: widget.scale,
        ),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

/// Paints one 48 logical-pixel character at the centre of any canvas.
class BaseCampMilitaryWalkerPainter extends CustomPainter {
  const BaseCampMilitaryWalkerPainter({
    required this.direction,
    required this.phase,
    required this.walkMix,
    this.scale = 1,
  });

  final BaseCampWalkerDirection direction;
  final double phase;
  final double walkMix;
  final double scale;

  static const _olive = Color(0xFF626B45);
  static const _darkOlive = Color(0xFF353D2C);
  static const _khaki = Color(0xFF8A8060);
  static const _shadow = Color(0x88151A14);
  static const _boot = Color(0xFF151A14);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + 24 * scale);
    canvas.scale(scale);
    _paintShadow(canvas);
    final gait = math.sin(phase) * walkMix;
    final bob = -1.2 * math.cos(phase * 2) * walkMix;
    if (direction == BaseCampWalkerDirection.left ||
        direction == BaseCampWalkerDirection.right) {
      _paintSide(canvas, gait, bob);
    } else {
      _paintFrontBack(canvas, gait, bob);
    }
    canvas.restore();
  }

  void _paintShadow(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 1), width: 20, height: 5),
      Paint()..color = _shadow,
    );
  }

  void _paintFrontBack(Canvas canvas, double gait, double bob) {
    final backFirst = direction == BaseCampWalkerDirection.front;
    final left = _Leg(hip: const Offset(-4.6, -17), swing: gait);
    final right = _Leg(hip: const Offset(4.6, -17), swing: -gait);
    final backArm = _Arm(
      shoulder: const Offset(-9.5, -32),
      swing: backFirst ? -gait : gait,
    );
    final frontArm = _Arm(
      shoulder: const Offset(9.5, -32),
      swing: backFirst ? gait : -gait,
    );
    _paintLeg(canvas, backFirst ? right : left, _darkOlive, bob);
    _paintArm(canvas, backArm, _darkOlive, bob);
    _paintTorso(canvas, bob, back: direction == BaseCampWalkerDirection.back);
    _paintLeg(canvas, backFirst ? left : right, _olive, bob);
    _paintArm(canvas, frontArm, _olive, bob);
    _paintHead(
      canvas,
      bob,
      side: false,
      back: direction == BaseCampWalkerDirection.back,
    );
  }

  void _paintSide(Canvas canvas, double gait, double bob) {
    final facingLeft = direction == BaseCampWalkerDirection.left;
    final forward = facingLeft ? -1.0 : 1.0;
    final rearLeg = _Leg(hip: const Offset(-2, -17), swing: -gait * forward);
    final nearLeg = _Leg(hip: const Offset(2, -17), swing: gait * forward);
    _paintLeg(canvas, rearLeg, _darkOlive, bob, side: true);
    _paintArm(
      canvas,
      _Arm(shoulder: const Offset(-4, -32), swing: -gait * forward),
      _darkOlive,
      bob,
      side: true,
    );
    _paintSideTorso(canvas, bob, facingLeft);
    _paintLeg(canvas, nearLeg, _olive, bob, side: true);
    _paintArm(
      canvas,
      _Arm(shoulder: const Offset(4, -32), swing: gait * forward),
      _olive,
      bob,
      side: true,
    );
    _paintHead(canvas, bob, side: true, back: false, facingLeft: facingLeft);
  }

  void _paintTorso(Canvas canvas, double bob, {required bool back}) {
    final body = Path()
      ..moveTo(-9.5, -34 + bob)
      ..lineTo(9.5, -34 + bob)
      ..lineTo(7.5, -17 + bob)
      ..lineTo(-7.5, -17 + bob)
      ..close();
    canvas.drawPath(body, Paint()..color = _khaki);
    canvas.drawPath(
      Path()
        ..moveTo(-8, -33 + bob)
        ..lineTo(0, -29 + bob)
        ..lineTo(8, -33 + bob)
        ..lineTo(7, -20 + bob)
        ..lineTo(-7, -20 + bob)
        ..close(),
      Paint()..color = _olive,
    );
    if (back) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(0, -27 + bob), width: 12, height: 10),
          const Radius.circular(2),
        ),
        Paint()..color = _darkOlive,
      );
    } else {
      canvas.drawLine(
        Offset(0, -33 + bob),
        Offset(0, -19 + bob),
        Paint()
          ..color = _darkOlive
          ..strokeWidth = 1.2,
      );
    }
  }

  void _paintSideTorso(Canvas canvas, double bob, bool facingLeft) {
    final forward = facingLeft ? -1.0 : 1.0;
    final body = Path()
      ..moveTo(-7 * forward, -34 + bob)
      ..lineTo(8 * forward, -31 + bob)
      ..lineTo(6 * forward, -17 + bob)
      ..lineTo(-6 * forward, -17 + bob)
      ..close();
    canvas.drawPath(body, Paint()..color = _khaki);
    canvas.drawPath(
      Path()
        ..moveTo(-6 * forward, -32 + bob)
        ..lineTo(6 * forward, -30 + bob)
        ..lineTo(4 * forward, -19 + bob)
        ..lineTo(-5 * forward, -19 + bob)
        ..close(),
      Paint()..color = _olive,
    );
  }

  void _paintHead(
    Canvas canvas,
    double bob, {
    required bool side,
    required bool back,
    bool facingLeft = false,
  }) {
    final center = Offset(side ? (facingLeft ? -1 : 1) : 0, -41 + bob);
    canvas.drawCircle(center, 5.5, Paint()..color = _khaki);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 6),
      math.pi,
      math.pi,
      true,
      Paint()
        ..color = _olive
        ..style = PaintingStyle.fill,
    );
    if (side) {
      final faceX = center.dx + (facingLeft ? -4.2 : 4.2);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(faceX, -40.5 + bob),
          width: 1.6,
          height: 1.2,
        ),
        Paint()..color = _darkOlive,
      );
    } else if (!back) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(0, -40 + bob), width: 5, height: 1.3),
        Paint()..color = _darkOlive,
      );
    }
  }

  void _paintArm(
    Canvas canvas,
    _Arm arm,
    Color color,
    double bob, {
    bool side = false,
  }) {
    final upperAngle = arm.swing * .35;
    final elbow =
        arm.shoulder + Offset(math.sin(upperAngle) * 3.4, 9.4) + Offset(0, bob);
    final bend = arm.swing > 0 ? arm.swing * .32 : 0.0;
    final hand = elbow + Offset(math.sin(upperAngle + bend) * 3.1, 8.4);
    final paint = Paint()
      ..color = color
      ..strokeWidth = side ? 3.1 : 2.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(arm.shoulder + Offset(0, bob), elbow, paint);
    canvas.drawLine(elbow, hand, paint);
    canvas.drawCircle(hand, 1.65, Paint()..color = _khaki);
  }

  void _paintLeg(
    Canvas canvas,
    _Leg leg,
    Color color,
    double bob, {
    bool side = false,
  }) {
    final thighAngle = leg.swing * .436; // ±25 degrees.
    final knee =
        leg.hip + Offset(math.sin(thighAngle) * 5.1, 8.5) + Offset(0, bob);
    final kneeBend = leg.swing > 0 ? leg.swing * .524 : 0.0; // up to 30°.
    final ankle = knee + Offset(math.sin(thighAngle - kneeBend) * 4.2, 8.5);
    final paint = Paint()
      ..color = color
      ..strokeWidth = side ? 4.2 : 3.7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(leg.hip + Offset(0, bob), knee, paint);
    canvas.drawLine(knee, ankle, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: ankle + const Offset(1.8, .5),
          width: 6,
          height: 2.7,
        ),
        const Radius.circular(1),
      ),
      Paint()..color = _boot,
    );
  }

  @override
  bool shouldRepaint(BaseCampMilitaryWalkerPainter oldDelegate) =>
      oldDelegate.direction != direction ||
      oldDelegate.phase != phase ||
      oldDelegate.walkMix != walkMix ||
      oldDelegate.scale != scale;
}

class _Leg {
  const _Leg({required this.hip, required this.swing});

  final Offset hip;
  final double swing;
}

class _Arm {
  const _Arm({required this.shoulder, required this.swing});

  final Offset shoulder;
  final double swing;
}

/// Development-only dialog content.  It is only opened through Base Camp's
/// RESET long press and never appears on the production dashboard by default.
class BaseCampMilitaryWalkerPreview extends StatefulWidget {
  const BaseCampMilitaryWalkerPreview({super.key});

  @override
  State<BaseCampMilitaryWalkerPreview> createState() =>
      _BaseCampMilitaryWalkerPreviewState();
}

class _BaseCampMilitaryWalkerPreviewState
    extends State<BaseCampMilitaryWalkerPreview> {
  BaseCampWalkerDirection _direction = BaseCampWalkerDirection.front;
  bool _walking = true;
  double _scale = 3;

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'BASE CAMP WALKING STUDY',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                IconButton(
                  key: const ValueKey('base-camp-walker-preview-close'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final direction in BaseCampWalkerDirection.values)
                  ChoiceChip(
                    key: ValueKey(
                      'base-camp-walker-direction-${direction.name}',
                    ),
                    label: Text(direction.name.toUpperCase()),
                    selected: _direction == direction,
                    onSelected: (_) => setState(() => _direction = direction),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                ChoiceChip(
                  key: const ValueKey('base-camp-walker-walk'),
                  label: const Text('WALK'),
                  selected: _walking,
                  onSelected: (_) => setState(() => _walking = true),
                ),
                ChoiceChip(
                  key: const ValueKey('base-camp-walker-idle'),
                  label: const Text('IDLE'),
                  selected: !_walking,
                  onSelected: (_) => setState(() => _walking = false),
                ),
                ChoiceChip(
                  key: const ValueKey('base-camp-walker-scale-1'),
                  label: const Text('1×'),
                  selected: _scale == 1,
                  onSelected: (_) => setState(() => _scale = 1),
                ),
                ChoiceChip(
                  key: const ValueKey('base-camp-walker-scale-3'),
                  label: const Text('3×'),
                  selected: _scale == 3,
                  onSelected: (_) => setState(() => _scale = 3),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              key: const ValueKey('base-camp-walker-preview-main'),
              height: 176,
              color: const Color(0xFF17201D),
              child: BaseCampMilitaryWalker(
                direction: _direction,
                walking: _walking,
                scale: _scale,
              ),
            ),
            const SizedBox(height: 12),
            const Text('VERTICAL / HORIZONTAL COMPARISON'),
            const SizedBox(height: 4),
            SizedBox(
              key: const ValueKey('base-camp-walker-preview-comparison'),
              height: 116,
              child: Row(
                children: [
                  Expanded(
                    child: ColoredBox(
                      color: Color(0xFF17201D),
                      child: BaseCampMilitaryWalker(
                        direction: BaseCampWalkerDirection.front,
                        walking: _walking,
                        scale: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ColoredBox(
                      color: Color(0xFF17201D),
                      child: BaseCampMilitaryWalker(
                        direction: BaseCampWalkerDirection.right,
                        walking: _walking,
                        scale: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
