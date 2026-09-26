import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import 'cat_run_v2_registration.dart';
import 'cat_run_v2_trace_data.dart';

/// Sandbox-only direct HIGH-vector frame playback; it intentionally morphs nothing.
class CatRunV2PocSection extends StatefulWidget {
  const CatRunV2PocSection({super.key});
  @override
  State<CatRunV2PocSection> createState() => _CatRunV2PocSectionState();
}

class _CatRunV2PocSectionState extends State<CatRunV2PocSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _playing = false;
  var _speed = 1.0;
  var _scale = 1;
  var _expanded = false;
  int? _manualFrame;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: CatRunV2Registration.cycleDuration,
        )..addListener(() {
          if (mounted && _playing) {
            setState(() {});
          }
        });
  }

  int get _frame =>
      _manualFrame ??
      CatRunV2Registration.frameAtCycleProgress(_controller.value);
  void _playPause() {
    setState(() {
      _manualFrame = null;
      _playing = !_playing;
      _playing ? _controller.repeat() : _controller.stop();
    });
  }

  void _setSpeed(double value) {
    setState(() {
      _speed = value;
      _controller.duration = Duration(
        microseconds:
            (CatRunV2Registration.cycleDuration.inMicroseconds / value).round(),
      );
      if (_playing) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trace = catRunV2HighTraces[_frame];
    final registeredPoints = CatRunV2Registration.registeredPoints(trace);
    final frameDuration = CatRunV2Registration.frameDurations[_frame];
    final registration = CatRunV2Registration.registrationFor(trace.pose);
    final transform = CatRunV2Registration.transformFor(trace);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OperationCard(
          key: const ValueKey('cat-run-v2-audit-disclosure'),
          child: InkWell(
            key: const ValueKey('cat-run-v2-toggle'),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.directions_run),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CAT RUN V2 — SEQUENTIAL HIGH VECTOR'),
                        Text('SOURCE / FRAME AUDIT'),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    semanticLabel: _expanded
                        ? 'Collapse source and frame audit'
                        : 'Expand source and frame audit',
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          AppSpacing.gapSM,
          OperationCard(
            key: const ValueKey('cat-run-v2-poc'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 190,
                  child: CustomPaint(
                    key: const ValueKey('cat-run-v2-canvas'),
                    painter: _CatRunV2Painter(registeredPoints, _scale),
                  ),
                ),
                AppSpacing.gapSM,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < 10; i++)
                      OutlinedButton(
                        key: ValueKey('cat-run-v2-frame-${i + 1}'),
                        onPressed: () => setState(() {
                          _playing = false;
                          _controller.stop();
                          _manualFrame = i;
                        }),
                        child: Text(
                          'FRAME ${(i + 1).toString().padLeft(2, '0')}',
                        ),
                      ),
                  ],
                ),
                AppSpacing.gapSM,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      key: const ValueKey('cat-run-v2-play'),
                      onPressed: _playPause,
                      child: Text(_playing ? 'PAUSE' : 'PLAY'),
                    ),
                    for (final speed in [0.5, 1.0])
                      OutlinedButton(
                        key: ValueKey('cat-run-v2-speed-$speed'),
                        onPressed: () => _setSpeed(speed),
                        child: Text('$speed×'),
                      ),
                    for (final scale in [1, 2, 4])
                      OutlinedButton(
                        key: ValueKey('cat-run-v2-scale-$scale'),
                        onPressed: () => setState(() => _scale = scale),
                        child: Text('$scale×'),
                      ),
                  ],
                ),
                AppSpacing.gapSM,
                Text(
                  'HIGH FRAME ${trace.pose.toString().padLeft(2, '0')} · '
                  '${trace.pointCount} points · '
                  'IoU ${(trace.iou * 100).toStringAsFixed(2)}% · '
                  '${(frameDuration.inMilliseconds / _speed).round()}ms hold at $_speed×',
                ),
                Text(
                  '${registration.state.label} · uniform '
                  '${transform.uniformScale.toStringAsFixed(3)} · '
                  '${(transform.rotationRadians * 180 / math.pi).toStringAsFixed(1)}°',
                ),
                const Text(
                  'V2.2: SHOULDER / PELVIS / VIRTUAL GROUND · '
                  'NO MORPH / RESAMPLING / ARTICULATION',
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CatRunV2Painter extends CustomPainter {
  const _CatRunV2Painter(this.points, this.scale);
  final List<Offset> points;
  final int scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF101010),
    );
    final path = Path()..addPolygon(points, true);
    final unit = math.min(size.width * .88, size.height * .72) * scale;
    canvas.save();
    canvas.translate((size.width - unit) / 2, (size.height - unit * .48) / 2);
    canvas.scale(unit);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFB8B8B8)
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CatRunV2Painter old) =>
      old.points != points || old.scale != scale;
}
