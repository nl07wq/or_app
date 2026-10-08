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

  /// Maps the single deterministic timeline to its current processing frame.
  /// Keeping this public makes the sequence library independently testable
  /// without adding a production debug control.
  @visibleForTesting
  static AmbientProcessingFrame frameAt(double timeline) =>
      AmbientProcessingFrame.fromTimeline(timeline);

  @override
  State<CommandCenterAmbientProcessing> createState() =>
      _CommandCenterAmbientProcessingState();
}

enum AmbientProcessingSequence {
  idle,
  ingestRoute,
  parallelProcessing,
  bufferWriteFlush,
  verifyAcknowledge,
  routeBranch,
  highLoadBurst,
}

/// A bounded, deterministic processing event followed by a real quiet period.
@immutable
class AmbientProcessingFrame {
  const AmbientProcessingFrame({
    required this.sequence,
    required this.progress,
    required this.isIdle,
  });

  final AmbientProcessingSequence sequence;
  final double progress;
  final bool isIdle;

  static const _sequences = <AmbientProcessingSequence>[
    AmbientProcessingSequence.ingestRoute,
    AmbientProcessingSequence.parallelProcessing,
    AmbientProcessingSequence.bufferWriteFlush,
    AmbientProcessingSequence.verifyAcknowledge,
    AmbientProcessingSequence.routeBranch,
    AmbientProcessingSequence.highLoadBurst,
  ];

  static AmbientProcessingFrame fromTimeline(double timeline) {
    final normalized = timeline.clamp(0.0, 1.0);
    final slot = normalized * _sequences.length;
    final index = math.min(slot.floor(), _sequences.length - 1);
    final local = slot - index;
    // Each 9-second slot is 6.7 seconds of purposeful work and 2.3 seconds
    // of quiet. This is represented proportionally so the painter owns one
    // timeline regardless of frame rate.
    const activeEnd = .74;
    if (local >= activeEnd) {
      return const AmbientProcessingFrame(
        sequence: AmbientProcessingSequence.idle,
        progress: 0,
        isIdle: true,
      );
    }
    return AmbientProcessingFrame(
      sequence: _sequences[index],
      progress: (local / activeEnd).clamp(0.0, 1.0),
      isIdle: false,
    );
  }
}

class _CommandCenterAmbientProcessingState
    extends State<CommandCenterAmbientProcessing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6700),
  );
  Timer? _startDelay;
  var _motionAllowed = false;
  var _sequenceIndex = 0;
  var _isIdle = true;

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
    _startDelay?.cancel();
    _controller.stop();
    _isIdle = true;
    if (widget.enabled && _motionAllowed) {
      // Allow navigation to settle before the first processing event. From
      // there a single coordinated timeline owns both events and idle spans.
      _startDelay = Timer(const Duration(milliseconds: 900), () {
        if (mounted && widget.enabled && _motionAllowed) _startSequence();
      });
    } else {
      _controller.value = 0;
    }
  }

  void _startSequence() {
    if (!mounted || !widget.enabled || !_motionAllowed) return;
    setState(() => _isIdle = false);
    _controller.forward(from: 0).whenComplete(() {
      if (!mounted || !widget.enabled || !_motionAllowed) return;
      setState(() {
        _isIdle = true;
        _sequenceIndex = (_sequenceIndex + 1) % _processingSequences.length;
      });
      _startDelay = Timer(const Duration(milliseconds: 2300), _startSequence);
    });
  }

  @override
  void dispose() {
    _startDelay?.cancel();
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
                sequence: _processingSequences[_sequenceIndex],
                idle: _isIdle,
                layer: _AmbientLayer.dataBus,
              ),
            ),
            CustomPaint(
              key: CommandCenterAmbientProcessing.nodesKey,
              painter: _AmbientProcessingPainter(
                animation: _controller,
                color: color,
                staticFrame: !_motionAllowed,
                sequence: _processingSequences[_sequenceIndex],
                idle: _isIdle,
                layer: _AmbientLayer.nodes,
              ),
            ),
            CustomPaint(
              key: CommandCenterAmbientProcessing.memoryBlocksKey,
              painter: _AmbientProcessingPainter(
                animation: _controller,
                color: color,
                staticFrame: !_motionAllowed,
                sequence: _processingSequences[_sequenceIndex],
                idle: _isIdle,
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

const _processingSequences = <AmbientProcessingSequence>[
  AmbientProcessingSequence.ingestRoute,
  AmbientProcessingSequence.parallelProcessing,
  AmbientProcessingSequence.bufferWriteFlush,
  AmbientProcessingSequence.verifyAcknowledge,
  AmbientProcessingSequence.routeBranch,
  AmbientProcessingSequence.highLoadBurst,
];

class _AmbientProcessingPainter extends CustomPainter {
  const _AmbientProcessingPainter({
    required this.animation,
    required this.color,
    required this.staticFrame,
    required this.sequence,
    required this.idle,
    required this.layer,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final bool staticFrame;
  final AmbientProcessingSequence sequence;
  final bool idle;
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

  AmbientProcessingFrame get _frame => staticFrame || idle
      ? const AmbientProcessingFrame(
          sequence: AmbientProcessingSequence.idle,
          progress: 0,
          isIdle: true,
        )
      : AmbientProcessingFrame(
          sequence: sequence,
          progress: animation.value,
          isIdle: false,
        );

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

  Path _routePath(Size size, int routeIndex) {
    final route = _routes[routeIndex];
    final from = _point(size, _nodes[route.$1]);
    final to = _point(size, _nodes[route.$2]);
    final bend = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2 - 10);
    return Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(bend.dx, bend.dy, to.dx, to.dy);
  }

  void _paintDataBus(Canvas canvas, Size size) {
    final routePaint = Paint()
      ..color = color.withValues(alpha: .075)
      ..strokeWidth = 1;
    for (var index = 0; index < _routes.length; index++) {
      canvas.drawPath(_routePath(size, index), routePaint);
    }
    if (_frame.isIdle) return;
    for (final packet in _packetsFor(_frame)) {
      _paintPacket(canvas, _routePath(size, packet.route), packet);
    }
  }

  void _paintPacket(Canvas canvas, Path path, _Packet packet) {
    final metrics = path.computeMetrics().first;
    final travel = packet.reverse ? 1 - packet.progress : packet.progress;
    final tangent = metrics.getTangentForOffset(metrics.length * travel);
    if (tangent == null) return;
    canvas.drawCircle(
      tangent.position,
      1.5 + packet.emphasis * 1.6,
      Paint()..color = color.withValues(alpha: .15 + packet.emphasis * .25),
    );
  }

  void _paintNodes(Canvas canvas, Size size) {
    final strengths = _nodeStrengthsFor(_frame);
    for (var index = 0; index < _nodes.length; index++) {
      final point = _point(size, _nodes[index]);
      final strength = strengths[index];
      canvas.drawCircle(
        point,
        8 + strength * 4,
        Paint()..color = color.withValues(alpha: .025 + strength * .075),
      );
      canvas.drawCircle(
        point,
        3.5 + strength * 1.5,
        Paint()
          ..color = color.withValues(alpha: .16 + strength * .32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      if (strength > .08) {
        canvas.drawCircle(
          point,
          1.2 + strength,
          Paint()..color = color.withValues(alpha: .24 + strength * .4),
        );
      }
    }
  }

  void _paintMemory(Canvas canvas, Size size) {
    final width = math.min(96.0, size.width * .2);
    const height = 10.0;
    final origins = [
      Offset(size.width * .08, size.height * .79),
      Offset(size.width * .62, size.height * .80),
      Offset(size.width * .38, size.height * .42),
    ];
    final fills = _memoryFillsFor(_frame);
    for (var bank = 0; bank < origins.length; bank++) {
      for (var cell = 0; cell < 5; cell++) {
        final rect = Rect.fromLTWH(
          origins[bank].dx + cell * (width / 5 + 3),
          origins[bank].dy,
          width / 5,
          height,
        );
        final fill = (fills[bank] - cell).clamp(0.0, 1.0);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
          Paint()..color = color.withValues(alpha: .07 + fill * .18),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
          Paint()
            ..color = color.withValues(alpha: .1 + fill * .18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .7,
        );
      }
    }
  }

  List<_Packet> _packetsFor(AmbientProcessingFrame frame) {
    final p = frame.progress;
    return switch (frame.sequence) {
      AmbientProcessingSequence.ingestRoute => [
        if (p < .38) _Packet(0, p / .38),
        if (p >= .2 && p < .55) _Packet(1, (p - .2) / .35),
        if (p >= .72) _Packet(7, (p - .72) / .28),
      ],
      AmbientProcessingSequence.parallelProcessing => [
        if (p < .58) _Packet(3, p / .58),
        if (p > .12 && p < .7) _Packet(2, (p - .12) / .58),
        if (p > .35) _Packet(5, (p - .35) / .65),
        if (p > .48) _Packet(8, (p - .48) / .52),
      ],
      AmbientProcessingSequence.bufferWriteFlush => [
        if (p > .68) _Packet(4, (p - .68) / .32),
        if (p > .78) _Packet(5, (p - .78) / .22, emphasis: 1),
      ],
      AmbientProcessingSequence.verifyAcknowledge => [
        if (p < .42) _Packet(7, p / .42),
        if (p > .56) _Packet(7, (p - .56) / .44, reverse: true),
      ],
      AmbientProcessingSequence.routeBranch => [
        if (p < .36) _Packet(1, p / .36),
        if (p > .36) _Packet(2, (p - .36) / .64),
        if (p > .46) _Packet(7, (p - .46) / .54),
      ],
      AmbientProcessingSequence.highLoadBurst => [
        _Packet(0, p),
        _Packet(3, (p + .18) % 1),
        _Packet(5, (p + .36) % 1),
        _Packet(8, (p + .55) % 1),
      ],
      AmbientProcessingSequence.idle => const [],
    };
  }

  List<double> _nodeStrengthsFor(AmbientProcessingFrame frame) {
    final values = List<double>.filled(_nodes.length, 0);
    for (final packet in _packetsFor(frame)) {
      final route = _routes[packet.route];
      values[route.$1] = math.max(
        values[route.$1],
        .35 + packet.emphasis * .25,
      );
      if (packet.progress > .72) values[route.$2] = 1;
    }
    if (frame.sequence == AmbientProcessingSequence.verifyAcknowledge &&
        frame.progress > .42 &&
        frame.progress < .7) {
      values[5] = 1;
      values[2] = .72;
    }
    return values;
  }

  List<double> _memoryFillsFor(AmbientProcessingFrame frame) {
    final p = frame.progress;
    return switch (frame.sequence) {
      AmbientProcessingSequence.ingestRoute => [0, 0, p < .56 ? 0 : 3],
      AmbientProcessingSequence.parallelProcessing => [
        (p * 5).clamp(0.0, 4.0),
        ((p - .22) * 6).clamp(0.0, 4.0),
        0,
      ],
      AmbientProcessingSequence.bufferWriteFlush => [
        p < .68 ? (p / .68 * 5).clamp(0.0, 5.0) : ((1 - p) / .32 * 5),
        0,
        0,
      ],
      AmbientProcessingSequence.verifyAcknowledge => [0, 0, p < .7 ? 2 : 4],
      AmbientProcessingSequence.routeBranch => [
        p > .48 ? 3 : 0,
        p > .66 ? 2 : 0,
        0,
      ],
      AmbientProcessingSequence.highLoadBurst => [
        (p * 5).clamp(0.0, 5.0),
        ((p - .16) * 6).clamp(0.0, 5.0),
        ((p - .32) * 7).clamp(0.0, 5.0),
      ],
      AmbientProcessingSequence.idle => const [0, 0, 0],
    };
  }

  @override
  bool shouldRepaint(covariant _AmbientProcessingPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.staticFrame != staticFrame ||
      oldDelegate.sequence != sequence ||
      oldDelegate.idle != idle ||
      oldDelegate.layer != layer;
}

class _Packet {
  const _Packet(
    this.route,
    this.progress, {
    this.reverse = false,
    this.emphasis = 0,
  });

  final int route;
  final double progress;
  final bool reverse;
  final double emphasis;
}
