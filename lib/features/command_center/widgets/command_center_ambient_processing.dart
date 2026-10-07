import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A restrained, Command Center-only processing field. It deliberately has no
/// relationship to the Dashboard Ambient Circuit routes or traffic model.
class CommandCenterAmbientProcessing extends StatefulWidget {
  const CommandCenterAmbientProcessing({super.key, required this.enabled});

  static const rootKey = ValueKey('command-center-ambient-processing');
  static const nodesKey = ValueKey('command-center-processing-nodes');
  static const dataBusKey = ValueKey('command-center-data-bus');
  static const memoryBlocksKey = ValueKey('command-center-memory-blocks');

  final bool enabled;

  @override
  State<CommandCenterAmbientProcessing> createState() =>
      _CommandCenterAmbientProcessingState();
}

class _CommandCenterAmbientProcessingState
    extends State<CommandCenterAmbientProcessing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? _nextCycle;
  var _motionAllowed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionAllowed =
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false) &&
        TickerMode.valuesOf(context).enabled;
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant CommandCenterAmbientProcessing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _syncAnimation();
  }

  void _syncAnimation() {
    if (!mounted) return;
    _nextCycle?.cancel();
    _controller.stop();
    if (widget.enabled && _motionAllowed) {
      // Let the Command Center settle first; the ambient system then enters
      // its first quiet processing cycle without competing with navigation.
      _scheduleCycle(const Duration(milliseconds: 900));
    }
  }

  void _scheduleCycle(Duration delay) {
    _nextCycle = Timer(delay, _startCycle);
  }

  void _startCycle() {
    if (!mounted || !widget.enabled || !_motionAllowed) return;
    _controller.forward(from: 0).whenComplete(() {
      if (!mounted || !widget.enabled || !_motionAllowed) return;
      // Processing is intentionally intermittent: a short packet/node/buffer
      // burst, followed by an idle interval that leaves the field quiet.
      _scheduleCycle(const Duration(seconds: 5));
    });
  }

  @override
  void dispose() {
    _nextCycle?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      child: RepaintBoundary(
        key: CommandCenterAmbientProcessing.rootKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              key: CommandCenterAmbientProcessing.dataBusKey,
              painter: _AmbientProcessingPainter(
                animation: _controller,
                color: color,
                staticFrame: !_motionAllowed,
                layer: _AmbientLayer.dataBus,
              ),
            ),
            CustomPaint(
              key: CommandCenterAmbientProcessing.nodesKey,
              painter: _AmbientProcessingPainter(
                animation: _controller,
                color: color,
                staticFrame: !_motionAllowed,
                layer: _AmbientLayer.nodes,
              ),
            ),
            CustomPaint(
              key: CommandCenterAmbientProcessing.memoryBlocksKey,
              painter: _AmbientProcessingPainter(
                animation: _controller,
                color: color,
                staticFrame: !_motionAllowed,
                layer: _AmbientLayer.memory,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AmbientLayer { dataBus, nodes, memory }

class _AmbientProcessingPainter extends CustomPainter {
  const _AmbientProcessingPainter({
    required this.animation,
    required this.color,
    required this.staticFrame,
    required this.layer,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final bool staticFrame;
  final _AmbientLayer layer;

  static const _nodes = <Offset>[
    Offset(.10, .20),
    Offset(.32, .14),
    Offset(.53, .29),
    Offset(.79, .17),
    Offset(.18, .56),
    Offset(.48, .62),
    Offset(.73, .52),
    Offset(.91, .71),
  ];

  static const _routes = <(int, int)>[
    (0, 1),
    (1, 2),
    (2, 3),
    (0, 4),
    (4, 5),
    (5, 6),
    (6, 7),
    (2, 5),
    (3, 6),
  ];

  double get _phase => staticFrame ? .38 : animation.value;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    switch (layer) {
      case _AmbientLayer.dataBus:
        _paintDataBus(canvas, size);
      case _AmbientLayer.nodes:
        _paintNodes(canvas, size);
      case _AmbientLayer.memory:
        _paintMemory(canvas, size);
    }
  }

  Offset _point(Size size, Offset normalized) =>
      Offset(normalized.dx * size.width, normalized.dy * size.height);

  double _pulse(double offset) {
    final cycle = (_phase + offset) % 1;
    final distance = (cycle - .42).abs();
    return (1 - (distance / .18)).clamp(0.0, 1.0);
  }

  void _paintDataBus(Canvas canvas, Size size) {
    final routePaint = Paint()
      ..color = color.withValues(alpha: .075)
      ..strokeWidth = 1;
    final packetPaint = Paint()..style = PaintingStyle.fill;
    for (var index = 0; index < _routes.length; index++) {
      final route = _routes[index];
      final from = _point(size, _nodes[route.$1]);
      final to = _point(size, _nodes[route.$2]);
      final bend = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2 - 10);
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(bend.dx, bend.dy, to.dx, to.dy);
      canvas.drawPath(path, routePaint);

      final strength = _pulse(index * .137);
      if (strength == 0) continue;
      final metrics = path.computeMetrics().first;
      final tangent = metrics.getTangentForOffset(
        metrics.length * ((_phase * .72 + index * .19) % 1),
      );
      if (tangent == null) continue;
      packetPaint.color = color.withValues(alpha: .12 + strength * .28);
      canvas.drawCircle(tangent.position, 1.4 + strength * 1.8, packetPaint);
    }
  }

  void _paintNodes(Canvas canvas, Size size) {
    for (var index = 0; index < _nodes.length; index++) {
      final point = _point(size, _nodes[index]);
      final strength = _nodeStrength(index);
      final halo = Paint()
        ..color = color.withValues(alpha: .025 + strength * .075)
        ..style = PaintingStyle.fill;
      final outline = Paint()
        ..color = color.withValues(alpha: .16 + strength * .32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(point, 8 + strength * 4, halo);
      canvas.drawCircle(point, 3.5 + strength * 1.5, outline);
      if (strength > .08) {
        canvas.drawCircle(
          point,
          1.2 + strength,
          Paint()..color = color.withValues(alpha: .24 + strength * .4),
        );
      }
    }
  }

  double _nodeStrength(int nodeIndex) {
    var strength = 0.0;
    for (var routeIndex = 0; routeIndex < _routes.length; routeIndex++) {
      final route = _routes[routeIndex];
      if (route.$1 == nodeIndex || route.$2 == nodeIndex) {
        strength = math.max(strength, _pulse(routeIndex * .137));
      }
    }
    return strength;
  }

  void _paintMemory(Canvas canvas, Size size) {
    final width = math.min(96.0, size.width * .2);
    const height = 10.0;
    final origins = [
      Offset(size.width * .08, size.height * .79),
      Offset(size.width * .62, size.height * .80),
      Offset(size.width * .38, size.height * .42),
    ];
    for (var bank = 0; bank < origins.length; bank++) {
      final origin = origins[bank];
      for (var cell = 0; cell < 5; cell++) {
        final rect = Rect.fromLTWH(
          origin.dx + cell * (width / 5 + 3),
          origin.dy,
          width / 5,
          height,
        );
        // The bank activity shares route phases with the node and packet
        // field, producing a restrained receive/process/buffer sequence.
        final strength = _pulse((bank * 3 + cell) * .137);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
          Paint()..color = color.withValues(alpha: .07 + strength * .18),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
          Paint()
            ..color = color.withValues(alpha: .1 + strength * .18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .7,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientProcessingPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.staticFrame != staticFrame ||
      oldDelegate.layer != layer;
}
