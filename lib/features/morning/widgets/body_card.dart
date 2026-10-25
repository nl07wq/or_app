import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/widgets/dashboard_glass_card.dart';
import '../../../core/widgets/global_touch_ripple.dart';
import '../../../core/widgets/section_header.dart';

class BodyCard extends StatelessWidget {
  const BodyCard({
    super.key,
    required this.weightController,
    required this.bodyFatController,
    required this.weightUnmeasured,
    required this.onWeightUnmeasured,
    required this.onWeightMeasured,
    this.initiallyExpanded = false,
  });
  final TextEditingController weightController, bodyFatController;
  final bool weightUnmeasured;
  final VoidCallback onWeightUnmeasured, onWeightMeasured;
  final bool initiallyExpanded;
  @override
  Widget build(BuildContext c) => DashboardGlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: SectionHeader(icon: Icons.monitor_weight, title: 'BODY'),
            ),
            _Toggle(
              key: const ValueKey('Weight-unmeasured-toggle'),
              selected: weightUnmeasured,
              onPressed: weightUnmeasured
                  ? onWeightMeasured
                  : onWeightUnmeasured,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (weightUnmeasured)
          const _Unmeasured('Weight')
        else
          _WeightHud(
            key: const ValueKey('status-weight-hud'),
            controller: weightController,
            initiallyExpanded: initiallyExpanded,
          ),
        const SizedBox(height: 28),
        if (weightUnmeasured)
          const _Unmeasured('Body Fat')
        else
          _BodyFatRing(
            key: const ValueKey('status-body-fat-ring'),
            controller: bodyFatController,
            initiallyExpanded: initiallyExpanded,
          ),
      ],
    ),
  );
}

class _WeightHud extends StatefulWidget {
  const _WeightHud({
    super.key,
    required this.controller,
    required this.initiallyExpanded,
  });
  final TextEditingController controller;
  final bool initiallyExpanded;
  @override
  State<_WeightHud> createState() => _WeightHudState();
}

class _WeightHudState extends State<_WeightHud> with TickerProviderStateMixin {
  double v = 100, start = 100, dx = 0;
  bool drag = false;
  late bool _editing;
  late final AnimationController _lockController;
  late final AnimationController _energyController;
  late final AnimationController _armController;
  double _lockStartExpansion = 0;
  @override
  void initState() {
    super.initState();
    _editing =
        widget.initiallyExpanded ||
        double.tryParse(widget.controller.text) == null;
    _lockController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 180),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _editing = false);
            _lockController.reset();
          }
        });
    _energyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _armController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _read();
    widget.controller.addListener(_read);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_read);
    _lockController.dispose();
    _energyController.dispose();
    _armController.dispose();
    super.dispose();
  }

  void _read() {
    final n = (double.tryParse(widget.controller.text) ?? v)
        .clamp(40, 180)
        .toDouble();
    if (n != v && mounted) setState(() => v = n);
  }

  void _set(double n) => widget.controller.text =
      ((n.clamp(40, 180) * 10).round() / 10).toStringAsFixed(1);

  void _setDragging(bool value) {
    if (drag == value) return;
    setState(() => drag = value);
    if (value) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _armController.value = 1;
      } else {
        _armController.forward();
      }
      if (!MediaQuery.disableAnimationsOf(context)) {
        _energyController.repeat();
      }
    } else {
      _energyController
        ..stop()
        ..reset();
      _armController.animateTo(
        0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _confirm() {
    _lockStartExpansion = _expansionForFrame();
    if (drag) setState(() => drag = false);
    _energyController
      ..stop()
      ..reset();
    _armController.stop();
    _lockController.forward(from: 0);
  }

  double _expansionForFrame() {
    final lock = _lockController.value;
    if (lock == 0) return _armController.value;
    if (lock < .5) {
      return _lockStartExpansion + (-1 - _lockStartExpansion) * (lock / .5);
    }
    if (lock < .805) return -1;
    return -1 + (lock - .805) / .195;
  }

  @override
  Widget build(BuildContext c) {
    final cs = Theme.of(c).colorScheme;
    if (!_editing && widget.controller.text.isNotEmpty) {
      return _CollapsedStatusValue(
        key: const ValueKey('status-weight-collapsed'),
        label: 'Weight',
        value: '${v.toStringAsFixed(1)} kg',
        onTap: () => setState(() => _editing = true),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          slider: true,
          label: 'Weight ${v.toStringAsFixed(1)} kilograms',
          child: GestureDetector(
            onHorizontalDragStart: (_) {
              _setDragging(true);
              setState(() {
                start = v;
                dx = 0;
              });
            },
            onHorizontalDragUpdate: (d) {
              dx += d.delta.dx;
              _set(start - dx / 88);
            },
            onHorizontalDragEnd: (_) => _setDragging(false),
            onHorizontalDragCancel: () => _setDragging(false),
            child: SizedBox(
              height: 206,
              width: double.infinity,
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _lockController,
                      _energyController,
                      _armController,
                    ]),
                    builder: (_, _) => TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 110),
                      curve: Curves.easeOutCubic,
                      tween: Tween<double>(end: v),
                      builder: (_, visualValue, _) => CustomPaint(
                        key: const ValueKey('status-weight-tape'),
                        size: Size.infinite,
                        painter: _Tape(
                          visualValue,
                          cs,
                          drag,
                          _lockController.value,
                          _energyController.value,
                          _expansionForFrame(),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 2,
                    child: Center(
                      child: RichText(
                        text: TextSpan(
                          style: Theme.of(c).textTheme.displaySmall?.copyWith(
                            fontFamily: 'ShareTechMono',
                            fontSize: MediaQuery.sizeOf(c).width < 340
                                ? 42
                                : 46,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xffe8ffff),
                            shadows: const [
                              Shadow(
                                color: Color(0xcc000000),
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          children: [
                            TextSpan(text: v.toStringAsFixed(1)),
                            TextSpan(
                              text: ' kg',
                              style: TextStyle(
                                fontSize: 18,
                                color: const Color(
                                  0xffe8ffff,
                                ).withValues(alpha: .72),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('status-weight-done'),
              onPressed: _lockController.isAnimating ? null : _confirm,
              icon: const Icon(Icons.lock_outline, size: 16),
              label: const Text('完了'),
            ).inputFeedback(),
          ),
        ),
      ],
    );
  }
}

class _Tape extends CustomPainter {
  const _Tape(
    this.v,
    this.colors,
    this.active,
    this.lock,
    this.energy,
    this.expansion,
  );
  final double v;
  final ColorScheme colors;
  final bool active;
  final double lock, energy, expansion;

  static const _cyan = Color(0xff20e9ff);
  static const _ice = Color(0xffe8ffff);
  static const _tapeY = 116.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.square;
    final cx = size.width / 2;
    const cy = _tapeY;
    final scale = math.min(1.0, size.width / 270);
    double left(double x) => cx + (x - cx) * scale;
    double right(double x) => size.width - left(x);
    double dx(double x) => x * scale;
    final lockPulse = math.sin(lock * math.pi);
    final energyPulse = active ? 1 - (2 * energy - 1).abs() : 0.0;

    _sideRulers(canvas, paint, left, right);
    _arcs(canvas, paint, cx, cy, scale, expansion, energyPulse);
    _corners(canvas, left, right);
    _tape(canvas, paint, size, cx, cy, scale);
    _reticle(canvas, paint, cx, cy, left, right);
    _centerGuide(canvas, paint, cx, cy);
    _arms(canvas, cx, cy, dx, expansion, lockPulse, energyPulse);
    _centerCursor(canvas, cx, cy, dx, lockPulse);
    _selectedValueLabel(canvas, cx, cy);
  }

  void _tape(
    Canvas canvas,
    Paint paint,
    Size size,
    double cx,
    double cy,
    double scale,
  ) {
    final qCenter = v * 10;
    final first = (qCenter - size.width / (17.6 * scale)).floor() - 1;
    final last = (qCenter + size.width / (17.6 * scale)).ceil() + 1;
    paint
      ..strokeWidth = .95
      ..color = _cyan.withValues(alpha: active ? .65 : .40);
    canvas.drawLine(Offset(18, cy), Offset(size.width - 18, cy), paint);
    for (var q = first; q <= last; q++) {
      if (q < 400 || q > 1800) continue;
      final x = cx + (q - qCenter) * 8.8 * scale;
      if (x < 0 || x > size.width) continue;
      final major = q % 10 == 0;
      final medium = !major && q % 5 == 0;
      final centerRange = 100 * scale;
      final edgeDistance = (x - cx).abs();
      final edgeRange = math.max(1.0, size.width / 2 - centerRange);
      final fade = edgeDistance <= centerRange
          ? 1.0
          : (1 - .5 * ((edgeDistance - centerRange) / edgeRange))
                .clamp(.50, 1.0)
                .toDouble();
      final height = major
          ? 28.0
          : medium
          ? 18.0
          : 10.0;
      paint
        ..strokeWidth = major
            ? 1.7
            : medium
            ? 1.25
            : 1.0
        ..color =
            (major
                    ? const Color(0xff77dfff)
                    : medium
                    ? const Color(0xff5bc9ee)
                    : const Color(0xff62cdeb))
                .withValues(
                  alpha:
                      (major
                          ? active
                                ? .95
                                : .85
                          : medium
                          ? active
                                ? .90
                                : .73
                          : active
                          ? .76
                          : .53) *
                      fade,
                );
      canvas.drawLine(
        Offset(x, cy - height / 2),
        Offset(x, cy + height / 2),
        paint,
      );
      if (major) {
        final label = TextPainter(
          text: TextSpan(
            text: (q ~/ 10).toString(),
            style: TextStyle(
              color: const Color(0xffc5f5ff).withValues(alpha: .88 * fade),
              fontSize: 12,
              fontFamily: 'ShareTechMono',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final selected = TextPainter(
          text: TextSpan(
            text: v.toStringAsFixed(1),
            style: const TextStyle(fontSize: 12, fontFamily: 'ShareTechMono'),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final selectedLeft = cx - selected.width / 2 - 6;
        final selectedRight = cx + selected.width / 2 + 6;
        final overlapsSelected =
            x + label.width / 2 > selectedLeft &&
            x - label.width / 2 < selectedRight;
        if (!overlapsSelected) {
          label.paint(canvas, Offset(x - label.width / 2, 136));
        }
      }
    }
  }

  void _selectedValueLabel(Canvas canvas, double cx, double cy) {
    final selected = TextPainter(
      text: TextSpan(
        text: v.toStringAsFixed(1),
        style: const TextStyle(
          color: Color(0xffe7fcff),
          fontSize: 12,
          fontFamily: 'ShareTechMono',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    selected.paint(canvas, Offset(cx - selected.width / 2, cy + 25));
  }

  void _corners(
    Canvas c,
    double Function(double) left,
    double Function(double) right,
  ) {
    final p = Paint()
      ..color = const Color(0xff52d9f2).withValues(alpha: .70)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    for (final path in [
      Path()
        ..moveTo(left(12), 69)
        ..lineTo(left(12), 38)
        ..lineTo(left(47), 38),
      Path()
        ..moveTo(right(12), 69)
        ..lineTo(right(12), 38)
        ..lineTo(right(47), 38),
      Path()
        ..moveTo(left(12), 162)
        ..lineTo(left(12), 187)
        ..lineTo(left(47), 187),
      Path()
        ..moveTo(right(12), 162)
        ..lineTo(right(12), 187)
        ..lineTo(right(47), 187),
    ]) {
      c.drawPath(path, p);
    }
  }

  void _sideRulers(
    Canvas c,
    Paint p,
    double Function(double) left,
    double Function(double) right,
  ) {
    p
      ..color = const Color(0xff79b7d3).withValues(alpha: .20)
      ..strokeWidth = .55;
    c.drawLine(Offset(left(31), 18), Offset(left(31), 199), p);
    c.drawLine(Offset(right(31), 18), Offset(right(31), 199), p);
    const positions = [46.0, 74.0, 96.0, 136.0, 158.0, 180.0];
    for (var index = 0; index < positions.length; index++) {
      final length = index == 0 || index == positions.length - 1 ? 18.0 : 9.0;
      p
        ..color = const Color(0xff72bbd6).withValues(alpha: .36)
        ..strokeWidth = .8;
      c.drawLine(
        Offset(left(31), positions[index]),
        Offset(left(31 + length), positions[index]),
        p,
      );
      c.drawLine(
        Offset(right(31), positions[index]),
        Offset(right(31 + length), positions[index]),
        p,
      );
    }
  }

  void _arcs(
    Canvas c,
    Paint p,
    double cx,
    double cy,
    double xScale,
    double expansion,
    double energyPulse,
  ) {
    final peak = _lockPeak();
    final geometry = <double>[76, 61, 47];
    final dragDelta = <double>[6, 5, 4];
    final lockDelta = <double>[4, 3.5, 3];
    double radiusFor(int index) =>
        geometry[index] +
        (expansion >= 0
            ? dragDelta[index] * expansion
            : lockDelta[index] * expansion);
    final activeGlow = .16 + .08 * energyPulse;
    final glowAlpha = peak > 0
        ? .05 + .25 * peak
        : active
        ? activeGlow
        : .05;
    final coreAlpha = peak > 0
        ? .78 + .22 * peak
        : active
        ? .88 + .10 * energyPulse
        : .72;
    final coreWidth = peak > 0
        ? 1.9
        : active
        ? 1.65
        : 1.3;
    void draw(double radius, double start, double sweep, Paint paint) {
      c.save();
      c.translate(cx, 0);
      c.scale(xScale, 1);
      c.drawArc(
        Rect.fromCircle(center: Offset(0, cy), radius: radius),
        start * math.pi / 180,
        sweep * math.pi / 180,
        false,
        paint,
      );
      c.restore();
    }

    final layers = [
      Paint()
        ..color = const Color(0xff1adffe).withValues(alpha: glowAlpha)
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt,
      Paint()
        ..color = _cyan.withValues(alpha: coreAlpha)
        ..strokeWidth = coreWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt,
      Paint()
        ..color = const Color(0xfff0ffff).withValues(
          alpha: peak > 0
              ? .70 + .30 * peak
              : active
              ? .68 + .17 * energyPulse
              : .42,
        )
        ..strokeWidth = .7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt,
    ];
    const angles = [
      [112.0, 136.0, -68.0, 136.0],
      [126.0, 108.0, -54.0, 108.0],
      [143.0, 74.0, -37.0, 74.0],
    ];
    for (final layer in layers) {
      for (var index = 0; index < geometry.length; index++) {
        draw(radiusFor(index), angles[index][0], angles[index][1], layer);
        draw(radiusFor(index), angles[index][2], angles[index][3], layer);
      }
    }
    final dotRadius = 39 + (expansion >= 0 ? 4 * expansion : 3 * expansion);
    p
      ..style = PaintingStyle.fill
      ..color = const Color(0xff7bddf0).withValues(alpha: .62);
    for (final range in const [
      [162.0, 198.0],
      [-18.0, 18.0],
    ]) {
      for (var index = 0; index < 7; index++) {
        final radians =
            (range[0] + (range[1] - range[0]) * index / 6) * math.pi / 180;
        c.drawCircle(
          Offset(
            cx + math.cos(radians) * dotRadius * xScale,
            cy + math.sin(radians) * dotRadius,
          ),
          1.15,
          p,
        );
      }
    }
  }

  void _reticle(
    Canvas c,
    Paint p,
    double cx,
    double cy,
    double Function(double) left,
    double Function(double) right,
  ) {
    p
      ..color = const Color(0xff79c9e5).withValues(alpha: .45)
      ..strokeWidth = .9
      ..strokeCap = StrokeCap.square;
    c.drawLine(Offset(left(12), cy), Offset(cx - 83, cy), p);
    c.drawLine(Offset(cx - 69, cy), Offset(cx - 53, cy), p);
    c.drawLine(Offset(cx + 53, cy), Offset(cx + 69, cy), p);
    c.drawLine(Offset(cx + 83, cy), Offset(right(12), cy), p);
  }

  void _centerGuide(Canvas c, Paint p, double cx, double cy) {
    p
      ..color = const Color(0xff82dcf3).withValues(alpha: .25)
      ..strokeWidth = .7;
    c.drawLine(Offset(cx, cy - 70), Offset(cx, cy - 18), p);
    c.drawLine(Offset(cx, cy + 18), Offset(cx, cy + 70), p);
  }

  void _arms(
    Canvas c,
    double cx,
    double cy,
    double Function(double) dx,
    double expansion,
    double lockPulse,
    double energyPulse,
  ) {
    final ix = dx(7) * expansion;
    final iy = 5 * expansion;
    Offset pt(double x, double y) =>
        Offset(cx + dx(x) + x.sign * ix, cy + y + y.sign * iy);
    Path path(List<List<double>> points) {
      final first = pt(points.first[0], points.first[1]);
      final result = Path()..moveTo(first.dx, first.dy);
      for (final pair in points.skip(1)) {
        final next = pt(pair[0], pair[1]);
        result.lineTo(next.dx, next.dy);
      }
      return result;
    }

    final paths = [
      path([
        [-63, -20],
        [-36, -20],
        [-25, -31],
        [-25, -47],
      ]),
      path([
        [63, -20],
        [36, -20],
        [25, -31],
        [25, -47],
      ]),
      path([
        [-63, 20],
        [-36, 20],
        [-25, 31],
        [-25, 47],
      ]),
      path([
        [63, 20],
        [36, 20],
        [25, 31],
        [25, 47],
      ]),
    ];
    final lockPeak = _lockPeak();
    final heldEnergy = active ? energyPulse : 0.0;
    final haloAlpha = lockPeak > 0
        ? .09 + .35 * lockPeak
        : active
        ? .13 + .09 * heldEnergy
        : .08;
    final cyanAlpha = lockPeak > 0
        ? .68 + .32 * lockPeak
        : active
        ? .85 + .15 * heldEnergy
        : .68;
    final iceAlpha = lockPeak > 0
        ? .35 + .60 * lockPeak
        : active
        ? .60 + .32 * heldEnergy
        : .35;
    final paints = [
      Paint()
        ..strokeCap = StrokeCap.square
        ..strokeJoin = StrokeJoin.miter
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = _cyan.withValues(alpha: haloAlpha),
      Paint()
        ..strokeCap = StrokeCap.square
        ..strokeJoin = StrokeJoin.miter
        ..style = PaintingStyle.stroke
        ..strokeWidth = lockPeak > 0 ? 1.8 : 1.8
        ..color = _cyan.withValues(alpha: cyanAlpha),
      Paint()
        ..strokeCap = StrokeCap.square
        ..strokeJoin = StrokeJoin.miter
        ..style = PaintingStyle.stroke
        ..strokeWidth = lockPeak > 0 ? .8 : .7
        ..color = _ice.withValues(alpha: iceAlpha),
    ];
    for (final paint in paints) {
      for (final arm in paths) {
        c.drawPath(arm, paint);
      }
    }
  }

  double _lockPeak() {
    if (lock < .5) return lock / .5;
    if (lock < .805) return 1;
    return 1 - (lock - .805) / .195;
  }

  void _centerCursor(
    Canvas c,
    double cx,
    double cy,
    double Function(double) dx,
    double lockPulse,
  ) {
    final cursorAlpha = active ? 1.0 : .80;
    final p = Paint()
      ..strokeCap = StrokeCap.square
      ..strokeWidth = lockPulse > 0 ? 1.5 : 1.05
      ..color = const Color(0xffd4ffff).withValues(alpha: cursorAlpha);
    c.drawLine(Offset(cx - dx(10), cy), Offset(cx + dx(10), cy), p);
    c.drawLine(Offset(cx, cy - 10), Offset(cx, cy + 10), p);
    p
      ..strokeWidth = .7
      ..color = const Color(0xffd4ffff).withValues(alpha: .50);
    c.drawLine(Offset(cx - dx(5), cy), Offset(cx + dx(5), cy), p);
    c.drawLine(Offset(cx, cy - 5), Offset(cx, cy + 5), p);
  }

  @override
  bool shouldRepaint(covariant _Tape other) =>
      other.v != v ||
      other.colors != colors ||
      other.active != active ||
      other.lock != lock ||
      other.energy != energy ||
      other.expansion != expansion;
}

class _BodyFatRing extends StatefulWidget {
  const _BodyFatRing({
    super.key,
    required this.controller,
    required this.initiallyExpanded,
  });
  final TextEditingController controller;
  final bool initiallyExpanded;
  @override
  State<_BodyFatRing> createState() => _BodyFatRingState();
}

class _BodyFatRingState extends State<_BodyFatRing> {
  double v = 20;
  late bool _editing;
  @override
  void initState() {
    super.initState();
    _editing =
        widget.initiallyExpanded ||
        double.tryParse(widget.controller.text) == null;
    _read();
    widget.controller.addListener(_read);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_read);
    super.dispose();
  }

  void _read() {
    final n = (double.tryParse(widget.controller.text) ?? v)
        .clamp(0, 60)
        .toDouble();
    if (n != v && mounted) setState(() => v = n);
  }

  void _set(double n) => widget.controller.text =
      ((n.clamp(0, 60) * 10).round() / 10).toStringAsFixed(1);
  @override
  Widget build(BuildContext c) {
    final cs = Theme.of(c).colorScheme;
    if (!_editing && widget.controller.text.isNotEmpty) {
      return _CollapsedStatusValue(
        key: const ValueKey('status-body-fat-collapsed'),
        label: 'Body Fat',
        value: '${v.toStringAsFixed(1)} %',
        onTap: () => setState(() => _editing = true),
      );
    }
    final enlargedText = MediaQuery.textScalerOf(c).scale(14) > 14;
    return SizedBox(
      height: enlargedText ? 238 : 194,
      child: Column(
        children: [
          SizedBox(
            height: enlargedText ? 142 : 102,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 300;
                final diameter = compact ? 90.0 : 102.0;
                return Row(
                  children: [
                    SizedBox(
                      width: diameter,
                      height: diameter,
                      child: CustomPaint(painter: _Ring(v, cs.primary)),
                    ),
                    SizedBox(width: compact ? 10 : 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BODY FAT',
                            style: Theme.of(c).textTheme.labelMedium,
                          ),
                          Text(
                            '${v.toStringAsFixed(1)}%',
                            style: Theme.of(c).textTheme.headlineMedium
                                ?.copyWith(
                                  fontFamily: 'ShareTechMono',
                                  fontSize: compact ? 30 : 33,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            '0.1% STEP',
                            style: Theme.of(c).textTheme.labelSmall?.copyWith(
                              color: cs.primary.withValues(alpha: .7),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(
            height: 44,
            child: LayoutBuilder(
              builder: (ctx, b) => GestureDetector(
                onTapDown: (d) => _set(d.localPosition.dx / b.maxWidth * 60),
                onHorizontalDragUpdate: (d) =>
                    _set(d.localPosition.dx / b.maxWidth * 60),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _Rail(v / 60, cs.primary),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey('status-body-fat-done'),
              onPressed: () => setState(() => _editing = false),
              child: const Text('完了'),
            ).inputFeedback(),
          ),
        ],
      ),
    );
  }
}

class _CollapsedStatusValue extends StatelessWidget {
  const _CollapsedStatusValue({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label, value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      label: '$label $value 再編集',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainer.withValues(alpha: .22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: .35)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'ShareTechMono',
                ),
              ),
              Icon(Icons.edit_outlined, size: 18, color: color),
            ],
          ),
        ),
      ).inputFeedback(),
    );
  }
}

class _Ring extends CustomPainter {
  const _Ring(this.v, this.c);
  final double v;
  final Color c;
  @override
  void paint(Canvas x, Size s) {
    final o = s.center(Offset.zero);
    final radius = math.min(s.width, s.height) / 2 - 5;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xff274459).withValues(alpha: .45);
    x.drawCircle(o, radius, p);
    if (v > 0) {
      final rect = Rect.fromCircle(center: o, radius: radius);
      final sweep = 2 * math.pi * v / 60;
      p
        ..shader = null
        ..color = const Color(0xff38b9ff).withValues(alpha: .10)
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;
      x.drawArc(rect, -math.pi / 2, sweep, false, p);
      _drawContinuousProgress(x, rect, sweep, p);
    }
    p
      ..strokeWidth = 1
      ..color = const Color(0xff274459).withValues(alpha: .20);
    x.drawCircle(o, radius * .76, p);
  }

  void _drawContinuousProgress(
    Canvas canvas,
    Rect rect,
    double sweep,
    Paint p,
  ) {
    const segments = 128;
    p
      ..shader = null
      ..strokeWidth = 8.5
      ..strokeCap = StrokeCap.butt;
    for (var index = 0; index < segments; index++) {
      final start = index / segments;
      final end = (index + 1) / segments;
      p.color = _progressColor((start + end) / 2);
      canvas.drawArc(
        rect,
        -math.pi / 2 + sweep * start,
        sweep / segments + .0001,
        false,
        p,
      );
    }
    final center = rect.center;
    final radius = rect.width / 2;
    Offset pointAt(double t) => Offset(
      center.dx + math.cos(-math.pi / 2 + sweep * t) * radius,
      center.dy + math.sin(-math.pi / 2 + sweep * t) * radius,
    );
    p.strokeCap = StrokeCap.round;
    canvas.drawCircle(pointAt(0), 4.25, p..color = _progressColor(0));
    canvas.drawCircle(pointAt(1), 4.25, p..color = _progressColor(1));
  }

  Color _progressColor(double t) {
    const anchors = [
      Color(0xff20e9ff),
      Color(0xff38b9ff),
      Color(0xff576cff),
      Color(0xffad73e8),
    ];
    final position = t.clamp(0.0, 1.0) * (anchors.length - 1);
    final lower = position.floor().clamp(0, anchors.length - 2).toInt();
    return Color.lerp(anchors[lower], anchors[lower + 1], position - lower)!;
  }

  @override
  bool shouldRepaint(covariant _Ring o) => o.v != v || o.c != c;
}

class _Rail extends CustomPainter {
  const _Rail(this.p, this.c);
  final double p;
  final Color c;
  @override
  void paint(Canvas x, Size s) {
    final y = s.height / 2,
        paint = Paint()
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..color = c.withValues(alpha: .12);
    x.drawLine(Offset(4, y), Offset(s.width - 4, y), paint);
    paint.color = c.withValues(alpha: .75);
    x.drawLine(Offset(4, y), Offset(4 + (s.width - 8) * p, y), paint);
    x.drawCircle(Offset(4 + (s.width - 8) * p, y), 6, paint);
  }

  @override
  bool shouldRepaint(covariant _Rail o) => o.p != p || o.c != c;
}

class _Toggle extends StatelessWidget {
  const _Toggle({super.key, required this.selected, required this.onPressed});
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext c) => ChoiceChip(
    label: const Text('未計測'),
    selected: selected,
    onSelected: (_) => onPressed(),
  ).inputFeedback();
}

class _Unmeasured extends StatelessWidget {
  const _Unmeasured(this.title);
  final String title;
  @override
  Widget build(BuildContext c) => Row(
    children: [
      Expanded(
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '未計測',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.lightBlueAccent,
          ),
        ),
      ),
    ],
  );
}
