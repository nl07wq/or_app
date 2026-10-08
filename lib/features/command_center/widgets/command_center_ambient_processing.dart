import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The Command Center's independent, low-intensity processing field.
///
/// One timeline drives all layers: base traffic is always present while the
/// screen is active, while a primary and a delayed secondary sequence create
/// bounded overlapping processing events. It intentionally shares nothing
/// with the Dashboard Ambient Circuit traffic model.
class CommandCenterAmbientProcessing extends StatefulWidget {
  const CommandCenterAmbientProcessing({super.key, required this.enabled});

  static const rootKey = ValueKey('command-center-ambient-processing');
  static const nodesKey = ValueKey('command-center-processing-nodes');
  static const dataBusKey = ValueKey('command-center-data-bus');
  static const memoryBlocksKey = ValueKey('command-center-memory-blocks');

  static const nodeCount = 14;
  static const dataBusCount = 21;
  static const memoryBankCount = 5;
  static const memoryCellsPerBank = 6;
  static const geometryFamilies = <AmbientBusGeometry>{
    AmbientBusGeometry.straight,
    AmbientBusGeometry.diagonal,
    AmbientBusGeometry.stepped,
    AmbientBusGeometry.curvedBypass,
    AmbientBusGeometry.parallelLane,
    AmbientBusGeometry.local,
    AmbientBusGeometry.transport,
  };

  final bool enabled;

  /// Linear progress deliberately has no easing: every packet's speed is
  /// constant from its departure until its arrival, including at route bends.
  static double constantSpeedProgress({
    required double elapsed,
    required double travelDuration,
  }) => (elapsed / travelDuration).clamp(0.0, 1.0);

  /// Nominal route durations define the four simulated data characteristics.
  /// Individual packets retain their selected duration for their whole trip.
  static const packetTravelDurations = <AmbientPacketModel, double>{
    AmbientPacketModel.light: .18,
    AmbientPacketModel.standard: .28,
    AmbientPacketModel.heavy: .42,
    AmbientPacketModel.priority: .11,
  };

  @override
  State<CommandCenterAmbientProcessing> createState() =>
      _CommandCenterAmbientProcessingState();
}

enum AmbientProcessingSequence {
  ingestRoute,
  parallelProcessing,
  bufferWriteFlush,
  verifyAcknowledge,
  routeBranch,
  highLoadBurst,
}

enum AmbientPacketModel { light, standard, heavy, priority }

enum AmbientBusGeometry {
  straight,
  diagonal,
  stepped,
  curvedBypass,
  parallelLane,
  local,
  transport,
}

const _sequenceLibrary = <AmbientProcessingSequence>[
  AmbientProcessingSequence.ingestRoute,
  AmbientProcessingSequence.parallelProcessing,
  AmbientProcessingSequence.bufferWriteFlush,
  AmbientProcessingSequence.verifyAcknowledge,
  AmbientProcessingSequence.routeBranch,
  AmbientProcessingSequence.highLoadBurst,
];

class _CommandCenterAmbientProcessingState
    extends State<CommandCenterAmbientProcessing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  Timer? _nextCycle;
  var _motionAllowed = false;
  var _sequenceIndex = 0;
  var _running = false;

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
    _running = false;
    if (widget.enabled && _motionAllowed) {
      // Let navigation settle first. Afterwards each short event hands off to
      // the next one almost immediately, so base traffic never visually stops.
      _nextCycle = Timer(const Duration(milliseconds: 900), _startCycle);
    } else {
      _controller.value = 0;
    }
  }

  void _startCycle() {
    if (!mounted || !widget.enabled || !_motionAllowed) return;
    setState(() => _running = true);
    _controller.forward(from: 0).whenComplete(() {
      if (!mounted || !widget.enabled || !_motionAllowed) return;
      setState(() {
        _running = false;
        _sequenceIndex = (_sequenceIndex + 1) % _sequenceLibrary.length;
      });
      _nextCycle = Timer(const Duration(milliseconds: 80), _startCycle);
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
                running: _running,
                primary: _sequenceLibrary[_sequenceIndex],
                secondary:
                    _sequenceLibrary[(_sequenceIndex + 2) %
                        _sequenceLibrary.length],
                layer: _AmbientLayer.dataBus,
              ),
            ),
            CustomPaint(
              key: CommandCenterAmbientProcessing.nodesKey,
              painter: _AmbientProcessingPainter(
                animation: _controller,
                color: color,
                staticFrame: !_motionAllowed,
                running: _running,
                primary: _sequenceLibrary[_sequenceIndex],
                secondary:
                    _sequenceLibrary[(_sequenceIndex + 2) %
                        _sequenceLibrary.length],
                layer: _AmbientLayer.nodes,
              ),
            ),
            CustomPaint(
              key: CommandCenterAmbientProcessing.memoryBlocksKey,
              painter: _AmbientProcessingPainter(
                animation: _controller,
                color: color,
                staticFrame: !_motionAllowed,
                running: _running,
                primary: _sequenceLibrary[_sequenceIndex],
                secondary:
                    _sequenceLibrary[(_sequenceIndex + 2) %
                        _sequenceLibrary.length],
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
    required this.running,
    required this.primary,
    required this.secondary,
    required this.layer,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final bool staticFrame;
  final bool running;
  final AmbientProcessingSequence primary;
  final AmbientProcessingSequence secondary;
  final _AmbientLayer layer;

  static const _nodes = <Offset>[
    Offset(.08, .16),
    Offset(.24, .14),
    Offset(.42, .20),
    Offset(.62, .12),
    Offset(.82, .20),
    Offset(.13, .42),
    Offset(.31, .38),
    Offset(.51, .46),
    Offset(.70, .37),
    Offset(.90, .48),
    Offset(.19, .74),
    Offset(.43, .72),
    Offset(.65, .69),
    Offset(.86, .79),
  ];

  static const _routes = <_RouteSpec>[
    _RouteSpec(0, 1, AmbientBusGeometry.straight),
    _RouteSpec(1, 2, AmbientBusGeometry.diagonal),
    _RouteSpec(
      2,
      3,
      AmbientBusGeometry.stepped,
      waypoints: [Offset(.52, .20), Offset(.52, .12)],
    ),
    _RouteSpec(
      3,
      4,
      AmbientBusGeometry.parallelLane,
      waypoints: [Offset(.72, .12)],
    ),
    _RouteSpec(0, 5, AmbientBusGeometry.transport),
    _RouteSpec(5, 6, AmbientBusGeometry.local),
    _RouteSpec(
      6,
      7,
      AmbientBusGeometry.curvedBypass,
      waypoints: [Offset(.40, .31)],
    ),
    _RouteSpec(7, 8, AmbientBusGeometry.local),
    _RouteSpec(8, 9, AmbientBusGeometry.diagonal),
    _RouteSpec(
      5,
      10,
      AmbientBusGeometry.curvedBypass,
      waypoints: [Offset(.08, .60)],
    ),
    _RouteSpec(
      10,
      11,
      AmbientBusGeometry.parallelLane,
      waypoints: [Offset(.31, .77)],
    ),
    _RouteSpec(11, 12, AmbientBusGeometry.straight),
    _RouteSpec(12, 13, AmbientBusGeometry.diagonal),
    _RouteSpec(2, 7, AmbientBusGeometry.transport),
    _RouteSpec(
      6,
      11,
      AmbientBusGeometry.stepped,
      waypoints: [Offset(.31, .58), Offset(.43, .58)],
    ),
    _RouteSpec(7, 12, AmbientBusGeometry.transport),
    _RouteSpec(
      8,
      12,
      AmbientBusGeometry.stepped,
      waypoints: [Offset(.70, .56), Offset(.65, .56)],
    ),
    _RouteSpec(3, 8, AmbientBusGeometry.local),
    _RouteSpec(4, 9, AmbientBusGeometry.transport),
    _RouteSpec(
      9,
      13,
      AmbientBusGeometry.curvedBypass,
      waypoints: [Offset(.96, .64)],
    ),
    _RouteSpec(1, 6, AmbientBusGeometry.transport),
  ];

  double get _progress => staticFrame || !running ? 0 : animation.value;

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
    final points = <Offset>[_point(size, _nodes[route.from])];
    points.addAll(route.waypoints.map((point) => _point(size, point)));
    points.add(_point(size, _nodes[route.to]));
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (route.geometry == AmbientBusGeometry.curvedBypass &&
        points.length == 3) {
      path.quadraticBezierTo(
        points[1].dx,
        points[1].dy,
        points[2].dx,
        points[2].dy,
      );
    } else {
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path;
  }

  void _paintDataBus(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..color = color.withValues(alpha: .075)
      ..strokeWidth = 1;
    for (var index = 0; index < _routes.length; index++) {
      canvas.drawPath(_routePath(size, index), basePaint);
    }
    for (final packet in _packets) {
      final local = _packetProgress(packet);
      if (local == null) continue;
      _paintPacket(canvas, _routePath(size, packet.route), packet, local);
    }
  }

  void _paintPacket(
    Canvas canvas,
    Path path,
    _PacketPlan packet,
    double progress,
  ) {
    final metric = path.computeMetrics().first;
    final travel = packet.reverse ? 1 - progress : progress;
    final tangent = metric.getTangentForOffset(metric.length * travel);
    if (tangent == null) return;
    final (radius, alpha) = switch (packet.model) {
      AmbientPacketModel.light => (1.3, .20),
      AmbientPacketModel.standard => (1.8, .25),
      AmbientPacketModel.heavy => (2.5, .29),
      AmbientPacketModel.priority => (1.45, .31),
    };
    canvas.drawCircle(
      tangent.position,
      radius,
      Paint()..color = color.withValues(alpha: alpha),
    );
  }

  void _paintNodes(Canvas canvas, Size size) {
    final activations = _nodeActivations;
    for (var index = 0; index < _nodes.length; index++) {
      final point = _point(size, _nodes[index]);
      final activation = activations[index];
      canvas.drawCircle(
        point,
        8 + activation * 4,
        Paint()..color = color.withValues(alpha: .025 + activation * .075),
      );
      canvas.drawCircle(
        point,
        3.5 + activation * 1.5,
        Paint()
          ..color = color.withValues(alpha: .16 + activation * .32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      if (activation > .01) {
        canvas.drawCircle(
          point,
          1.2 + activation,
          Paint()..color = color.withValues(alpha: .24 + activation * .4),
        );
      }
    }
  }

  void _paintMemory(Canvas canvas, Size size) {
    final width = math.min(90.0, size.width * .16);
    const height = 9.0;
    final origins = [
      Offset(size.width * .06, size.height * .84),
      Offset(size.width * .27, size.height * .57),
      Offset(size.width * .46, size.height * .84),
      Offset(size.width * .66, size.height * .60),
      Offset(size.width * .80, size.height * .86),
    ];
    final fills = _memoryFills;
    for (var bank = 0; bank < origins.length; bank++) {
      for (
        var cell = 0;
        cell < CommandCenterAmbientProcessing.memoryCellsPerBank;
        cell++
      ) {
        final rect = Rect.fromLTWH(
          origins[bank].dx +
              cell *
                  (width / CommandCenterAmbientProcessing.memoryCellsPerBank +
                      2),
          origins[bank].dy,
          width / CommandCenterAmbientProcessing.memoryCellsPerBank,
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

  List<_PacketPlan> get _packets => [
    ..._basePackets,
    ..._sequencePackets(primary),
    if (_progress > .24) ..._sequencePackets(secondary, secondary: true),
  ];

  // Base traffic is deliberately sparse and distributed across three regions.
  // It continues underneath every processing event.
  List<_PacketPlan> get _basePackets => const [
    _PacketPlan(0, .00, .22, AmbientPacketModel.light),
    _PacketPlan(8, .31, .28, AmbientPacketModel.standard),
    _PacketPlan(10, .58, .30, AmbientPacketModel.light),
    _PacketPlan(18, .14, .42, AmbientPacketModel.heavy),
    _PacketPlan(20, .82, .18, AmbientPacketModel.priority),
  ];

  List<_PacketPlan> _sequencePackets(
    AmbientProcessingSequence sequence, {
    bool secondary = false,
  }) {
    // The sequence's start is moved into the local event timeline. Every
    // packet has a fixed duration selected at creation, never an eased speed.
    final offset = secondary ? .24 : 0.0;
    return switch (sequence) {
      AmbientProcessingSequence.ingestRoute => [
        _PacketPlan(4, offset, .22, AmbientPacketModel.light),
        _PacketPlan(5, offset + .20, .24, AmbientPacketModel.standard),
        _PacketPlan(13, offset + .48, .34, AmbientPacketModel.heavy),
      ],
      AmbientProcessingSequence.parallelProcessing => [
        _PacketPlan(2, offset, .30, AmbientPacketModel.standard),
        _PacketPlan(9, offset + .08, .40, AmbientPacketModel.heavy),
        _PacketPlan(15, offset + .42, .26, AmbientPacketModel.light),
        _PacketPlan(12, offset + .50, .20, AmbientPacketModel.priority),
      ],
      AmbientProcessingSequence.bufferWriteFlush => [
        _PacketPlan(14, offset + .12, .32, AmbientPacketModel.heavy),
        _PacketPlan(10, offset + .54, .16, AmbientPacketModel.priority),
        _PacketPlan(11, offset + .70, .18, AmbientPacketModel.priority),
      ],
      AmbientProcessingSequence.verifyAcknowledge => [
        _PacketPlan(6, offset + .08, .28, AmbientPacketModel.standard),
        _PacketPlan(
          6,
          offset + .48,
          .18,
          AmbientPacketModel.priority,
          reverse: true,
        ),
      ],
      AmbientProcessingSequence.routeBranch => [
        _PacketPlan(1, offset, .22, AmbientPacketModel.light),
        _PacketPlan(2, offset + .22, .30, AmbientPacketModel.standard),
        _PacketPlan(13, offset + .28, .30, AmbientPacketModel.standard),
        _PacketPlan(7, offset + .52, .20, AmbientPacketModel.priority),
      ],
      AmbientProcessingSequence.highLoadBurst => [
        _PacketPlan(3, offset, .13, AmbientPacketModel.priority),
        _PacketPlan(7, offset + .10, .18, AmbientPacketModel.light),
        _PacketPlan(17, offset + .20, .25, AmbientPacketModel.standard),
        _PacketPlan(19, offset + .28, .34, AmbientPacketModel.heavy),
        _PacketPlan(16, offset + .44, .16, AmbientPacketModel.priority),
      ],
    };
  }

  double? _packetProgress(_PacketPlan packet) {
    final elapsed = _progress - packet.start;
    if (elapsed < 0 || elapsed > packet.duration) return null;
    return CommandCenterAmbientProcessing.constantSpeedProgress(
      elapsed: elapsed,
      travelDuration: packet.duration,
    );
  }

  List<double> get _nodeActivations {
    final values = List<double>.filled(
      CommandCenterAmbientProcessing.nodeCount,
      0,
    );
    for (final packet in _packets) {
      final local = _packetProgress(packet);
      if (local != null) continue;
      final arrival = packet.start + packet.duration;
      final elapsedSinceArrival = _progress - arrival;
      // The target illuminates only after route completion, then decays. No
      // proximity activation is used for either source or destination nodes.
      if (elapsedSinceArrival < 0 || elapsedSinceArrival > .12) continue;
      final target = packet.reverse
          ? _routes[packet.route].from
          : _routes[packet.route].to;
      values[target] = math.max(values[target], 1 - elapsedSinceArrival / .12);
    }
    return values;
  }

  List<double> get _memoryFills {
    final fills = List<double>.filled(
      CommandCenterAmbientProcessing.memoryBankCount,
      0,
    );
    for (final packet in _packets) {
      final local = _packetProgress(packet);
      if (local != null) continue;
      final arrival = packet.start + packet.duration;
      final elapsed = _progress - arrival;
      if (elapsed < 0 || elapsed > .34) continue;
      final bank = _bankForRoute(packet.route);
      final amount = packet.model == AmbientPacketModel.heavy
          ? 3.5
          : packet.model == AmbientPacketModel.priority
          ? 1.5
          : 1.0;
      // WRITE -> HOLD -> TRANSFER -> CLEAR is causal: no bank changes before
      // a packet has completed the matching route.
      final fill = switch (elapsed) {
        < .08 => amount * (elapsed / .08),
        < .20 => amount,
        < .28 => amount * (1 - (elapsed - .20) / .08),
        _ => 0.0,
      };
      fills[bank] = math.max(fills[bank], fill);
    }
    return fills;
  }

  int _bankForRoute(int route) => switch (route) {
    4 || 5 || 9 => 0,
    1 || 2 || 13 || 14 => 1,
    6 || 7 || 15 => 2,
    3 || 8 || 17 || 18 => 3,
    _ => 4,
  };

  @override
  bool shouldRepaint(covariant _AmbientProcessingPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.staticFrame != staticFrame ||
      oldDelegate.running != running ||
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary ||
      oldDelegate.layer != layer;
}

class _RouteSpec {
  const _RouteSpec(
    this.from,
    this.to,
    this.geometry, {
    this.waypoints = const [],
  });

  final int from;
  final int to;
  final AmbientBusGeometry geometry;
  final List<Offset> waypoints;
}

class _PacketPlan {
  const _PacketPlan(
    this.route,
    this.start,
    this.duration,
    this.model, {
    this.reverse = false,
  });

  final int route;
  final double start;
  final double duration;
  final AmbientPacketModel model;
  final bool reverse;
}
