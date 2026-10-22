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

class _WeightHudState extends State<_WeightHud>
    with SingleTickerProviderStateMixin {
  double v = 100, start = 100, dx = 0;
  bool drag = false;
  late bool _editing;
  late final AnimationController _lockController;
  @override
  void initState() {
    super.initState();
    _editing = double.tryParse(widget.controller.text) == null;
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
    _read();
    widget.controller.addListener(_read);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_read);
    _lockController.dispose();
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
              height: 140,
              width: double.infinity,
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _lockController,
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
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 4,
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
  const _Tape(this.v, this.colors, this.active, this.lock);
  final double v;
  final ColorScheme colors;
  final bool active;
  final double lock;

  static const _laserCyan = Color(0xff20e9ff);
  static const _laserIce = Color(0xffe8ffff);
  static const _laserBlue = Color(0xff37a9ff);
  static const _unlitTick = Color(0xff4d90ad);
  static const _tapeY = 86.0;

  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..strokeCap = StrokeCap.square;
    final cx = s.width / 2;
    const y = _tapeY;
    final centerQ = v * 10;
    final firstQ = (centerQ - s.width / 17.6).floor() - 1;
    final lastQ = (centerQ + s.width / 17.6).ceil() + 1;
    for (var q = firstQ; q <= lastQ; q++) {
      if (q < 400 || q > 1800) continue;
      final x = cx + (q - centerQ) * 8.8;
      if (x < 0 || x > s.width) continue;
      final major = q % 10 == 0,
          mid = !major && q % 5 == 0,
          fade = (1 - (x - cx).abs() / (s.width * .55))
              .clamp(.18, 1)
              .toDouble();
      p
        ..color = (major ? _laserBlue : _unlitTick).withValues(
          alpha:
              (major
                  ? .72 + (active ? .12 : 0)
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
            text: (q ~/ 10).toString(),
            style: TextStyle(
              color: _laserIce.withValues(alpha: .65 * fade),
              fontSize: 10,
              fontFamily: 'ShareTechMono',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        t.paint(c, Offset(x - t.width / 2, y + 28));
      }
    }
    final lockPulse = math.sin(lock * math.pi);
    final inset = lockPulse * 2;
    final strength = active ? 1.0 : .76;
    final frame = <Path>[
      Path()
        ..moveTo(12 + inset, 58)
        ..lineTo(12 + inset, 39 + inset)
        ..lineTo(48 + inset, 39 + inset),
      Path()
        ..moveTo(s.width - 12 - inset, 58)
        ..lineTo(s.width - 12 - inset, 39 + inset)
        ..lineTo(s.width - 48 - inset, 39 + inset),
      Path()
        ..moveTo(12 + inset, 108)
        ..lineTo(12 + inset, 122 - inset)
        ..lineTo(48 + inset, 122 - inset),
      Path()
        ..moveTo(s.width - 12 - inset, 108)
        ..lineTo(s.width - 12 - inset, 122 - inset)
        ..lineTo(s.width - 48 - inset, 122 - inset),
    ];
    _laserPaths(c, frame, strength: strength, flash: lockPulse);
    final reticle = <Offset>[
      Offset(cx - 80, y),
      Offset(cx - 13, y),
      Offset(cx + 13, y),
      Offset(cx + 80, y),
    ];
    _laserLines(c, reticle, strength: strength, flash: lockPulse);
    _laserLines(
      c,
      [
        Offset(cx - 9, y),
        Offset(cx + 9, y),
        Offset(cx, y - 9),
        Offset(cx, y + 9),
      ],
      strength: 1,
      flash: lockPulse,
    );
    p
      ..style = PaintingStyle.fill
      ..color = _laserIce.withValues(alpha: .9 + lockPulse * .1);
    c.drawCircle(Offset(cx, y), 1.8, p);
  }

  void _laserPaths(
    Canvas canvas,
    List<Path> paths, {
    required double strength,
    required double flash,
  }) {
    for (final paint in _laserPaints(strength, flash)) {
      for (final path in paths) {
        canvas.drawPath(path, paint);
      }
    }
  }

  void _laserLines(
    Canvas canvas,
    List<Offset> endpoints, {
    required double strength,
    required double flash,
  }) {
    for (final paint in _laserPaints(strength, flash)) {
      for (var index = 0; index < endpoints.length; index += 2) {
        canvas.drawLine(endpoints[index], endpoints[index + 1], paint);
      }
    }
  }

  List<Paint> _laserPaints(double strength, double flash) => [
    Paint()
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..color = _laserCyan.withValues(alpha: (.1 + flash * .04) * strength),
    Paint()
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = _laserCyan.withValues(alpha: (.78 + flash * .17) * strength),
    Paint()
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..color = _laserIce.withValues(alpha: (.68 + flash * .22) * strength),
  ];

  @override
  bool shouldRepaint(covariant _Tape o) =>
      o.v != v || o.colors != colors || o.active != active || o.lock != lock;
}

class _BodyFatRing extends StatefulWidget {
  const _BodyFatRing({super.key, required this.controller});
  final TextEditingController controller;
  @override
  State<_BodyFatRing> createState() => _BodyFatRingState();
}

class _BodyFatRingState extends State<_BodyFatRing> {
  double v = 20;
  late bool _editing;
  @override
  void initState() {
    super.initState();
    _editing = double.tryParse(widget.controller.text) == null;
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
    return SizedBox(
      height: 194,
      child: Column(
        children: [
          SizedBox(
            height: 102,
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
    p.color = c.withValues(alpha: .78);
    x.drawArc(
      Rect.fromCircle(center: o, radius: radius),
      -math.pi / 2,
      2 * math.pi * v / 60,
      false,
      p,
    );
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
