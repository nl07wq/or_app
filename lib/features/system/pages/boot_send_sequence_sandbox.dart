import 'dart:math' as math;

import 'package:flutter/material.dart';

enum BootSendSequenceConcept { terminalSend, packetUplink, archiveDispatch }

enum BootSendSequencePhase {
  initializing,
  buildingData,
  transmitting,
  complete,
}

enum _OperationMode { brief, debrief, backup }

const _cycle = Duration(milliseconds: 6000);

/// A comparison-only monitor. It has no production data or transport hook.
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
          onSelectionChanged: (v) {
            setState(() => _concept = v.first);
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
          onSelectionChanged: (v) => setState(() => _mode = v.first),
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

String _caption(BootSendSequenceConcept c) => switch (c) {
  BootSendSequenceConcept.terminalSend => 'TERMINAL SEND',
  BootSendSequenceConcept.packetUplink => 'PACKET UPLINK',
  BootSendSequenceConcept.archiveDispatch => 'ARCHIVE DISPATCH',
};
String _modeTitle(_OperationMode m) => switch (m) {
  _OperationMode.brief => 'BRIEF SEQUENCE',
  _OperationMode.debrief => 'DEBRIEF SEQUENCE',
  _OperationMode.backup => 'BACKUP SEQUENCE',
};
BootSendSequencePhase bootSendSequencePhase(double p) =>
    switch (p.clamp(0, 1)) {
      < 2 / 15 => BootSendSequencePhase.initializing,
      < 2 / 5 => BootSendSequencePhase.buildingData,
      < 23 / 30 => BootSendSequencePhase.transmitting,
      _ => BootSendSequencePhase.complete,
    };
String bootSendSequencePhaseLabel(BootSendSequencePhase p) => switch (p) {
  BootSendSequencePhase.initializing => 'INITIALIZING',
  BootSendSequencePhase.buildingData => 'BUILDING DATA',
  BootSendSequencePhase.transmitting => 'TRANSMITTING',
  BootSendSequencePhase.complete => 'COMPLETE',
};
double _phase(double t, double start, double end) =>
    ((t - start) / (end - start)).clamp(0, 1).toDouble();
double _ease(double t) => Curves.easeInOutCubic.transform(t.clamp(0, 1));

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
  static const _mint = Color(0xff35e2c2);
  Paint _fill(Color c) => Paint()..color = c;
  Paint _line(Color c, [double w = 1]) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w;
  Paint _glow(Color c, double sigma, [double w = 1]) =>
      _line(c, w)..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
  @override
  void paint(Canvas c, Size size) {
    final scale = math.min(size.width / 360, size.height / 280);
    c.save();
    c.translate(
      (size.width - 360 * scale) / 2,
      (size.height - 280 * scale) / 2,
    );
    c.scale(scale);
    final t = progress.clamp(0, 1).toDouble();
    _housing(c);
    _grid(c);
    _header(c, t);
    switch (concept) {
      case BootSendSequenceConcept.terminalSend:
        _terminal(c, t);
      case BootSendSequenceConcept.packetUplink:
        _packet(c, t);
      case BootSendSequenceConcept.archiveDispatch:
        _archive(c, t);
    }
    _footer(c, t);
    _bezel(c);
    c.restore();
  }

  void _housing(Canvas c) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 4, 352, 272),
        const Radius.circular(13),
      ),
      _fill(const Color(0xff101c25)),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 4, 352, 272),
        const Radius.circular(13),
      ),
      _line(const Color(0xff45697a), 2),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, 10, 340, 260),
        const Radius.circular(9),
      ),
      _fill(const Color(0xff061018)),
    );
    c.drawRect(const Rect.fromLTWH(19, 21, 322, 238), _fill(_screen));
    c.drawRect(
      const Rect.fromLTWH(19, 21, 322, 238),
      _line(const Color(0xff31788a)),
    );
    for (final x in [31.0, 303.0]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 14, 26, 3),
          const Radius.circular(1),
        ),
        _fill(const Color(0xff294957)),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 18, 26, 3),
          const Radius.circular(1),
        ),
        _fill(const Color(0xff172f3b)),
      );
    }
    for (final p in const [
      Offset(13, 13),
      Offset(347, 13),
      Offset(13, 267),
      Offset(347, 267),
    ]) {
      c.drawCircle(p, 2, _fill(const Color(0xff5a7a87)));
      c.drawCircle(p, .75, _fill(const Color(0xff0b151c)));
    }
    for (final q in const [
      Offset(20, 22),
      Offset(340, 22),
      Offset(20, 258),
      Offset(340, 258),
    ]) {
      final sx = q.dx < 180 ? 1.0 : -1.0,
          sy = q.dy < 140 ? 1.0 : -1.0,
          p = _line(const Color(0xff64bfcf), 1.4);
      c.drawLine(q, q + Offset(12 * sx, 0), p);
      c.drawLine(q, q + Offset(0, 12 * sy), p);
    }
  }

  void _grid(Canvas c) {
    final p = _line(const Color(0xff6ba4b5).withValues(alpha: .045), .6);
    for (var x = 20.0; x < 341; x += 24) {
      c.drawLine(Offset(x, 22), Offset(x, 258), p);
    }
    for (var y = 22.0; y < 259; y += 24) {
      c.drawLine(Offset(20, y), Offset(340, y), p);
    }
  }

  void _header(Canvas c, double t) {
    _text(c, 'SYSTEM / 01', const Offset(30, 35), 9, const Color(0xff7ba9b8));
    _center(
      c,
      _modeTitle(mode),
      const Offset(180, 39),
      10,
      const Color(0xffd8fbff),
    );
    _text(c, 'SIMULATION', const Offset(272, 35), 8, const Color(0xff6f9bac));
    final on = t >= 23 / 30 ? const Color(0xff8af6e9) : const Color(0xff2d8fa7);
    c.drawCircle(
      const Offset(327, 39),
      5,
      _glow(on.withValues(alpha: .42), 7, 5),
    );
    c.drawCircle(
      const Offset(327, 39),
      5,
      _glow(on.withValues(alpha: .75), 3, 3),
    );
    c.drawCircle(const Offset(327, 39), 3, _fill(on));
    c.drawLine(
      const Offset(30, 65),
      const Offset(330, 65),
      _line(const Color(0xff386277), .7),
    );
  }

  void _footer(Canvas c, double t) {
    final phase = bootSendSequencePhase(t);
    final status = phase == BootSendSequencePhase.complete
        ? switch (concept) {
            BootSendSequenceConcept.terminalSend => 'TRANSMISSION COMPLETE',
            BootSendSequenceConcept.packetUplink => 'UPLINK VERIFIED',
            BootSendSequenceConcept.archiveDispatch => 'ARCHIVE VERIFIED',
          }
        : bootSendSequencePhaseLabel(phase);
    _text(
      c,
      bootSendSequencePhaseLabel(phase),
      const Offset(30, 230),
      9,
      const Color(0xffa1dbe6),
    );
    _right(
      c,
      status,
      const Offset(330, 230),
      8.5,
      phase == BootSendSequencePhase.complete
          ? const Color(0xffc6fff7)
          : const Color(0xff6694a5),
    );
    final active = (t * 20).floor().clamp(0, 20);
    for (var i = 0; i < 20; i++) {
      final color = phase == BootSendSequencePhase.complete
          ? const Color(0xff8af6e9)
          : i < active
          ? const Color(0xff42daf2)
          : const Color(0xff193443);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(30 + i * 14, 242, 10, 5),
          const Radius.circular(1),
        ),
        _fill(color),
      );
    }
  }

  void _bezel(Canvas c) {
    c.drawLine(
      const Offset(13, 29),
      const Offset(13, 245),
      _line(const Color(0xff7bc6d5).withValues(alpha: .17), .7),
    );
    c.drawLine(
      const Offset(347, 29),
      const Offset(347, 245),
      _line(const Color(0xff02080c)),
    );
  }

  void _panel(Canvas c, Rect r, Color accent) {
    c.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(3)),
      _fill(const Color(0xff071923)),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(3)),
      _line(accent.withValues(alpha: .55)),
    );
  }

  void _terminal(Canvas c, double t) {
    const left = Rect.fromLTWH(28, 77, 177, 126),
        right = Rect.fromLTWH(213, 77, 118, 126);
    _panel(c, left, _cyan);
    _panel(c, right, _cyan);
    final lines = [
      'SOURCE LINK',
      'VERIFY RECORDS',
      'BUILD PAYLOAD',
      'SERIALIZE DATA',
      'OPEN CHANNEL',
      'TRANSMIT BUFFER',
    ];
    final b = _phase(t, 2 / 15, .4);
    final visible = (b * 6).ceil().clamp(0, 6);
    for (var i = 0; i < visible; i++) {
      final done = i < b * 6 - .55 || t >= .4,
          current = !done && i == visible - 1,
          color = done ? const Color(0xff8adfea) : const Color(0xffe2ffff),
          y = 88 + i * 19.0;
      c.drawCircle(
        Offset(39, y - 3),
        2,
        _fill(done ? _cyan : const Color(0xff315263)),
      );
      _text(c, '> ${lines[i]}', Offset(46, y - 8), 9.5, color);
      if (current) c.drawRect(Rect.fromLTWH(184, y - 8, 2, 11), _fill(_cyan));
    }
    final banks = (b * 4).ceil().clamp(0, 4);
    for (var i = 0; i < 4; i++) {
      final bank = Rect.fromLTWH(222, 88 + i * 19, 27, 11), on = i < banks;
      c.drawRect(
        bank,
        _fill(on ? const Color(0xff1c6676) : const Color(0xff102b36)),
      );
      c.drawRect(bank, _line(const Color(0xff6ecfdf), .7));
      if (on) {
        c.drawLine(
          Offset(bank.right, bank.center.dy),
          const Offset(260, 126),
          _line(_cyan.withValues(alpha: .65), .9),
        );
      }
    }
    const encode = Rect.fromLTWH(258, 111, 27, 30);
    c.drawRect(encode, _fill(const Color(0xff102c39)));
    c.drawRect(encode, _line(const Color(0xff92efff)));
    _center(c, 'ENC', encode.center, 7, const Color(0xffb9f8ff));
    c.drawLine(
      const Offset(285, 126),
      const Offset(310, 126),
      _line(const Color(0xff4ccfe5)),
    );
    c.drawPath(
      Path()
        ..moveTo(310, 120)
        ..lineTo(320, 126)
        ..lineTo(310, 132),
      _line(const Color(0xff92efff), 1.2),
    );
    final tx = _phase(t, .4, 23 / 30);
    for (var i = 0; i < 5; i++) {
      final p = ((tx * 1.65) - i * .23).clamp(0.0, 1.0);
      if (p > 0 && p < 1) {
        c.drawRect(
          Rect.fromLTWH(286 + p * 24, 123 + (i.isEven ? -3 : 3), 12, 4),
          _fill(const Color(0xffe2ffff)),
        );
      }
    }
  }

  void _packet(Canvas c, double t) {
    const source = Rect.fromLTWH(27, 92, 84, 88),
        dest = Rect.fromLTWH(249, 92, 84, 88);
    _panel(c, source, const Color(0xff4aaeff));
    _panel(c, dest, const Color(0xff4aaeff));
    _text(
      c,
      'LINK / TX / RX',
      const Offset(28, 78),
      8,
      const Color(0xffb0e6ff),
    );
    final b = _phase(t, 2 / 15, .4), tx = _phase(t, .4, 23 / 30);
    _memory(c, source, (b * 8).ceil().clamp(0, 8), const Color(0xff4aaeff));
    _memory(c, dest, (tx * 8).floor().clamp(0, 8), const Color(0xffb0e6ff));
    final p = _line(const Color(0xff4aaeff).withValues(alpha: .5), .8);
    c.drawArc(const Rect.fromLTWH(114, 101, 132, 35), 0, math.pi, false, p);
    c.drawArc(
      const Rect.fromLTWH(114, 126, 132, 35),
      math.pi,
      math.pi,
      false,
      p,
    );
    c.drawLine(
      const Offset(114, 136),
      const Offset(246, 136),
      _line(const Color(0xff79d8ff).withValues(alpha: .35)),
    );
    for (var i = 0; i < 8; i++) {
      final local = ((tx - (.10 + i * .09)) / .245).clamp(0.0, 1.0);
      if (local > 0 && local < 1) {
        final x = 108 + _ease(local) * 142;
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 133, 12, 6),
          const Radius.circular(2),
        );
        c.drawRRect(
          r,
          _glow(const Color(0xff4aaeff).withValues(alpha: .55), 2, 6),
        );
        c.drawRRect(r, _fill(const Color(0xffd9f6ff)));
      }
    }
    _text(
      c,
      'PACKETS ${(tx * 8).floor().clamp(0, 8).toString().padLeft(2, '0')}/08',
      const Offset(115, 172),
      8,
      const Color(0xff9ac8dc),
    );
    _text(
      c,
      tx >= 1 ? 'LINK STATE  STABLE' : 'LINK STATE  UPLINK',
      const Offset(115, 184),
      8,
      const Color(0xff8fc8df),
    );
  }

  void _memory(Canvas c, Rect r, int filled, Color accent) {
    for (var i = 0; i < 8; i++) {
      final cell = Rect.fromLTWH(
        r.left + 11 + (i % 4) * 17,
        r.top + 20 + (i ~/ 4) * 22,
        13,
        12,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(cell, const Radius.circular(1)),
        _fill(
          i < filled ? accent.withValues(alpha: .72) : const Color(0xff102b38),
        ),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(cell, const Radius.circular(1)),
        _line(accent.withValues(alpha: .7), .7),
      );
    }
  }

  void _archive(Canvas c, double t) {
    const input = Rect.fromLTWH(29, 93, 83, 90),
        chamber = Rect.fromLTWH(135, 87, 90, 105),
        output = Rect.fromLTWH(248, 93, 82, 90);
    _text(c, 'ARCHIVE INPUT', const Offset(29, 78), 8, const Color(0xffb7fff0));
    _stack(c, input, 5, _mint, false);
    _chamber(c, chamber, t);
    final tx = _phase(t, .4, 23 / 30);
    _stack(c, output, (tx * 5).floor().clamp(0, 5), _mint, true);
    final b = _phase(t, 2 / 15, .4);
    for (var i = 0; i < 5; i++) {
      final p = ((b - i * .1625) / .16).clamp(0.0, 1.0);
      if (p > 0 && p < 1) {
        _document(
          c,
          Rect.fromLTWH(35 + p * 116, 107 + i * 11, 52 - 24 * p, 18 - 8 * p),
          i,
          const Color(0xffb7fff0),
        );
      }
    }
    c.drawLine(
      const Offset(220, 123),
      const Offset(249, 112),
      _line(_mint.withValues(alpha: .45)),
    );
    c.drawLine(
      const Offset(220, 157),
      const Offset(249, 168),
      _line(_mint.withValues(alpha: .45)),
    );
    for (var i = 0; i < 5; i++) {
      final p = ((tx * 1.45) - i * .22).clamp(0.0, 1.0);
      if (p > 0 && p < 1) {
        c.drawRect(
          Rect.fromLTWH(214 + _ease(p) * 42, 132 + (i % 2) * 8, 15, 9),
          _fill(const Color(0xffd7fff7)),
        );
      }
    }
  }

  void _stack(Canvas c, Rect r, int count, Color accent, bool receiving) {
    c.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(3)),
      _fill(const Color(0xff071923)),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(3)),
      _line(accent.withValues(alpha: .55)),
    );
    for (var i = 0; i < 5; i++) {
      final y = r.bottom - 18 - i * 13;
      if (!receiving || i < count) {
        _document(c, Rect.fromLTWH(r.left + 10 + i * 2, y, 52, 18), i, accent);
      } else {
        c.drawRect(
          Rect.fromLTWH(r.left + 11, y, 54, 17),
          _line(const Color(0xff29505a), .6),
        );
      }
    }
  }

  void _document(Canvas c, Rect r, int index, Color accent) {
    c.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(1)),
      _fill(const Color(0xff103440)),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(1)),
      _line(accent.withValues(alpha: .85), .8),
    );
    for (var l = 0; l < 4; l++) {
      c.drawLine(
        Offset(r.left + 12, r.top + 4 + l * 3),
        Offset(r.right - 4, r.top + 4 + l * 3),
        _line(accent.withValues(alpha: .42), .55),
      );
    }
    _text(c, '${index + 1}', Offset(r.left + 3, r.top + 3), 6, accent);
  }

  void _chamber(Canvas c, Rect r, double t) {
    final center = r.center, path = Path();
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3,
          p = center + Offset(math.cos(a) * 43, math.sin(a) * 43);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    c.drawPath(path, _fill(const Color(0xff09242c)));
    c.drawPath(path, _line(_mint.withValues(alpha: .75), 1.2));
    final core = Rect.fromCenter(center: center, width: 55, height: 55);
    c.drawRect(core, _fill(const Color(0xff0e3540)));
    c.drawRect(core, _line(const Color(0xffb7fff0), .8));
    final b = _phase(t, 2 / 15, .4);
    for (var i = 0; i < 16; i++) {
      final on = i < (b * 16).ceil() || t >= .4;
      c.drawRect(
        Rect.fromLTWH(
          core.left + 8 + (i % 4) * 10,
          core.top + 8 + (i ~/ 4) * 10,
          6,
          6,
        ),
        _fill(on ? _mint : const Color(0xff17434c)),
      );
    }
    for (final p in [
      Offset(core.left - 7, core.top + 8),
      Offset(core.right + 2, core.top + 8),
      Offset(core.left - 7, core.bottom - 14),
      Offset(core.right + 2, core.bottom - 14),
    ]) {
      c.drawRect(
        Rect.fromLTWH(p.dx, p.dy, 5, 12),
        _fill(const Color(0xff80e7d8)),
      );
    }
  }

  void _text(Canvas c, String text, Offset at, double size, Color color) {
    final p = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'ShareTechMono',
          fontSize: size,
          color: color,
          letterSpacing: .35,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(c, at);
  }

  void _center(Canvas c, String text, Offset at, double size, Color color) {
    final p = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'ShareTechMono',
          fontSize: size,
          color: color,
          letterSpacing: .35,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(c, at - Offset(p.width / 2, p.height / 2));
  }

  void _right(Canvas c, String text, Offset at, double size, Color color) {
    final p = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'ShareTechMono',
          fontSize: size,
          color: color,
          letterSpacing: .3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(c, Offset(at.dx - p.width, at.dy));
  }

  @override
  bool shouldRepaint(covariant _SendSequencePainter old) =>
      old.concept != concept || old.mode != mode || old.progress != progress;
}
