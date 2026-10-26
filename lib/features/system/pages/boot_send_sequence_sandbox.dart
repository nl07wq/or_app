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

class BootSendSequenceSandbox extends StatefulWidget {
  const BootSendSequenceSandbox({super.key});

  @override
  State<BootSendSequenceSandbox> createState() =>
      _BootSendSequenceSandboxState();
}

class _BootSendSequenceSandboxState extends State<BootSendSequenceSandbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _concept = BootSendSequenceConcept.assemblyMatrix;
  var _mode = _OperationMode.brief;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _cycle)..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _replay() => _controller.forward(from: 0);

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
          animation: _controller,
          builder: (_, _) => _SendSequenceMonitor(
            concept: _concept,
            mode: _mode,
            progress: reducedMotion ? 1 : _controller.value,
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
double _ease(double value) =>
    Curves.easeInOutCubic.transform(value.clamp(0, 1));

class _SendSequenceMonitor extends StatelessWidget {
  const _SendSequenceMonitor({
    required this.concept,
    required this.mode,
    required this.progress,
  });

  final BootSendSequenceConcept concept;
  final _OperationMode mode;
  final double progress;

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
  });

  final BootSendSequenceConcept concept;
  final _OperationMode mode;
  final double progress;

  static const _screen = Color(0xff030d15);
  static const _cyan = Color(0xff39ddf2);
  static const _ice = Color(0xffd8fbff);
  static const _violet = Color(0xff9588d9);
  static const _amber = Color(0xffcaa765);

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
    switch (concept) {
      case BootSendSequenceConcept.assemblyMatrix:
        _assemblyMatrix(canvas, t);
      case BootSendSequenceConcept.voxelIntegration:
        _voxelIntegration(canvas, t);
      case BootSendSequenceConcept.polyhedralFold:
        _polyhedralFold(canvas, t);
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
            BootSendSequenceConcept.assemblyMatrix => 'ASSEMBLY COMPLETE',
            BootSendSequenceConcept.voxelIntegration => 'INTEGRATION COMPLETE',
            BootSendSequenceConcept.polyhedralFold => 'FOLD COMPLETE',
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

  void _panel(Canvas canvas, Rect rect, Color accent) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      _fill(const Color(0xff071923)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      _line(accent.withValues(alpha: .55)),
    );
  }

  void _assemblyMatrix(Canvas canvas, double t) {
    const matrix = Rect.fromLTWH(114, 78, 132, 126);
    const tray = Rect.fromLTWH(34, 166, 57, 30);
    const seal = Rect.fromLTWH(270, 80, 52, 34);
    final build = _phase(t, .2, 7 / 15);
    final integrate = _phase(t, 7 / 15, 23 / 30);
    final lock = _phase(t, 23 / 30, 1);
    _text(
      canvas,
      'SOURCE TRAY',
      const Offset(34, 153),
      7.5,
      const Color(0xff86b7c5),
    );
    _panel(canvas, tray, _cyan);
    _text(canvas, 'SEAL', const Offset(270, 72), 7.5, const Color(0xff86b7c5));
    _panel(canvas, seal, _cyan);
    _text(
      canvas,
      lock >= 1
          ? 'SAVED'
          : lock > 0
          ? 'LOCK'
          : 'WAIT',
      const Offset(278, 93),
      8,
      lock > 0 ? _ice : const Color(0xff5f8795),
    );
    final litSource = (math.max(_phase(t, 0, .2), build) * 10).ceil().clamp(
      0,
      10,
    );
    for (var index = 0; index < 10; index++) {
      final x = tray.left + 7 + (index % 5) * 9.5;
      final y = tray.top + 8 + (index ~/ 5) * 11;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, 6, 6),
          const Radius.circular(1),
        ),
        _fill(
          index < litSource
              ? _cyan.withValues(alpha: .85)
              : const Color(0xff153542),
        ),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(matrix, const Radius.circular(4)),
      _fill(const Color(0xff061520)),
    );
    const order = [
      0,
      7,
      1,
      8,
      14,
      2,
      15,
      21,
      9,
      3,
      16,
      22,
      28,
      10,
      4,
      17,
      23,
      29,
      35,
      11,
      5,
      18,
      24,
      30,
      6,
      12,
      19,
      25,
      31,
      13,
      20,
      26,
      32,
      27,
      33,
      34,
    ];
    final filled = (build * 24).floor() + (integrate * 12).floor();
    for (var visualIndex = 0; visualIndex < 36; visualIndex++) {
      final cell = order[visualIndex];
      final x = matrix.left + 9 + (cell % 6) * 19;
      final y = matrix.top + 8 + (cell ~/ 6) * 19;
      final active = visualIndex < filled;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, 16, 16),
        const Radius.circular(2),
      );
      if (active) {
        canvas.drawRRect(
          rect,
          _fill(_cyan.withValues(alpha: .55 + (visualIndex % 4) * .08)),
        );
      }
      canvas.drawRRect(
        rect,
        _line(
          active ? _ice.withValues(alpha: .75) : _cyan.withValues(alpha: .22),
          .7,
        ),
      );
    }
    if (build > 0 && build < 1) {
      final cell = order[(build * 24).floor().clamp(0, 23)];
      final target = Offset(
        matrix.left + 17 + (cell % 6) * 19,
        matrix.top + 16 + (cell ~/ 6) * 19,
      );
      final point = Offset.lerp(tray.center, target, _ease((build * 24) % 1))!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: point, width: 10, height: 10),
          const Radius.circular(2),
        ),
        _fill(_ice),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(matrix, const Radius.circular(4)),
      _line(_cyan.withValues(alpha: .35 + integrate * .55), 1.1),
    );
    if (integrate > 0) {
      for (var scan = 0; scan < 3; scan++) {
        final offset = ((integrate * 1.4) + scan * .31).remainder(1.0);
        final y = matrix.top + 6 + offset * (matrix.height - 12);
        canvas.drawLine(
          Offset(matrix.left + 5, y),
          Offset(matrix.right - 5, y),
          _glow(_ice.withValues(alpha: .45), 2, 1.1),
        );
        canvas.drawLine(
          Offset(matrix.left + 5, y),
          Offset(matrix.right - 5, y),
          _line(_ice.withValues(alpha: .78), .7),
        );
      }
    }
    final bracket = 12 * _ease(lock);
    for (final point in [
      Offset(matrix.left, matrix.top),
      Offset(matrix.right, matrix.top),
      Offset(matrix.left, matrix.bottom),
      Offset(matrix.right, matrix.bottom),
    ]) {
      final dx = point.dx < matrix.center.dx ? 1.0 : -1.0;
      final dy = point.dy < matrix.center.dy ? 1.0 : -1.0;
      final paint = _line(_ice.withValues(alpha: .45 + lock * .55), 1.4);
      canvas.drawLine(point, point + Offset(dx * bracket, 0), paint);
      canvas.drawLine(point, point + Offset(0, dy * bracket), paint);
    }
  }

  void _voxelIntegration(Canvas canvas, double t) {
    const accent = Color(0xff69b9ff);
    const chamber = Rect.fromLTWH(103, 82, 154, 112);
    final build = _phase(t, .2, 7 / 15);
    final integrate = _phase(t, 7 / 15, 23 / 30);
    final lock = _phase(t, 23 / 30, 1);
    _text(
      canvas,
      'VOXEL CHAMBER',
      const Offset(111, 72),
      8,
      const Color(0xffb0e6ff),
    );
    _isometricChamber(canvas, chamber, accent);
    const nodes = [
      Offset(53, 102),
      Offset(53, 168),
      Offset(306, 102),
      Offset(306, 168),
    ];
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      canvas.drawCircle(node, 6, _line(accent.withValues(alpha: .45), 1));
      if (t >= index * .045) {
        canvas.drawCircle(node, 3, _fill(accent.withValues(alpha: .75)));
      }
      canvas.drawLine(
        node,
        chamber.center,
        _line(accent.withValues(alpha: .14), .7),
      );
    }
    const targets = [
      Offset(148, 138),
      Offset(164, 130),
      Offset(180, 138),
      Offset(196, 130),
      Offset(156, 151),
      Offset(172, 143),
      Offset(188, 151),
      Offset(204, 143),
      Offset(164, 164),
      Offset(180, 156),
      Offset(196, 164),
      Offset(212, 156),
      Offset(172, 177),
      Offset(188, 169),
      Offset(204, 177),
      Offset(220, 169),
    ];
    final count = (build * 8).floor() + (integrate * 8).floor();
    for (var index = 0; index < targets.length; index++) {
      if (index < count) {
        _cube(canvas, targets[index], accent, bright: lock > 0 || index >= 8);
      }
    }
    if (build > 0 && build < 1) {
      final index = (build * 8).floor().clamp(0, 7);
      final point = Offset.lerp(
        nodes[index % nodes.length],
        targets[index],
        _ease((build * 8) % 1),
      )!;
      _cube(canvas, point, _ice, bright: true);
    }
    if (integrate > 0 && integrate < 1) {
      final index = 8 + (integrate * 8).floor().clamp(0, 7);
      final point = Offset.lerp(
        nodes[index % nodes.length],
        targets[index],
        _ease((integrate * 8) % 1),
      )!;
      _cube(canvas, point, _ice, bright: true);
    }
    if (integrate > 0) {
      final frame = RRect.fromRectAndRadius(
        const Rect.fromLTWH(137, 119, 94, 67),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        frame,
        _line(accent.withValues(alpha: .25 + integrate * .55), 1),
      );
    }
    if (lock > 0) {
      final plate = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: const Offset(184, 151),
          width: 62 * lock,
          height: 18 * lock,
        ),
        const Radius.circular(2),
      );
      canvas.drawRRect(plate, _fill(_ice.withValues(alpha: .14)));
      canvas.drawRRect(plate, _line(_ice.withValues(alpha: .7), .8));
      _center(canvas, 'LOCK', const Offset(184, 151), 7, _ice);
    }
  }

  void _isometricChamber(Canvas canvas, Rect rect, Color accent) {
    final top = Path()
      ..moveTo(rect.center.dx, rect.top)
      ..lineTo(rect.right, rect.top + 25)
      ..lineTo(rect.center.dx, rect.top + 50)
      ..lineTo(rect.left, rect.top + 25)
      ..close();
    final left = Path()
      ..moveTo(rect.left, rect.top + 25)
      ..lineTo(rect.center.dx, rect.top + 50)
      ..lineTo(rect.center.dx, rect.bottom)
      ..lineTo(rect.left, rect.bottom - 25)
      ..close();
    final right = Path()
      ..moveTo(rect.right, rect.top + 25)
      ..lineTo(rect.center.dx, rect.top + 50)
      ..lineTo(rect.center.dx, rect.bottom)
      ..lineTo(rect.right, rect.bottom - 25)
      ..close();
    canvas.drawPath(top, _fill(const Color(0xff0e2b3a)));
    canvas.drawPath(left, _fill(const Color(0xff09202d)));
    canvas.drawPath(right, _fill(const Color(0xff12354a)));
    canvas.drawPath(top, _line(accent.withValues(alpha: .62), 1));
    canvas.drawPath(left, _line(accent.withValues(alpha: .34), .8));
    canvas.drawPath(right, _line(accent.withValues(alpha: .46), .8));
  }

  void _cube(
    Canvas canvas,
    Offset center,
    Color color, {
    required bool bright,
  }) {
    const width = 15.0;
    const height = 9.0;
    final top = Path()
      ..moveTo(center.dx, center.dy - height)
      ..lineTo(center.dx + width / 2, center.dy - height / 2)
      ..lineTo(center.dx, center.dy)
      ..lineTo(center.dx - width / 2, center.dy - height / 2)
      ..close();
    final left = Path()
      ..moveTo(center.dx - width / 2, center.dy - height / 2)
      ..lineTo(center.dx, center.dy)
      ..lineTo(center.dx, center.dy + height)
      ..lineTo(center.dx - width / 2, center.dy + height / 2)
      ..close();
    final right = Path()
      ..moveTo(center.dx + width / 2, center.dy - height / 2)
      ..lineTo(center.dx, center.dy)
      ..lineTo(center.dx, center.dy + height)
      ..lineTo(center.dx + width / 2, center.dy + height / 2)
      ..close();
    if (bright) {
      canvas.drawCircle(center, 8, _glow(color.withValues(alpha: .25), 3, 6));
    }
    canvas.drawPath(top, _fill(color.withValues(alpha: .88)));
    canvas.drawPath(left, _fill(color.withValues(alpha: .42)));
    canvas.drawPath(right, _fill(color.withValues(alpha: .64)));
    canvas.drawPath(
      top,
      _line(_ice.withValues(alpha: bright ? .85 : .45), .65),
    );
  }

  void _polyhedralFold(Canvas canvas, double t) {
    final build = _phase(t, .2, 7 / 15);
    final integrate = _phase(t, 7 / 15, 23 / 30);
    final lock = _phase(t, 23 / 30, 1);
    _text(
      canvas,
      'UNFOLDED NET',
      const Offset(37, 79),
      7.5,
      const Color(0xffb5adf2),
    );
    _text(
      canvas,
      'FOLD ARRAY',
      const Offset(151, 79),
      7.5,
      const Color(0xffb5adf2),
    );
    _text(
      canvas,
      'ARCHIVE BAY',
      const Offset(260, 79),
      7.5,
      const Color(0xffb5adf2),
    );
    const origin = Offset(70, 137);
    const center = Offset(184, 137);
    final finalCenter = Offset.lerp(
      center,
      const Offset(286, 137),
      _ease(lock),
    )!;
    _archiveBay(canvas);
    for (var index = 0; index < 6; index++) {
      final local = index < 3
          ? ((build * 3) - index).clamp(0.0, 1.0)
          : ((integrate * 3) - (index - 3)).clamp(0.0, 1.0);
      final source = origin + _netOffset(index);
      final target = finalCenter + _capsuleOffset(index);
      final face = Offset.lerp(source, target, _ease(local))!;
      _foldFace(canvas, face, index, local);
      if (local < 1) {
        canvas.drawLine(
          origin,
          source,
          _line(_violet.withValues(alpha: .22), .7),
        );
      }
    }
    if (integrate > .66) {
      final path = _capsulePath(finalCenter, 34);
      canvas.drawPath(path, _glow(_ice.withValues(alpha: .28), 3, 2));
      canvas.drawPath(path, _line(_ice.withValues(alpha: .86), 1.2));
    }
    if (lock > 0) {
      canvas.drawCircle(
        finalCenter,
        29 + lock * 7,
        _line(_ice.withValues(alpha: .4 + lock * .35), 1),
      );
      final reticle = 12 * lock;
      canvas.drawLine(
        finalCenter - Offset(reticle, 0),
        finalCenter + Offset(reticle, 0),
        _line(_ice, 1),
      );
      canvas.drawLine(
        finalCenter - Offset(0, reticle),
        finalCenter + Offset(0, reticle),
        _line(_ice, 1),
      );
      _center(canvas, 'SEAL', finalCenter + const Offset(0, 42), 7, _ice);
    }
  }

  Offset _netOffset(int index) => switch (index) {
    0 => const Offset(0, 0),
    1 => const Offset(-25, 0),
    2 => const Offset(25, 0),
    3 => const Offset(0, -25),
    4 => const Offset(0, 25),
    _ => const Offset(-25, 25),
  };
  Offset _capsuleOffset(int index) => switch (index) {
    0 => const Offset(0, -18),
    1 => const Offset(-21, -4),
    2 => const Offset(21, -4),
    3 => const Offset(-12, 16),
    4 => const Offset(12, 16),
    _ => const Offset(0, 2),
  };

  void _foldFace(Canvas canvas, Offset center, int index, double folded) {
    final width = 28 - folded * 6;
    final height = 23 - folded * 7;
    final tilt = (index.isEven ? 1 : -1) * folded * 7;
    final path = Path()
      ..moveTo(center.dx - width / 2, center.dy - height / 2 + tilt)
      ..lineTo(center.dx + width / 2, center.dy - height / 2 - tilt)
      ..lineTo(center.dx + width / 2, center.dy + height / 2 - tilt)
      ..lineTo(center.dx - width / 2, center.dy + height / 2 + tilt)
      ..close();
    canvas.drawPath(path, _fill(_violet.withValues(alpha: .22 + folded * .48)));
    canvas.drawPath(
      path,
      _line(_ice.withValues(alpha: .35 + folded * .55), .9),
    );
    canvas.drawLine(
      Offset(center.dx - width / 2 + 4, center.dy),
      Offset(center.dx + width / 2 - 4, center.dy),
      _line(_amber.withValues(alpha: .22), .55),
    );
  }

  Path _capsulePath(Offset center, double radius) => Path()
    ..moveTo(center.dx, center.dy - radius)
    ..lineTo(center.dx + radius * .82, center.dy - radius * .42)
    ..lineTo(center.dx + radius * .82, center.dy + radius * .42)
    ..lineTo(center.dx, center.dy + radius)
    ..lineTo(center.dx - radius * .82, center.dy + radius * .42)
    ..lineTo(center.dx - radius * .82, center.dy - radius * .42)
    ..close();

  void _archiveBay(Canvas canvas) {
    const bay = Rect.fromLTWH(257, 91, 62, 92);
    _panel(canvas, bay, _violet);
    for (var index = 0; index < 3; index++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(266, 106 + index * 21, 44, 13),
          const Radius.circular(2),
        ),
        _line(_violet.withValues(alpha: .45), .7),
      );
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
      oldDelegate.progress != progress;
}
