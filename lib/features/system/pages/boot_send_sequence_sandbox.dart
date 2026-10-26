import 'dart:math' as math;

import 'package:flutter/material.dart';

/// These prototypes are deliberately sandbox-only: they do not own data,
/// storage, sound, or transport behavior.
enum BootSendSequenceConcept {
  assemblyMatrix,
  voxelIntegration,
  polyhedralFold,
}

enum BootSendSequencePhase { initializing, buildingData, integrating, complete }

enum _OperationMode { brief, debrief, backup }

const _cycle = Duration(milliseconds: 6000);
const _completionTimeline = Duration(hours: 1);
const _completionTimelineSeconds = 3600.0;

class BootSendSequenceSandbox extends StatefulWidget {
  const BootSendSequenceSandbox({super.key});

  @override
  State<BootSendSequenceSandbox> createState() =>
      _BootSendSequenceSandboxState();
}

class _BootSendSequenceSandboxState extends State<BootSendSequenceSandbox>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _completionController;
  var _concept = BootSendSequenceConcept.assemblyMatrix;
  var _mode = _OperationMode.brief;

  @override
  void initState() {
    super.initState();
    _completionController = AnimationController(
      vsync: this,
      duration: _completionTimeline,
    );
    _controller = AnimationController(vsync: this, duration: _cycle)
      ..addListener(_startCompletionTimelineAtConstructionEnd)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          _startCompletionTimelineAtConstructionEnd();
        }
      })
      ..forward();
  }

  void _startCompletionTimelineAtConstructionEnd() {
    if (mounted &&
        _controller.value >= .999 &&
        !_completionController.isAnimating) {
      _completionController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _completionController.dispose();
    super.dispose();
  }

  void _replay() {
    _completionController
      ..stop()
      ..value = 0;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (reducedMotion && _controller.isAnimating) _controller.stop();
    return Column(
      key: const ValueKey('boot-send-sequence-sandbox'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'BOOT / SEND SEQUENCE',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SegmentedButton<BootSendSequenceConcept>(
          key: const ValueKey('boot-send-sequence-selector'),
          segments: const [
            ButtonSegment(
              value: BootSendSequenceConcept.assemblyMatrix,
              label: FittedBox(child: Text('ASSEMBLY MATRIX')),
            ),
            ButtonSegment(
              value: BootSendSequenceConcept.voxelIntegration,
              label: FittedBox(child: Text('VOXEL INTEGRATION')),
            ),
            ButtonSegment(
              value: BootSendSequenceConcept.polyhedralFold,
              label: FittedBox(child: Text('POLYHEDRAL FOLD')),
            ),
          ],
          selected: {_concept},
          onSelectionChanged: (value) {
            setState(() => _concept = value.first);
            _replay();
          },
        ),
        const SizedBox(height: 8),
        SegmentedButton<_OperationMode>(
          key: const ValueKey('boot-send-sequence-mode-selector'),
          segments: const [
            ButtonSegment(value: _OperationMode.brief, label: Text('BRIEF')),
            ButtonSegment(
              value: _OperationMode.debrief,
              label: Text('DEBRIEF'),
            ),
            ButtonSegment(value: _OperationMode.backup, label: Text('BACKUP')),
          ],
          selected: {_mode},
          onSelectionChanged: (value) => setState(() => _mode = value.first),
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: Listenable.merge([_controller, _completionController]),
          builder: (_, _) => _SendSequenceMonitor(
            concept: _concept,
            mode: _mode,
            progress: reducedMotion ? 1 : _controller.value,
            completionElapsedSeconds: reducedMotion
                ? 0
                : _completionController.value * _completionTimelineSeconds,
            reducedMotion: reducedMotion,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text(_caption(_concept))),
            TextButton.icon(
              key: const ValueKey('boot-send-sequence-replay'),
              onPressed: _replay,
              icon: const Icon(Icons.replay_outlined, size: 18),
              label: const Text('REPLAY'),
            ),
          ],
        ),
      ],
    );
  }
}

String _caption(BootSendSequenceConcept concept) => switch (concept) {
  BootSendSequenceConcept.assemblyMatrix => 'ASSEMBLY MATRIX',
  BootSendSequenceConcept.voxelIntegration => 'VOXEL INTEGRATION',
  BootSendSequenceConcept.polyhedralFold => 'POLYHEDRAL FOLD',
};

String _modeTitle(_OperationMode mode) => switch (mode) {
  _OperationMode.brief => 'BRIEF SEQUENCE',
  _OperationMode.debrief => 'DEBRIEF SEQUENCE',
  _OperationMode.backup => 'BACKUP SEQUENCE',
};

BootSendSequencePhase bootSendSequencePhase(double progress) {
  final value = progress.clamp(0, 1).toDouble();
  if (value < .2) return BootSendSequencePhase.initializing;
  if (value < 7 / 15) return BootSendSequencePhase.buildingData;
  if (value < 23 / 30) return BootSendSequencePhase.integrating;
  return BootSendSequencePhase.complete;
}

String bootSendSequencePhaseLabel(BootSendSequencePhase phase) =>
    switch (phase) {
      BootSendSequencePhase.initializing => 'INITIALIZING',
      BootSendSequencePhase.buildingData => 'BUILDING DATA',
      BootSendSequencePhase.integrating => 'INTEGRATING',
      BootSendSequencePhase.complete => 'COMPLETE',
    };

double _phase(double value, double start, double end) =>
    ((value - start) / (end - start)).clamp(0, 1).toDouble();
bool _isConstructionComplete(double progress) => progress >= .999;
double _ease(double value) =>
    Curves.easeInOutCubic.transform(value.clamp(0, 1));

class _SendSequenceMonitor extends StatelessWidget {
  const _SendSequenceMonitor({
    required this.concept,
    required this.mode,
    required this.progress,
    required this.completionElapsedSeconds,
    required this.reducedMotion,
  });

  final BootSendSequenceConcept concept;
  final _OperationMode mode;
  final double progress;
  final double completionElapsedSeconds;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 360 / 280,
    child: RepaintBoundary(
      child: CustomPaint(
        key: const ValueKey('boot-send-sequence-monitor'),
        painter: _SendSequencePainter(
          concept: concept,
          mode: mode,
          progress: progress,
          completionElapsedSeconds: completionElapsedSeconds,
          reducedMotion: reducedMotion,
        ),
      ),
    ),
  );
}

class _SendSequencePainter extends CustomPainter {
  const _SendSequencePainter({
    required this.concept,
    required this.mode,
    required this.progress,
    required this.completionElapsedSeconds,
    required this.reducedMotion,
  });

  final BootSendSequenceConcept concept;
  final _OperationMode mode;
  final double progress;
  final double completionElapsedSeconds;
  final bool reducedMotion;

  static const _screen = Color(0xff030d15);
  static const _cyan = Color(0xff39ddf2);
  static const _ice = Color(0xffd8fbff);
  static const _violet = Color(0xff9588d9);

  Paint _fill(Color color) => Paint()..color = color;
  Paint _line(Color color, [double width = 1]) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width;
  Paint _glow(Color color, double sigma, [double width = 1]) =>
      _line(color, width)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 360, size.height / 280);
    canvas.save();
    canvas.translate(
      (size.width - 360 * scale) / 2,
      (size.height - 280 * scale) / 2,
    );
    canvas.scale(scale);
    final t = progress.clamp(0, 1).toDouble();
    _housing(canvas);
    _grid(canvas);
    _header(canvas, t);
    final particleField = _isConstructionComplete(t)
        ? _completedParticleField(completionElapsedSeconds)
        : null;
    if (particleField != null) {
      _paintParticles(canvas, particleField, reducedMotion: reducedMotion);
    }
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(20, 72, 320, 137));
    switch (concept) {
      case BootSendSequenceConcept.assemblyMatrix:
        _assemblyMatrix(canvas, t, completionElapsedSeconds);
      case BootSendSequenceConcept.voxelIntegration:
        _voxelIntegration(canvas, t, completionElapsedSeconds);
      case BootSendSequenceConcept.polyhedralFold:
        _polyhedralFold(canvas, t, completionElapsedSeconds);
    }
    canvas.restore();
    if (particleField != null) {
      _paintParticles(
        canvas,
        particleField,
        frontOnly: true,
        reducedMotion: reducedMotion,
      );
    }
    _footer(canvas, t);
    _bezel(canvas);
    canvas.restore();
  }

  void _housing(Canvas canvas) {
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4, 4, 352, 272),
      const Radius.circular(13),
    );
    canvas.drawRRect(body, _fill(const Color(0xff101c25)));
    canvas.drawRRect(body, _line(const Color(0xff45697a), 2));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, 10, 340, 260),
        const Radius.circular(9),
      ),
      _fill(const Color(0xff061018)),
    );
    canvas.drawRect(const Rect.fromLTWH(19, 21, 322, 238), _fill(_screen));
    canvas.drawRect(
      const Rect.fromLTWH(19, 21, 322, 238),
      _line(const Color(0xff31788a)),
    );
    for (final x in [31.0, 303.0]) {
      for (var row = 0; row < 2; row++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 14 + row * 4, 26, 3),
            const Radius.circular(1),
          ),
          _fill(row == 0 ? const Color(0xff294957) : const Color(0xff172f3b)),
        );
      }
    }
    for (final point in const [
      Offset(13, 13),
      Offset(347, 13),
      Offset(13, 267),
      Offset(347, 267),
    ]) {
      canvas.drawCircle(point, 2, _fill(const Color(0xff5a7a87)));
      canvas.drawCircle(point, .75, _fill(const Color(0xff0b151c)));
    }
    for (final point in const [
      Offset(20, 22),
      Offset(340, 22),
      Offset(20, 258),
      Offset(340, 258),
    ]) {
      final sx = point.dx < 180 ? 1.0 : -1.0;
      final sy = point.dy < 140 ? 1.0 : -1.0;
      final paint = _line(const Color(0xff64bfcf), 1.4);
      canvas.drawLine(point, point + Offset(12 * sx, 0), paint);
      canvas.drawLine(point, point + Offset(0, 12 * sy), paint);
    }
  }

  void _grid(Canvas canvas) {
    final paint = _line(const Color(0xff6ba4b5).withValues(alpha: .045), .6);
    for (var x = 20.0; x < 341; x += 24) {
      canvas.drawLine(Offset(x, 22), Offset(x, 258), paint);
    }
    for (var y = 22.0; y < 259; y += 24) {
      canvas.drawLine(Offset(20, y), Offset(340, y), paint);
    }
  }

  void _header(Canvas canvas, double t) {
    _text(
      canvas,
      'SYSTEM / 01',
      const Offset(30, 35),
      9,
      const Color(0xff7ba9b8),
    );
    _center(canvas, _modeTitle(mode), const Offset(180, 39), 10, _ice);
    _text(canvas, 'SANDBOX', const Offset(279, 35), 8, const Color(0xff6f9bac));
    final color = t >= 23 / 30
        ? const Color(0xff8af6e9)
        : const Color(0xff2d8fa7);
    canvas.drawCircle(
      const Offset(327, 39),
      5,
      _glow(color.withValues(alpha: .35), 7, 5),
    );
    canvas.drawCircle(
      const Offset(327, 39),
      5,
      _glow(color.withValues(alpha: .75), 3, 3),
    );
    canvas.drawCircle(const Offset(327, 39), 3, _fill(color));
    canvas.drawLine(
      const Offset(30, 65),
      const Offset(330, 65),
      _line(const Color(0xff386277), .7),
    );
  }

  void _footer(Canvas canvas, double t) {
    final phase = bootSendSequencePhase(t);
    final state = phase == BootSendSequencePhase.complete
        ? switch (concept) {
            BootSendSequenceConcept.assemblyMatrix => 'MATRIX ONLINE',
            BootSendSequenceConcept.voxelIntegration => 'CORE INTEGRATED',
            BootSendSequenceConcept.polyhedralFold => 'CUBE SEALED',
          }
        : bootSendSequencePhaseLabel(phase);
    _text(
      canvas,
      _caption(concept),
      const Offset(30, 219),
      8,
      const Color(0xff71a7b8),
    );
    _text(
      canvas,
      '${(t * 100).round().clamp(0, 100)}%',
      const Offset(30, 231),
      9,
      const Color(0xffa1dbe6),
    );
    _right(
      canvas,
      state,
      const Offset(330, 230),
      8.5,
      phase == BootSendSequencePhase.complete
          ? const Color(0xffc6fff7)
          : const Color(0xff6694a5),
    );
    final active = (t * 20).floor().clamp(0, 20);
    for (var index = 0; index < 20; index++) {
      final color = phase == BootSendSequencePhase.complete
          ? const Color(0xff8af6e9)
          : index < active
          ? const Color(0xff42daf2)
          : const Color(0xff193443);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(30 + index * 14, 242, 10, 5),
          const Radius.circular(1),
        ),
        _fill(color),
      );
    }
  }

  void _bezel(Canvas canvas) {
    canvas.drawLine(
      const Offset(13, 29),
      const Offset(13, 245),
      _line(const Color(0xff7bc6d5).withValues(alpha: .17), .7),
    );
    canvas.drawLine(
      const Offset(347, 29),
      const Offset(347, 245),
      _line(const Color(0xff02080c)),
    );
  }

  SandboxParticleField _completedParticleField(double elapsedSeconds) {
    final bounds = switch (concept) {
      BootSendSequenceConcept.assemblyMatrix => _completedMatrixBounds(
        elapsedSeconds,
      ),
      BootSendSequenceConcept.voxelIntegration => _completedVoxelBounds(
        elapsedSeconds,
      ),
      BootSendSequenceConcept.polyhedralFold => _completedCubeBounds(
        elapsedSeconds,
      ),
    };
    final contentBounds = const Rect.fromLTWH(25, 72, 310, 137);
    final expanded = Rect.fromLTRB(
      math.max(contentBounds.left, bounds.left - 18),
      math.max(contentBounds.top, bounds.top - 13),
      math.min(contentBounds.right, bounds.right + 18),
      math.min(contentBounds.bottom, bounds.bottom + 13),
    );
    return SandboxParticleField(
      center: expanded.center,
      spawnBounds: expanded,
      palette: const [
        Color(0xff63d8ff),
        Color(0xffb5f3ff),
        Color(0xffa69aff),
        Color(0xffe8fcff),
      ],
      density: sandboxParticleCount(concept),
      motionBias: switch (concept) {
        BootSendSequenceConcept.assemblyMatrix =>
          const SandboxParticleMotionBias(6, 9, 4, 6),
        BootSendSequenceConcept.voxelIntegration =>
          const SandboxParticleMotionBias(8, 14, 6, 10),
        BootSendSequenceConcept.polyhedralFold =>
          const SandboxParticleMotionBias(7, 12, 5, 8),
      },
      seed: switch (concept) {
        BootSendSequenceConcept.assemblyMatrix => 3101,
        BootSendSequenceConcept.voxelIntegration => 3102,
        BootSendSequenceConcept.polyhedralFold => 3103,
      },
      elapsedTime: elapsedSeconds,
      depthLayer: SandboxParticleDepthLayer.back,
    );
  }

  Rect _completedMatrixBounds(double elapsedSeconds) {
    final hover = math.sin(elapsedSeconds * math.pi * 2 / 3.2) * 2;
    final yaw =
        -18 * math.pi / 180 +
        math.sin(elapsedSeconds * math.pi * 2 / 4) * 5 * math.pi / 180;
    final pitch =
        12 * math.pi / 180 +
        math.sin(elapsedSeconds * math.pi * 2 / 4.6) * 3 * math.pi / 180;
    const projection = SandboxProjection(Offset(180, 140));
    final points = sandboxMatrixModuleCenters()
        .expand((center) => sandboxRectangularPrismFaces(center, 13, 13, 7))
        .expand((face) => face.vertices)
        .map(
          (point) => (point + SandboxVec3(0, 14 + hover, 0))
              .rotateY(yaw)
              .rotateX(pitch),
        )
        .map(projection.project)
        .map((point) => point.offset);
    return _boundsFor(points);
  }

  Rect _completedVoxelBounds(double elapsedSeconds) {
    const projection = SandboxProjection(Offset(181, 143));
    final yaw = elapsedSeconds * 22 * math.pi / 180;
    final pitch =
        math.sin(elapsedSeconds * 2 * math.pi / 3) * 6 * math.pi / 180;
    final hover = math.sin(elapsedSeconds * 2 * math.pi / 3.2) * 3;
    final points = sandboxVoxelCenters()
        .expand(
          (center) => sandboxCubeFaces(
            (center * (22 / 24) + SandboxVec3(0, 23 + hover, 0))
                .rotateY(yaw)
                .rotateX(pitch),
            22,
          ).expand((face) => face.vertices),
        )
        .map(projection.project)
        .map((point) => point.offset);
    return _boundsFor(points);
  }

  Rect _completedCubeBounds(double elapsedSeconds) {
    const projection = SandboxProjection(Offset(181, 148));
    final yaw = elapsedSeconds * 20 * math.pi / 180;
    final pitch =
        math.sin(elapsedSeconds * 2 * math.pi / 3) * 7 * math.pi / 180;
    final hover = math.sin(elapsedSeconds * 2 * math.pi / 3.2) * 4;
    final points = sandboxFusionCubeFaces(1)
        .expand((face) => face.vertices)
        .map(
          (point) => (point + SandboxVec3(0, 25 + hover, 0))
              .rotateY(yaw)
              .rotateX(pitch),
        )
        .map(projection.project)
        .map((point) => point.offset);
    return _boundsFor(points);
  }

  Rect _boundsFor(Iterable<Offset> points) {
    final list = points.toList();
    return Rect.fromLTRB(
      list.map((point) => point.dx).reduce(math.min),
      list.map((point) => point.dy).reduce(math.min),
      list.map((point) => point.dx).reduce(math.max),
      list.map((point) => point.dy).reduce(math.max),
    );
  }

  void _paintParticles(
    Canvas canvas,
    SandboxParticleField field, {
    bool frontOnly = false,
    required bool reducedMotion,
  }) {
    final layers = frontOnly
        ? const [SandboxParticleDepthLayer.front]
        : const [
            SandboxParticleDepthLayer.back,
            SandboxParticleDepthLayer.side,
          ];
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(20, 72, 320, 137));
    for (final layer in layers) {
      for (final particle in sandboxParticleVisuals(
        field.copyWith(depthLayer: layer),
        reducedMotion: reducedMotion,
      )) {
        final wide = particle.color.withValues(alpha: particle.wideAlpha);
        final near = particle.color.withValues(alpha: particle.nearAlpha);
        canvas.drawCircle(
          particle.position,
          particle.radius * 2.5,
          _fill(wide)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5),
        );
        canvas.drawCircle(
          particle.position,
          particle.radius * 1.55,
          _fill(near)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
        );
        canvas.drawCircle(
          particle.position,
          particle.radius,
          _fill(particle.color.withValues(alpha: particle.coreAlpha)),
        );
      }
    }
    canvas.restore();
  }

  void _assemblyMatrix(Canvas canvas, double t, double post) {
    const projection = SandboxProjection(Offset(180, 140));
    final complete = _isConstructionComplete(t);
    final lift = _ease(_phase(t, 4100 / 6000, 4700 / 6000));
    final hover = complete ? math.sin(post * math.pi * 2 / 3.2) * 3 : 0.0;
    final yaw =
        -18 * math.pi / 180 +
        (complete ? math.sin(post * math.pi * 2 / 4) * 5 * math.pi / 180 : 0);
    final pitch =
        12 * math.pi / 180 +
        (complete ? math.sin(post * math.pi * 2 / 4.6) * 3 * math.pi / 180 : 0);
    SandboxVec3 transform(SandboxVec3 point) =>
        (point + SandboxVec3(0, 14 * lift + hover, 0))
            .rotateY(yaw)
            .rotateX(pitch);
    final faces = <_RenderFace>[];
    for (var index = 0; index < 36; index++) {
      final target = sandboxMatrixModuleCenters()[index];
      final start = SandboxVec3(
        target.x + 65 * math.cos(index * 2.399963229728653),
        target.y + 48 * math.sin(index * 2.399963229728653),
        35 + (index % 5) * 10,
      );
      final arrival = _ease(
        _phase(t, (400 + index * 35) / 6000, (400 + index * 35 + 720) / 6000),
      );
      final position =
          SandboxVec3.lerp(start, target, arrival) +
          SandboxVec3(0, 0, math.sin(arrival * math.pi) * 14);
      for (final face in sandboxRectangularPrismFaces(
        transform(position),
        13,
        13,
        7,
      )) {
        faces.add(
          _RenderFace(face.vertices, face.normal, _cyan.withValues(alpha: .86)),
        );
      }
    }
    _paint3dFaces(
      canvas,
      projection,
      faces,
      border: _ice.withValues(alpha: .8),
    );
    final connections = _phase(t, 2500 / 6000, 3200 / 6000);
    final centers = sandboxMatrixModuleCenters().map(transform).toList();
    final links = sandboxMatrixAdjacencyLinks();
    for (var index = 0; index < (links.length * connections).floor(); index++) {
      final link = links[index];
      final a = projection.project(centers[link.$1]).offset;
      final b = projection.project(centers[link.$2]).offset;
      canvas.drawLine(a, b, _line(_ice.withValues(alpha: .55), .7));
    }
    final pulse = _phase(t, 3200 / 6000, 4100 / 6000);
    if (pulse > 0) {
      for (final center in centers) {
        final distance = math.max(center.x.abs(), center.y.abs()) / 74;
        final energy = (1 - ((pulse * 3 - distance * 2.4).remainder(1)).abs())
            .clamp(0, 1);
        if (energy > .78) {
          canvas.drawCircle(
            projection.project(center).offset,
            2.5,
            _fill(_ice.withValues(alpha: (energy - .78) * 1.2)),
          );
        }
      }
    }
    if (t >= 4700 / 6000 || complete) {
      final scan = complete
          ? (post / 2.8).remainder(1)
          : _phase(t, 4700 / 6000, 1);
      final y = 96 + scan * 88;
      canvas.drawLine(
        Offset(122, y),
        Offset(238, y - 24),
        _glow(_ice.withValues(alpha: .42), 2, 1.5),
      );
    }
  }

  void _voxelIntegration(Canvas canvas, double t, double post) {
    const sceneCenter = Offset(181, 143);
    final projection = SandboxProjection(sceneCenter);
    final centers = sandboxVoxelCenters();
    final crystallize = _ease(_phase(t, 3700 / 6000, 4400 / 6000));
    final lift = _ease(_phase(t, 4400 / 6000, 5000 / 6000));
    final afterComplete = _isConstructionComplete(t);
    final seconds = post;
    final yaw = afterComplete ? seconds * 22 * math.pi / 180 : 0.0;
    final pitch = afterComplete
        ? math.sin(seconds * 2 * math.pi / 3) * 6 * math.pi / 180
        : 0.0;
    final hover = afterComplete
        ? math.sin(seconds * 2 * math.pi / 3.2) * 3
        : 0.0;
    final rise = 23 * lift + hover;
    final emission = t >= 4400 / 6000 && t < 4700 / 6000
        ? .52
        : afterComplete
        ? .28
        : crystallize > 0
        ? .22 + crystallize * .2
        : .22;
    _text(
      canvas,
      'CORE CHAMBER / 3x3x3',
      const Offset(108, 75),
      8,
      const Color(0xffb0e6ff),
    );
    final faces = <_RenderFace>[];
    for (var index = 0; index < centers.length; index++) {
      final visibleAt = index * (1100 / 27) / 6000;
      if (t < visibleAt) continue;
      final travelStart = 1100 / 6000 + index * (45 / 6000);
      final travel = _ease(_phase(t, travelStart, travelStart + 700 / 6000));
      final source = sandboxVoxelSource(index);
      final finalCenter = centers[index] * (1 - crystallize * (2 / 24));
      var position = SandboxVec3.lerp(source, finalCenter, travel);
      final previous = SandboxVec3.lerp(
        source,
        finalCenter,
        math.max(0, travel - .12),
      );
      position = position + SandboxVec3(0, rise, 0);
      position = position.rotateY(yaw).rotateX(pitch);
      final base = sandboxVoxelColorForIndex(
        centers[index],
        index,
      ).withValues(alpha: .84);
      final cube = sandboxCubeFaces(position, 22);
      for (final face in cube) {
        faces.add(_RenderFace(face.vertices, face.normal, base));
      }
      final projected = projection.project(position);
      if (travel > 0 && travel < 1) {
        final trail = projection.project(previous).offset;
        canvas.drawLine(
          trail,
          projected.offset,
          _glow(base.withValues(alpha: .18 * (1 - travel)), 2.5, 1.4),
        );
      }
      canvas.drawCircle(
        projected.offset,
        4.5,
        _glow(base.withValues(alpha: emission), 5, 5),
      );
      canvas.drawCircle(
        projected.offset,
        2.2,
        _glow(_ice.withValues(alpha: emission), 2.5, 2.5),
      );
    }
    _paint3dFaces(
      canvas,
      projection,
      faces,
      border: _ice.withValues(alpha: .84),
    );
    if (afterComplete || t >= 5000 / 6000) {
      _center(canvas, 'CORE INTEGRATED', const Offset(181, 202), 8, _ice);
    }
  }

  void _polyhedralFold(Canvas canvas, double t, double post) {
    const center = Offset(181, 148);
    final projection = SandboxProjection(center);
    final fuse = _phase(t, 600 / 6000, 2400 / 6000);
    final lift = _ease(_phase(t, 3500 / 6000, 4100 / 6000));
    final afterComplete = _isConstructionComplete(t);
    final seconds = post;
    final yaw = afterComplete ? seconds * 20 * math.pi / 180 : 0.0;
    final pitch = afterComplete
        ? math.sin(seconds * 2 * math.pi / 3) * 7 * math.pi / 180
        : 0.0;
    final hover = afterComplete
        ? math.sin(seconds * 2 * math.pi / 3.2) * 4
        : 0.0;
    final faces = sandboxFusionCubeFaces(fuse).asMap().entries.map((entry) {
      final face = entry.value.transform(
        (point) => (point + SandboxVec3(0, 25 * lift + hover, 0))
            .rotateY(yaw)
            .rotateX(pitch),
      );
      return _RenderFace(
        face.vertices,
        face.normal.rotateY(yaw).rotateX(pitch),
        Color.lerp(_cyan, _violet, (entry.key % 3) / 3)!.withValues(alpha: .76),
      );
    }).toList();
    final shadow = 1 - lift * .15;
    canvas.drawOval(
      Rect.fromCenter(center: center + Offset(0, 56), width: 94, height: 17),
      _fill(const Color(0xff02080c).withValues(alpha: .45 * shadow)),
    );
    _paint3dFaces(
      canvas,
      projection,
      faces,
      border: _ice.withValues(alpha: t >= 2400 / 6000 ? .9 : .6),
    );
    if (t >= 2400 / 6000) {
      final progress = _phase(t, 2400 / 6000, 3500 / 6000);
      final edges = sandboxCubeEdges();
      for (var index = 0; index < (edges.length * progress).floor(); index++) {
        final edge = edges[index];
        final a = projection
            .project(
              (edge.$1 + SandboxVec3(0, 25 * lift + hover, 0))
                  .rotateY(yaw)
                  .rotateX(pitch),
            )
            .offset;
        final b = projection
            .project(
              (edge.$2 + SandboxVec3(0, 25 * lift + hover, 0))
                  .rotateY(yaw)
                  .rotateX(pitch),
            )
            .offset;
        canvas.drawLine(a, b, _glow(_ice.withValues(alpha: .55), 2, 1.1));
      }
      _center(canvas, 'CUBE SEALED', const Offset(181, 205), 8, _ice);
    }
  }

  void _paint3dFaces(
    Canvas canvas,
    SandboxProjection projection,
    List<_RenderFace> faces, {
    required Color border,
  }) {
    final prepared = faces.map((face) {
      final projected = face.vertices.map(projection.project).toList();
      final depth =
          projected.fold(0.0, (sum, item) => sum + item.depth) /
          projected.length;
      return _ProjectedFace(projected, depth, face.normal, face.color);
    }).toList()..sort((a, b) => a.depth.compareTo(b.depth));
    const light = SandboxVec3(-.35, .65, .7);
    for (final face in prepared) {
      final path = Path()
        ..moveTo(face.points.first.offset.dx, face.points.first.offset.dy);
      for (final point in face.points.skip(1)) {
        path.lineTo(point.offset.dx, point.offset.dy);
      }
      path.close();
      final shade = sandboxFaceShade(face.normal, light);
      canvas.drawPath(path, _fill(_scaleColor(face.color, shade)));
      canvas.drawPath(path, _line(border, .65));
    }
  }

  void _text(
    Canvas canvas,
    String value,
    Offset offset,
    double size,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontFamily: 'ShareTechMono',
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _center(
    Canvas canvas,
    String value,
    Offset center,
    double size,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontFamily: 'ShareTechMono',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _right(
    Canvas canvas,
    String value,
    Offset right,
    double size,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontFamily: 'ShareTechMono',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(right.dx - painter.width, right.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _SendSequencePainter oldDelegate) =>
      oldDelegate.concept != concept ||
      oldDelegate.mode != mode ||
      oldDelegate.progress != progress ||
      oldDelegate.completionElapsedSeconds != completionElapsedSeconds ||
      oldDelegate.reducedMotion != reducedMotion;
}

/// Stable depth partition for the completed-only floating particle field.
enum SandboxParticleDepthLayer { back, side, front }

class SandboxParticleMotionBias {
  const SandboxParticleMotionBias(
    this.minimumVerticalSpeed,
    this.maximumVerticalSpeed,
    this.minimumOscillation,
    this.maximumOscillation,
  );

  final double minimumVerticalSpeed;
  final double maximumVerticalSpeed;
  final double minimumOscillation;
  final double maximumOscillation;
}

/// Configuration accepted by the shared sandbox particle renderer.
class SandboxParticleField {
  const SandboxParticleField({
    required this.center,
    required this.spawnBounds,
    required this.palette,
    required this.density,
    required this.motionBias,
    required this.seed,
    required this.elapsedTime,
    required this.depthLayer,
  });

  final Offset center;
  final Rect spawnBounds;
  final List<Color> palette;
  final int density;
  final SandboxParticleMotionBias motionBias;
  final int seed;
  final double elapsedTime;
  final SandboxParticleDepthLayer depthLayer;

  SandboxParticleField copyWith({
    SandboxParticleDepthLayer? depthLayer,
    double? elapsedTime,
  }) => SandboxParticleField(
    center: center,
    spawnBounds: spawnBounds,
    palette: palette,
    density: density,
    motionBias: motionBias,
    seed: seed,
    elapsedTime: elapsedTime ?? this.elapsedTime,
    depthLayer: depthLayer ?? this.depthLayer,
  );
}

class SandboxParticleVisual {
  const SandboxParticleVisual({
    required this.index,
    required this.position,
    required this.radius,
    required this.color,
    required this.coreAlpha,
    required this.nearAlpha,
    required this.wideAlpha,
    required this.depthLayer,
  });

  final int index;
  final Offset position;
  final double radius;
  final Color color;
  final double coreAlpha;
  final double nearAlpha;
  final double wideAlpha;
  final SandboxParticleDepthLayer depthLayer;
}

int sandboxParticleCount(BootSendSequenceConcept concept) => switch (concept) {
  BootSendSequenceConcept.assemblyMatrix => 12,
  BootSendSequenceConcept.voxelIntegration => 18,
  BootSendSequenceConcept.polyhedralFold => 15,
};

/// Pure deterministic particle positions.  It deliberately does not use
/// Random so replaying a concept produces the same floating energy field.
List<SandboxParticleVisual> sandboxParticleVisuals(
  SandboxParticleField field, {
  bool reducedMotion = false,
}) {
  final count = reducedMotion ? 4 : field.density;
  final visuals = <SandboxParticleVisual>[];
  final backCount = (count * .35).round();
  final sideCount = (count * .45).round();
  for (var index = 0; index < count; index++) {
    final layer = index < backCount
        ? SandboxParticleDepthLayer.back
        : index < backCount + sideCount
        ? SandboxParticleDepthLayer.side
        : SandboxParticleDepthLayer.front;
    if (layer != field.depthLayer) continue;
    final sector = index % 4;
    final horizontal = _particleUnit(field.seed, index, 1);
    final vertical = _particleUnit(field.seed, index, 2);
    final inset = _particleUnit(field.seed, index, 3);
    final origin = switch (sector) {
      0 => Offset(
        field.spawnBounds.left + 3 + inset * 7,
        field.spawnBounds.top +
            field.spawnBounds.height * (.12 + vertical * .76),
      ),
      1 => Offset(
        field.spawnBounds.right - 3 - inset * 7,
        field.spawnBounds.top +
            field.spawnBounds.height * (.12 + vertical * .76),
      ),
      2 => Offset(
        field.spawnBounds.left +
            field.spawnBounds.width * (.12 + horizontal * .76),
        field.spawnBounds.bottom - 3 - inset * 5,
      ),
      _ => Offset(
        field.spawnBounds.left +
            field.spawnBounds.width * (.12 + horizontal * .76),
        field.spawnBounds.top + 3 + inset * 5,
      ),
    };
    final phaseOffset = _particleUnit(field.seed, index, 4);
    final palettePick = (_particleUnit(field.seed, index, 5) * 20).floor();
    final color =
        field.palette[palettePick < 9
            ? 0
            : palettePick < 15
            ? 1
            : palettePick < 18
            ? 2
            : 3];
    if (reducedMotion) {
      visuals.add(
        SandboxParticleVisual(
          index: index,
          position: origin,
          radius: 1.4 + (index % 3) * .35,
          color: field.palette[index.isEven ? 1 : 3],
          coreAlpha: .35,
          nearAlpha: .12,
          wideAlpha: .08,
          depthLayer: layer,
        ),
      );
      continue;
    }
    final lifespan = 1.4 + _particleUnit(field.seed, index, 6) * 1.2;
    final life = (field.elapsedTime / lifespan + phaseOffset).remainder(1.0);
    final velocity =
        field.motionBias.minimumVerticalSpeed +
        _particleUnit(field.seed, index, 7) *
            (field.motionBias.maximumVerticalSpeed -
                field.motionBias.minimumVerticalSpeed);
    final oscillation =
        field.motionBias.minimumOscillation +
        _particleUnit(field.seed, index, 8) *
            (field.motionBias.maximumOscillation -
                field.motionBias.minimumOscillation);
    final period = 2 + _particleUnit(field.seed, index, 9) * 1.4;
    final position = Offset(
      origin.dx +
          oscillation *
              math.sin(
                2 * math.pi * field.elapsedTime / period +
                    phaseOffset * 2 * math.pi,
              ),
      origin.dy - velocity * lifespan * life,
    );
    final envelope = _particleEnvelope(life);
    final fadeIn = _smoothStep(0, .35, field.elapsedTime);
    final front = layer == SandboxParticleDepthLayer.front ? .75 : 1.0;
    final corePeak = .55 + _particleUnit(field.seed, index, 10) * .35;
    final glowPeak = .18 + _particleUnit(field.seed, index, 11) * .14;
    final alpha = envelope * fadeIn * front;
    visuals.add(
      SandboxParticleVisual(
        index: index,
        position: position,
        radius: _particleRadius(index),
        color: color,
        coreAlpha: corePeak * alpha,
        nearAlpha: glowPeak * alpha,
        wideAlpha: glowPeak * .72 * alpha,
        depthLayer: layer,
      ),
    );
  }
  return visuals;
}

double _particleUnit(int seed, int index, int salt) {
  final value =
      math.sin(
        (seed * 73856093 + index * 19349663 + salt * 83492791).toDouble(),
      ) *
      43758.5453123;
  return value - value.floorToDouble();
}

double _particleRadius(int index) {
  final bucket = index % 10;
  if (bucket < 6) return 1.4;
  if (bucket < 9) return 2.1;
  return 2.8;
}

double _particleEnvelope(double phase) =>
    _smoothStep(0, .15, phase) * (1 - _smoothStep(.7, 1, phase));

double _smoothStep(double edge0, double edge1, double value) {
  final normalized = ((value - edge0) / (edge1 - edge0)).clamp(0, 1).toDouble();
  return normalized * normalized * (3 - 2 * normalized);
}

/// Small immutable 3D vector used only by the sandbox renderers and tests.
class SandboxVec3 {
  const SandboxVec3(this.x, this.y, this.z);

  static const zero = SandboxVec3(0, 0, 0);
  final double x;
  final double y;
  final double z;

  SandboxVec3 operator +(SandboxVec3 other) =>
      SandboxVec3(x + other.x, y + other.y, z + other.z);
  SandboxVec3 operator -(SandboxVec3 other) =>
      SandboxVec3(x - other.x, y - other.y, z - other.z);
  SandboxVec3 operator *(double scalar) =>
      SandboxVec3(x * scalar, y * scalar, z * scalar);
  double dot(SandboxVec3 other) => x * other.x + y * other.y + z * other.z;
  SandboxVec3 cross(SandboxVec3 other) => SandboxVec3(
    y * other.z - z * other.y,
    z * other.x - x * other.z,
    x * other.y - y * other.x,
  );
  double get length => math.sqrt(dot(this));
  SandboxVec3 normalized() {
    final magnitude = length;
    return magnitude == 0 ? zero : this * (1 / magnitude);
  }

  SandboxVec3 rotateX(double radians) => SandboxVec3(
    x,
    y * math.cos(radians) - z * math.sin(radians),
    y * math.sin(radians) + z * math.cos(radians),
  );
  SandboxVec3 rotateY(double radians) => SandboxVec3(
    x * math.cos(radians) + z * math.sin(radians),
    y,
    -x * math.sin(radians) + z * math.cos(radians),
  );

  /// Rodrigues rotation about a normalized physical hinge axis.
  SandboxVec3 rotateAroundAxis(
    SandboxVec3 pivot,
    SandboxVec3 axis,
    double radians,
  ) {
    final normalizedAxis = axis.normalized();
    final vector = this - pivot;
    final cosine = math.cos(radians);
    final sine = math.sin(radians);
    final rotated =
        vector * cosine +
        normalizedAxis.cross(vector) * sine +
        normalizedAxis * (normalizedAxis.dot(vector) * (1 - cosine));
    return pivot + rotated;
  }

  static SandboxVec3 lerp(SandboxVec3 a, SandboxVec3 b, double t) =>
      a + (b - a) * t;
}

class SandboxProjection {
  const SandboxProjection(this.center);

  final Offset center;
  static const _cameraDistance = 400.0;
  static const _focalLength = 310.0;
  static const _yaw = -30 * math.pi / 180;
  static const _pitch = 22 * math.pi / 180;

  SandboxProjectedPoint project(SandboxVec3 point) {
    final viewed = point.rotateY(_yaw).rotateX(_pitch);
    final denominator = math.max(24.0, _cameraDistance - viewed.z);
    final scale = _focalLength / denominator;
    return SandboxProjectedPoint(
      Offset(center.dx + viewed.x * scale, center.dy - viewed.y * scale),
      viewed.z,
    );
  }
}

class SandboxProjectedPoint {
  const SandboxProjectedPoint(this.offset, this.depth);
  final Offset offset;
  final double depth;
}

class SandboxFace {
  const SandboxFace(this.vertices, this.normal);
  final List<SandboxVec3> vertices;
  final SandboxVec3 normal;

  SandboxFace transform(SandboxVec3 Function(SandboxVec3 point) transform) =>
      SandboxFace(vertices.map(transform).toList(growable: false), normal);
}

class _RenderFace {
  const _RenderFace(this.vertices, this.normal, this.color);
  final List<SandboxVec3> vertices;
  final SandboxVec3 normal;
  final Color color;
}

class _ProjectedFace {
  const _ProjectedFace(this.points, this.depth, this.normal, this.color);
  final List<SandboxProjectedPoint> points;
  final double depth;
  final SandboxVec3 normal;
  final Color color;
}

List<int> sandboxMatrixAssemblyOrder() {
  final cells = List<int>.generate(36, (index) => index);
  cells.sort((a, b) {
    final ar = a ~/ 6;
    final ac = a % 6;
    final br = b ~/ 6;
    final bc = b % 6;
    final ad = math.max((ar - 2.5).abs(), (ac - 2.5).abs());
    final bd = math.max((br - 2.5).abs(), (bc - 2.5).abs());
    final distance = ad.compareTo(bd);
    if (distance != 0) return distance;
    final row = ar.compareTo(br);
    return row != 0 ? row : ac.compareTo(bc);
  });
  return cells;
}

List<SandboxVec3> sandboxMatrixModuleCenters() => [
  for (var row = 0; row < 6; row++)
    for (var column = 0; column < 6; column++)
      SandboxVec3((column - 2.5) * 16, (2.5 - row) * 16, 0),
];

List<(int, int)> sandboxMatrixAdjacencyLinks() => [
  for (var row = 0; row < 6; row++)
    for (var column = 0; column < 5; column++)
      (row * 6 + column, row * 6 + column + 1),
  for (var row = 0; row < 5; row++)
    for (var column = 0; column < 6; column++)
      (row * 6 + column, (row + 1) * 6 + column),
];

List<SandboxVec3> sandboxVoxelCenters() => [
  for (final z in [-24.0, 0.0, 24.0])
    for (final y in [-24.0, 0.0, 24.0])
      for (final x in [-24.0, 0.0, 24.0]) SandboxVec3(x, y, z),
];

SandboxVec3 sandboxVoxelSource(int index) {
  const goldenAngle = 2.399963229728653;
  final u = (index + .5) / 27;
  final z = 2 * u - 1;
  final radius = math.sqrt(1 - z * z);
  final theta = index * goldenAngle;
  return SandboxVec3(
    120 * radius * math.cos(theta),
    120 * radius * math.sin(theta),
    120 * z,
  );
}

Color sandboxVoxelColor(SandboxVec3 center) {
  final base = switch (center.z) {
    < 0 => const Color(0xff5fa8ff),
    > 0 => const Color(0xff7b90ff),
    _ => const Color(0xff63d8ff),
  };
  final blended = Color.lerp(base, const Color(0xff63d8ff), .35)!;
  final distance =
      (center.x.abs() / 24 + center.y.abs() / 24 + center.z.abs() / 24).round();
  final brightness = distance == 0
      ? 1.12
      : distance < 3
      ? 1.06
      : 1.0;
  return _scaleColor(blended, brightness);
}

Color sandboxVoxelColorForIndex(SandboxVec3 center, int index) {
  final variation = ((index * 7) % 9 - 4) / 100;
  return _scaleColor(sandboxVoxelColor(center), 1 + variation);
}

Color _scaleColor(Color color, double factor) => Color.from(
  alpha: color.a,
  red: (color.r * factor).clamp(0, 1),
  green: (color.g * factor).clamp(0, 1),
  blue: (color.b * factor).clamp(0, 1),
);

double sandboxFaceShade(SandboxVec3 normal, SandboxVec3 light) {
  final diffuse = math.max(0, normal.normalized().dot(light.normalized()));
  return .45 + .55 * diffuse;
}

List<SandboxFace> sandboxRectangularPrismFaces(
  SandboxVec3 center,
  double width,
  double height,
  double depth,
) {
  final halfX = width / 2;
  final halfY = height / 2;
  final halfZ = depth / 2;
  final vertices = [
    SandboxVec3(center.x - halfX, center.y - halfY, center.z - halfZ),
    SandboxVec3(center.x + halfX, center.y - halfY, center.z - halfZ),
    SandboxVec3(center.x + halfX, center.y + halfY, center.z - halfZ),
    SandboxVec3(center.x - halfX, center.y + halfY, center.z - halfZ),
    SandboxVec3(center.x - halfX, center.y - halfY, center.z + halfZ),
    SandboxVec3(center.x + halfX, center.y - halfY, center.z + halfZ),
    SandboxVec3(center.x + halfX, center.y + halfY, center.z + halfZ),
    SandboxVec3(center.x - halfX, center.y + halfY, center.z + halfZ),
  ];
  SandboxFace face(List<int> points, SandboxVec3 normal) =>
      SandboxFace(points.map((index) => vertices[index]).toList(), normal);
  return [
    face([4, 5, 6, 7], const SandboxVec3(0, 0, 1)),
    face([1, 0, 3, 2], const SandboxVec3(0, 0, -1)),
    face([1, 2, 6, 5], const SandboxVec3(1, 0, 0)),
    face([0, 4, 7, 3], const SandboxVec3(-1, 0, 0)),
    face([3, 7, 6, 2], const SandboxVec3(0, 1, 0)),
    face([0, 1, 5, 4], const SandboxVec3(0, -1, 0)),
  ];
}

List<SandboxFace> sandboxCubeFaces(SandboxVec3 center, double side) {
  final half = side / 2;
  final vertices = [
    SandboxVec3(center.x - half, center.y - half, center.z - half),
    SandboxVec3(center.x + half, center.y - half, center.z - half),
    SandboxVec3(center.x + half, center.y + half, center.z - half),
    SandboxVec3(center.x - half, center.y + half, center.z - half),
    SandboxVec3(center.x - half, center.y - half, center.z + half),
    SandboxVec3(center.x + half, center.y - half, center.z + half),
    SandboxVec3(center.x + half, center.y + half, center.z + half),
    SandboxVec3(center.x - half, center.y + half, center.z + half),
  ];
  SandboxFace face(List<int> indices, SandboxVec3 normal) =>
      SandboxFace(indices.map((index) => vertices[index]).toList(), normal);
  return [
    face([4, 5, 6, 7], const SandboxVec3(0, 0, 1)),
    face([1, 0, 3, 2], const SandboxVec3(0, 0, -1)),
    face([1, 2, 6, 5], const SandboxVec3(1, 0, 0)),
    face([0, 4, 7, 3], const SandboxVec3(-1, 0, 0)),
    face([3, 7, 6, 2], const SandboxVec3(0, 1, 0)),
    face([0, 1, 5, 4], const SandboxVec3(0, -1, 0)),
  ];
}

List<SandboxFace> sandboxFinalCubeFaces() =>
    sandboxCubeFaces(SandboxVec3.zero, 80);

List<SandboxFace> sandboxFusionCubeFaces(double progress) {
  final targets = sandboxFinalCubeFaces();
  final order = [5, 0, 3, 2, 1, 4];
  final orderIndex = {for (var i = 0; i < order.length; i++) order[i]: i};
  const offsets = [
    SandboxVec3(12, -12, 0),
    SandboxVec3(-10, 14, 0),
    SandboxVec3(0, 15, 10),
    SandboxVec3(0, -12, -14),
    SandboxVec3(16, 0, 8),
    SandboxVec3(-14, 0, -10),
  ];
  return [
    for (var index = 0; index < targets.length; index++)
      _fusionFace(
        targets[index],
        offsets[index],
        _ease(
          _phase(
            progress,
            orderIndex[index]! * .08,
            .6 + orderIndex[index]! * .08,
          ),
        ),
      ),
  ];
}

SandboxFace _fusionFace(SandboxFace target, SandboxVec3 tangent, double t) {
  final center = target.vertices.reduce((a, b) => a + b) * .25;
  final sourceCenter = center + target.normal * 65 + tangent;
  final axis = target.normal.z.abs() > .5
      ? const SandboxVec3(0, 1, 0)
      : const SandboxVec3(1, 0, 0);
  final initialAngle = 15 * math.pi / 180;
  final currentCenter = SandboxVec3.lerp(sourceCenter, center, t);
  return SandboxFace(
    target.vertices.map((vertex) {
      final sourceOffset = (vertex - center).rotateAroundAxis(
        SandboxVec3.zero,
        axis,
        initialAngle,
      );
      return currentCenter +
          sourceOffset.rotateAroundAxis(
            SandboxVec3.zero,
            axis,
            -initialAngle * t,
          );
    }).toList(),
    target.normal.rotateAroundAxis(
      SandboxVec3.zero,
      axis,
      initialAngle * (1 - t),
    ),
  );
}

List<(SandboxVec3, SandboxVec3)> sandboxCubeEdges() {
  final edges = <String, (SandboxVec3, SandboxVec3)>{};
  for (final face in sandboxFinalCubeFaces()) {
    for (var index = 0; index < 4; index++) {
      final a = face.vertices[index];
      final b = face.vertices[(index + 1) % 4];
      final key = [
        a,
        b,
      ].map((point) => '${point.x}:${point.y}:${point.z}').toList()..sort();
      edges[key.join('|')] = (a, b);
    }
  }
  return edges.values.toList();
}

List<SandboxFace> sandboxFoldedCubeFaces(double progress) {
  const side = 80.0;
  const h = 40.0;
  final base = sandboxCubeFaces(SandboxVec3.zero, side).first;
  final rightProgress = _hingeProgress(progress, 0, .56);
  final leftProgress = _hingeProgress(progress, .10, .66);
  final topProgress = _hingeProgress(progress, .20, .76);
  final bottomProgress = _hingeProgress(progress, .30, .86);
  final rearProgress = _hingeProgress(progress, .46, 1);
  SandboxFace make(List<SandboxVec3> points, SandboxVec3 normal) =>
      SandboxFace(points, normal);
  final right = make([
    const SandboxVec3(h, -h, h),
    const SandboxVec3(3 * h, -h, h),
    const SandboxVec3(3 * h, h, h),
    const SandboxVec3(h, h, h),
  ], const SandboxVec3(0, 0, 1));
  final left = make([
    const SandboxVec3(-3 * h, -h, h),
    const SandboxVec3(-h, -h, h),
    const SandboxVec3(-h, h, h),
    const SandboxVec3(-3 * h, h, h),
  ], const SandboxVec3(0, 0, 1));
  final top = make([
    const SandboxVec3(-h, h, h),
    const SandboxVec3(h, h, h),
    const SandboxVec3(h, 3 * h, h),
    const SandboxVec3(-h, 3 * h, h),
  ], const SandboxVec3(0, 0, 1));
  final bottom = make([
    const SandboxVec3(-h, -3 * h, h),
    const SandboxVec3(h, -3 * h, h),
    const SandboxVec3(h, -h, h),
    const SandboxVec3(-h, -h, h),
  ], const SandboxVec3(0, 0, 1));
  final rear = make([
    const SandboxVec3(-h, 3 * h, h),
    const SandboxVec3(h, 3 * h, h),
    const SandboxVec3(h, 5 * h, h),
    const SandboxVec3(-h, 5 * h, h),
  ], const SandboxVec3(0, 0, 1));
  SandboxFace rotateFace(
    SandboxFace face,
    SandboxVec3 pivot,
    SandboxVec3 axis,
    double angle,
  ) => SandboxFace(
    face.vertices
        .map((point) => point.rotateAroundAxis(pivot, axis, angle))
        .toList(),
    face.normal.rotateAroundAxis(SandboxVec3.zero, axis, angle),
  );
  final foldedRight = rotateFace(
    right,
    const SandboxVec3(h, 0, h),
    const SandboxVec3(0, 1, 0),
    math.pi / 2 * rightProgress,
  );
  final foldedLeft = rotateFace(
    left,
    const SandboxVec3(-h, 0, h),
    const SandboxVec3(0, 1, 0),
    -math.pi / 2 * leftProgress,
  );
  final foldedTop = rotateFace(
    top,
    const SandboxVec3(0, h, h),
    const SandboxVec3(1, 0, 0),
    -math.pi / 2 * topProgress,
  );
  final foldedBottom = rotateFace(
    bottom,
    const SandboxVec3(0, -h, h),
    const SandboxVec3(1, 0, 0),
    math.pi / 2 * bottomProgress,
  );
  final topPivot = const SandboxVec3(0, h, h);
  final parentAngle = -math.pi / 2 * topProgress;
  final rearAfterParent = rotateFace(
    rear,
    topPivot,
    const SandboxVec3(1, 0, 0),
    parentAngle,
  );
  final rearHinge = const SandboxVec3(
    0,
    3 * h,
    h,
  ).rotateAroundAxis(topPivot, const SandboxVec3(1, 0, 0), parentAngle);
  final rearAxis = const SandboxVec3(
    1,
    0,
    0,
  ).rotateAroundAxis(SandboxVec3.zero, const SandboxVec3(1, 0, 0), parentAngle);
  final foldedRear = rotateFace(
    rearAfterParent,
    rearHinge,
    rearAxis,
    -math.pi / 2 * rearProgress,
  );
  return [base, foldedRight, foldedLeft, foldedTop, foldedBottom, foldedRear];
}

double _hingeProgress(double progress, double start, double end) =>
    Curves.easeInOutCubic.transform(_phase(progress, start, end));
