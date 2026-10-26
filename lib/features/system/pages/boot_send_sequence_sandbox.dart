import 'dart:math' as math;

import 'package:flutter/material.dart';

enum BootSendSequenceConcept { terminalSend, packetUplink, archiveDispatch }

enum BootSendSequencePhase {
  initializing,
  buildingData,
  transmitting,
  complete,
}

const _cycle = Duration(milliseconds: 6000);

/// Sandbox-only comparison bench for proposed BRIEF/DEBRIEF/BACKUP send
/// feedback. It has no production callback, data dependency, or sound hook.
class BootSendSequenceSandbox extends StatefulWidget {
  const BootSendSequenceSandbox({super.key});

  @override
  State<BootSendSequenceSandbox> createState() =>
      _BootSendSequenceSandboxState();
}

class _BootSendSequenceSandboxState extends State<BootSendSequenceSandbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _concept = BootSendSequenceConcept.terminalSend;

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
              value: BootSendSequenceConcept.terminalSend,
              label: Text('TERMINAL'),
            ),
            ButtonSegment(
              value: BootSendSequenceConcept.packetUplink,
              label: Text('PACKET'),
            ),
            ButtonSegment(
              value: BootSendSequenceConcept.archiveDispatch,
              label: Text('ARCHIVE'),
            ),
          ],
          selected: {_concept},
          onSelectionChanged: (value) {
            setState(() => _concept = value.first);
            _replay();
          },
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _SendSequenceMonitor(
            concept: _concept,
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
  BootSendSequenceConcept.terminalSend => 'TERMINAL SEND',
  BootSendSequenceConcept.packetUplink => 'PACKET UPLINK',
  BootSendSequenceConcept.archiveDispatch => 'ARCHIVE DISPATCH',
};

BootSendSequencePhase bootSendSequencePhase(double progress) =>
    switch (progress) {
      < .1334 => BootSendSequencePhase.initializing,
      < .4 => BootSendSequencePhase.buildingData,
      < .7667 => BootSendSequencePhase.transmitting,
      _ => BootSendSequencePhase.complete,
    };

String bootSendSequencePhaseLabel(BootSendSequencePhase phase) =>
    switch (phase) {
      BootSendSequencePhase.initializing => 'INITIALIZING',
      BootSendSequencePhase.buildingData => 'BUILDING DATA',
      BootSendSequencePhase.transmitting => 'TRANSMITTING',
      BootSendSequencePhase.complete => 'COMPLETE',
    };

class _SendSequenceMonitor extends StatelessWidget {
  const _SendSequenceMonitor({required this.concept, required this.progress});
  final BootSendSequenceConcept concept;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final phase = bootSendSequencePhase(progress);
    return AspectRatio(
      aspectRatio: 1.72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xff060b12),
          border: Border.all(color: const Color(0xff2d6e86)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Color(0x3300cfee), blurRadius: 10),
          ],
        ),
        child: CustomPaint(
          painter: _SendSequencePainter(concept: concept, progress: progress),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'SYSTEM / 01',
                      style: TextStyle(fontSize: 9, color: Color(0xff75aabe)),
                    ),
                    Expanded(
                      child: Text(
                        _caption(concept),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.1,
                          color: Color(0xffd8fbff),
                        ),
                      ),
                    ),
                    _StatusLamp(
                      complete: phase == BootSendSequencePhase.complete,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  phase == BootSendSequencePhase.complete
                      ? concept == BootSendSequenceConcept.archiveDispatch
                            ? 'ARCHIVE SENT'
                            : concept == BootSendSequenceConcept.packetUplink
                            ? 'VERIFY OK'
                            : 'TRANSMISSION COMPLETE'
                      : bootSendSequencePhaseLabel(phase),
                  key: const ValueKey('boot-send-sequence-phase'),
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: Color(0xffb9f5ff),
                  ),
                ),
                const SizedBox(height: 5),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  color: const Color(0xff28ddf6),
                  backgroundColor: const Color(0xff173343),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusLamp extends StatelessWidget {
  const _StatusLamp({required this.complete});
  final bool complete;
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('boot-send-sequence-status-lamp'),
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: complete ? const Color(0xff79fff2) : const Color(0xff248aa2),
      boxShadow: [
        BoxShadow(
          color: (complete ? const Color(0xff55f6e4) : const Color(0xff258aa2))
              .withValues(alpha: .6),
          blurRadius: 5,
        ),
      ],
    ),
  );
}

class _SendSequencePainter extends CustomPainter {
  const _SendSequencePainter({required this.concept, required this.progress});
  final BootSendSequenceConcept concept;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(14, 38, size.width - 28, size.height - 86);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    paint.color = const Color(0xff1d4c60);
    for (var x = rect.left; x <= rect.right; x += 20) {
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
    }
    for (var y = rect.top; y <= rect.bottom; y += 16) {
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }
    switch (concept) {
      case BootSendSequenceConcept.terminalSend:
        _terminal(canvas, rect);
      case BootSendSequenceConcept.packetUplink:
        _packets(canvas, rect);
      case BootSendSequenceConcept.archiveDispatch:
        _archive(canvas, rect);
    }
  }

  Paint _fill(Color color) => Paint()..color = color;
  Paint _line(Color color, [double width = 1]) => Paint()
    ..color = color
    ..strokeWidth = width
    ..style = PaintingStyle.stroke;

  void _terminal(Canvas c, Rect r) {
    c.drawLine(
      Offset(r.left + 8, r.top),
      Offset(r.left + 8, r.bottom),
      _line(const Color(0xff34d9f2), 2),
    );
    final built = ((progress - .133) / .267 * 6).clamp(0, 6).floor();
    for (var i = 0; i < 6; i++) {
      final y = r.top + 10 + i * 13.0;
      c.drawRect(
        Rect.fromLTWH(r.left + 22, y, r.width * (.32 + i * .07), 5),
        _fill(i < built ? const Color(0xff76e8f4) : const Color(0xff214858)),
      );
    }
    if (progress >= .4) {
      final scan = r.left + (progress - .4) / .367 * r.width;
      c.drawLine(
        Offset(r.left + 20, r.bottom - 10),
        Offset(math.min(scan, r.right), r.bottom - 10),
        _line(const Color(0xffe1ffff), 2),
      );
      c.drawLine(
        Offset(math.max(r.left + 20, scan - 18), r.top + 4),
        Offset(math.min(r.right, scan), r.top + 4),
        _line(const Color(0xff31dff7), 2),
      );
    }
  }

  void _packets(Canvas c, Rect r) {
    final source = Rect.fromLTWH(r.left + 8, r.center.dy - 24, 40, 48);
    final target = Rect.fromLTWH(r.right - 48, r.center.dy - 24, 40, 48);
    c.drawRect(source, _line(const Color(0xff69e6f3), 1.4));
    c.drawRect(target, _line(const Color(0xff69e6f3), 1.4));
    final building = ((progress - .133) / .267).clamp(0, 1).toDouble();
    for (var i = 0; i < 4; i++) {
      c.drawRect(
        Rect.fromLTWH(
          source.left + 7,
          source.top + 8 + i * 9,
          26 * building,
          4,
        ),
        _fill(const Color(0xff64dbea)),
      );
    }
    if (progress >= .4) {
      final travel = ((progress - .4) / .367).clamp(0, 1).toDouble();
      for (var i = 0; i < 6; i++) {
        final t = (travel * 1.35 - i * .16).clamp(0.0, 1.0).toDouble();
        final x = source.right + (target.left - source.right - 12) * t;
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, r.center.dy - 10 + (i % 3) * 8, 10, 4),
            const Radius.circular(2),
          ),
          _fill(const Color(0xffd9ffff)),
        );
      }
    }
  }

  void _archive(Canvas c, Rect r) {
    final chamber = Rect.fromCenter(center: r.center, width: 42, height: 48);
    c.drawRect(chamber, _line(const Color(0xff6fe9f8), 1.4));
    for (var i = 0; i < 4; i++) {
      final t = ((progress - .133) / .267 - i * .18).clamp(0.0, 1.0).toDouble();
      final x = r.left + 8 + (chamber.left - r.left - 26) * t;
      c.drawRect(
        Rect.fromLTWH(x, r.top + 8 + i * 12, 22, 7),
        _fill(const Color(0xff5fcfe2)),
      );
    }
    if (progress >= .4) {
      final beam = ((progress - .4) / .367).clamp(0, 1).toDouble();
      c.drawLine(
        Offset(chamber.right, r.center.dy),
        Offset(
          chamber.right + (r.right - chamber.right - 8) * beam,
          r.center.dy,
        ),
        _line(const Color(0xffe1ffff), 2),
      );
      c.drawRect(
        Rect.fromLTWH(r.right - 20, r.center.dy - 15, 12, 30),
        _line(const Color(0xff5fddec), 1.2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SendSequencePainter old) =>
      old.concept != concept || old.progress != progress;
}
