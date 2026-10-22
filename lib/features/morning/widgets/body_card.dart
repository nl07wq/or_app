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
  });
  final TextEditingController weightController, bodyFatController;
  final bool weightUnmeasured;
  final VoidCallback onWeightUnmeasured, onWeightMeasured;
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
          ),
        const SizedBox(height: 28),
        if (weightUnmeasured)
          const _Unmeasured('Body Fat')
        else
          _BodyFatRing(
            key: const ValueKey('status-body-fat-ring'),
            controller: bodyFatController,
          ),
      ],
    ),
  );
}

class _WeightHud extends StatefulWidget {
  const _WeightHud({super.key, required this.controller});
  final TextEditingController controller;
  @override
  State<_WeightHud> createState() => _WeightHudState();
}

class _WeightHudState extends State<_WeightHud> {
  double v = 100, start = 100, dx = 0;
  bool drag = false;
  @override
  void initState() {
    super.initState();
    if (widget.controller.text.isEmpty) widget.controller.text = '100.0';
    _read();
    widget.controller.addListener(_read);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_read);
    super.dispose();
  }

  void _read() {
    final n = (double.tryParse(widget.controller.text) ?? 100)
        .clamp(40, 180)
        .toDouble();
    if (n != v && mounted) setState(() => v = n);
  }

  void _set(double n) => widget.controller.text =
      ((n.clamp(40, 180) * 10).round() / 10).toStringAsFixed(1);
  @override
  Widget build(BuildContext c) {
    final cs = Theme.of(c).colorScheme;
    return Semantics(
      slider: true,
      label: 'Weight ${v.toStringAsFixed(1)} kilograms',
      child: GestureDetector(
        onHorizontalDragStart: (_) => setState(() {
          drag = true;
          start = v;
          dx = 0;
        }),
        onHorizontalDragUpdate: (d) {
          dx += d.delta.dx;
          _set(start - dx / 88);
        },
        onHorizontalDragEnd: (_) => setState(() => drag = false),
        onHorizontalDragCancel: () => setState(() => drag = false),
        child: SizedBox(
          height: 166,
          width: double.infinity,
          child: Stack(
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: _Tape(v, cs.primary, drag),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 5,
                child: Center(
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(c).textTheme.displaySmall?.copyWith(
                        fontSize: 46,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                      children: [
                        TextSpan(text: v.toStringAsFixed(1)),
                        TextSpan(
                          text: ' kg',
                          style: TextStyle(
                            fontSize: 18,
                            color: cs.onSurface.withValues(alpha: .7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                top: 137,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _hudText(c, 'FLIGHT TAPE'),
                    _hudText(c, drag ? 'ADJUSTING' : 'LOCKED'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Text _hudText(BuildContext c, String s) => Text(
  s,
  style: Theme.of(c).textTheme.labelSmall?.copyWith(
    letterSpacing: 1,
    color: Theme.of(c).colorScheme.primary.withValues(alpha: .65),
  ),
);

class _Tape extends CustomPainter {
  const _Tape(this.v, this.color, this.active);
  final double v;
  final Color color;
  final bool active;
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..strokeCap = StrokeCap.square;
    final cx = s.width / 2, y = 98.0;
    p
      ..color = color.withValues(alpha: .65)
      ..strokeWidth = 1.4;
    for (final sign in [-1, 1]) {
      final x = (sign < 0 ? 8 : s.width - 8).toDouble();
      c.drawLine(Offset(x, y - 62), Offset(x + sign * 28, y - 62), p);
      c.drawLine(Offset(x, y - 62), Offset(x, y - 38), p);
      c.drawLine(Offset(x, y + 62), Offset(x + sign * 28, y + 62), p);
      c.drawLine(Offset(x, y + 62), Offset(x, y + 38), p);
    }
    for (var i = -35; i <= 35; i++) {
      final n = v + i / 10;
      if (n < 40 || n > 180) continue;
      final x = cx + i * 8.8;
      if (x < 0 || x > s.width) continue;
      final major = i % 10 == 0,
          mid = !major && i % 5 == 0,
          fade = (1 - (x - cx).abs() / (s.width * .55))
              .clamp(.18, 1)
              .toDouble();
      p
        ..color = color.withValues(
          alpha:
              (major
                  ? .72
                  : mid
                  ? .48
                  : .28) *
              fade,
        )
        ..strokeWidth = major
            ? 1.5
            : mid
            ? 1.1
            : .75;
      final h =
          (major
                  ? 22
                  : mid
                  ? 16
                  : 9)
              .toDouble();
      c.drawLine(Offset(x, y - h / 2), Offset(x, y + h / 2), p);
      if (major) {
        final t = TextPainter(
          text: TextSpan(
            text: n.round().toString(),
            style: TextStyle(
              color: color.withValues(alpha: .65 * fade),
              fontSize: 10,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        t.paint(c, Offset(x - t.width / 2, y + 28));
      }
    }
    p
      ..color = color.withValues(alpha: active ? 1 : .8)
      ..strokeWidth = 1.5;
    c.drawLine(Offset(cx, y - 33), Offset(cx, y + 33), p);
    c.drawLine(Offset(cx - 11, y), Offset(cx - 3, y), p);
    c.drawLine(Offset(cx + 3, y), Offset(cx + 11, y), p);
    c.drawCircle(Offset(cx, y), 6, p..style = PaintingStyle.stroke);
    p.style = PaintingStyle.fill;
    c.drawPath(
      Path()
        ..moveTo(cx, y - 39)
        ..lineTo(cx - 4, y - 33)
        ..lineTo(cx + 4, y - 33)
        ..close(),
      p,
    );
    c.drawPath(
      Path()
        ..moveTo(cx, y + 39)
        ..lineTo(cx - 4, y + 33)
        ..lineTo(cx + 4, y + 33)
        ..close(),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _Tape o) =>
      o.v != v || o.color != color || o.active != active;
}

class _BodyFatRing extends StatefulWidget {
  const _BodyFatRing({super.key, required this.controller});
  final TextEditingController controller;
  @override
  State<_BodyFatRing> createState() => _BodyFatRingState();
}

class _BodyFatRingState extends State<_BodyFatRing> {
  double v = 20;
  @override
  void initState() {
    super.initState();
    if (widget.controller.text.isEmpty) widget.controller.text = '20.0';
    _read();
    widget.controller.addListener(_read);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_read);
    super.dispose();
  }

  void _read() {
    final n = (double.tryParse(widget.controller.text) ?? 20)
        .clamp(0, 60)
        .toDouble();
    if (n != v && mounted) setState(() => v = n);
  }

  void _set(double n) => widget.controller.text =
      ((n.clamp(0, 60) * 10).round() / 10).toStringAsFixed(1);
  @override
  Widget build(BuildContext c) {
    final cs = Theme.of(c).colorScheme;
    return SizedBox(
      height: 146,
      child: Column(
        children: [
          SizedBox(
            height: 102,
            child: Row(
              children: [
                SizedBox(
                  width: 102,
                  height: 102,
                  child: CustomPaint(painter: _Ring(v, cs.primary)),
                ),
                const SizedBox(width: 16),
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
                        style: Theme.of(c).textTheme.headlineMedium?.copyWith(
                          fontSize: 33,
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
        ],
      ),
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
        p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..color = c.withValues(alpha: .12);
    x.drawCircle(o, 46, p);
    p.color = c.withValues(alpha: .78);
    x.drawArc(
      Rect.fromCircle(center: o, radius: 46),
      -math.pi / 2,
      2 * math.pi * v / 60,
      false,
      p,
    );
    p
      ..strokeWidth = 1
      ..color = c.withValues(alpha: .12);
    x.drawCircle(o, 35, p);
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
