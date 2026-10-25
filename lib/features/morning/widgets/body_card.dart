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
    _read();
    widget.controller.addListener(_read);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_read);
    _lockController.dispose();
    _energyController.dispose();
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
    if (value && !MediaQuery.disableAnimationsOf(context)) {
      _energyController.repeat();
    } else {
      _energyController
        ..stop()
        ..reset();
    }
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
              onPressed: _lockController.isAnimating
                  ? null
                  : () => _lockController.forward(),
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
  const _Tape(this.v, this.colors, this.active, this.lock, this.energy);
  final double v;
  final ColorScheme colors;
  final bool active;
  final double lock, energy;

  static const _cyan = Color(0xff20e9ff);
  static const _ice = Color(0xffe8ffff);
  static const _blue = Color(0xff37a9ff);
  static const _dim = Color(0xff4d90ad);
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
    _arcs(canvas, paint, cx, cy, scale);
    _corners(canvas, left, right);
    _tape(canvas, paint, size, cx, cy, scale);
    _reticle(canvas, paint, cx, cy, left, right);
    _centerGuide(canvas, paint, cx, cy);
    _arms(canvas, cx, cy, dx, lockPulse, energyPulse);
    _laserLines(
      canvas,
      [
        Offset(cx - dx(5), cy),
        Offset(cx + dx(5), cy),
        Offset(cx, cy - 5),
        Offset(cx, cy + 5),
      ],
      .55,
      lockPulse,
    );
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
    for (var q = first; q <= last; q++) {
      if (q < 400 || q > 1800) continue;
      final x = cx + (q - qCenter) * 8.8 * scale;
      if (x < 0 || x > size.width || (x - cx).abs() < 28 * scale) continue;
      final major = q % 10 == 0;
      final medium = !major && q % 5 == 0;
      final fade = (1 - (x - cx).abs() / (size.width * .55))
          .clamp(.18, 1.0)
          .toDouble();
      final height = major
          ? 22.0
          : medium
          ? 16.0
          : 9.0;
      paint
        ..strokeWidth = major
            ? 1.5
            : medium
            ? 1.1
            : .75
        ..color = (major ? _blue : _dim).withValues(
          alpha:
              (major
                  ? .72 + (active ? .12 : 0)
                  : medium
                  ? .48
                  : .28) *
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
              color: _ice.withValues(alpha: .65 * fade),
              fontSize: 10,
              fontFamily: 'ShareTechMono',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, Offset(x - label.width / 2, cy + 16));
      }
    }
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

  void _arcs(Canvas c, Paint p, double cx, double cy, double xScale) {
    void draw(
      double radius,
      double start,
      double sweep,
      Color color,
      double alpha,
      double width,
    ) {
      c.save();
      c.translate(cx, 0);
      c.scale(xScale, 1);
      p
        ..color = color.withValues(alpha: alpha)
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;
      c.drawArc(
        Rect.fromCircle(center: Offset(0, cy), radius: radius),
        start * math.pi / 180,
        sweep * math.pi / 180,
        false,
        p,
      );
      c.restore();
    }

    draw(76, 112, 136, const Color(0xff4cbee2), .64, 1.25);
    draw(76, -68, 136, const Color(0xff4cbee2), .64, 1.25);
    draw(61, 126, 108, const Color(0xff62cee8), .66, 1.15);
    draw(61, -54, 108, const Color(0xff62cee8), .66, 1.15);
    draw(47, 143, 74, const Color(0xff8adff0), .82, 1.15);
    draw(47, -37, 74, const Color(0xff8adff0), .82, 1.15);
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
            cx + math.cos(radians) * 39 * xScale,
            cy + math.sin(radians) * 39,
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
    double lockPulse,
    double energyPulse,
  ) {
    final ix = dx(3) * lockPulse;
    final iy = 2 * lockPulse;
    Offset pt(double x, double y) =>
        Offset(cx + dx(x) - x.sign * ix, cy + y - y.sign * iy);
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
    final strength = active ? 1 + energyPulse * .13 : .85;
    for (final p in _laserPaints(strength, lockPulse + energyPulse * .13)) {
      for (final arm in paths) {
        c.drawPath(arm, p);
      }
    }
  }

  void _laserLines(
    Canvas c,
    List<Offset> points,
    double strength,
    double flash,
  ) {
    for (final p in _laserPaints(strength, flash)) {
      for (var index = 0; index < points.length; index += 2) {
        c.drawLine(points[index], points[index + 1], p);
      }
    }
  }

  List<Paint> _laserPaints(double strength, double flash) => [
    Paint()
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = _cyan.withValues(alpha: (.08 + flash * .08) * strength),
    Paint()
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..color = _cyan.withValues(alpha: (.72 + flash * .24) * strength),
    Paint()
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke
      ..strokeWidth = .60
      ..color = _ice.withValues(alpha: (.42 + flash * .38) * strength),
  ];

  @override
  bool shouldRepaint(covariant _Tape other) =>
      other.v != v ||
      other.colors != colors ||
      other.active != active ||
      other.lock != lock ||
      other.energy != energy;
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
    final o = s.center(Offset.zero),
        radius = math.min(s.width, s.height) / 2 - 5,
        p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..color = c.withValues(alpha: .12);
    x.drawCircle(o, radius, p);
    if (v > 0) {
      final rect = Rect.fromCircle(center: o, radius: radius);
      p.shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 3 / 2,
        colors: [
          Color(0xff20cfe4),
          Color(0xff3bb5ee),
          Color(0xff668fe6),
          Color(0xff827dd8),
        ],
      ).createShader(rect);
      x.drawArc(rect, -math.pi / 2, 2 * math.pi * v / 60, false, p);
      p.shader = null;
    }
    p
      ..strokeWidth = 1
      ..color = c.withValues(alpha: .12);
    x.drawCircle(o, radius * .76, p);
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
