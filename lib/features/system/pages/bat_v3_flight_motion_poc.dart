import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import 'bat_v3_source_data.dart';

enum BatV3View { raw, mask, registered, bodyOverlay }

class BatV3FlightMotionPoc extends StatefulWidget {
  const BatV3FlightMotionPoc({super.key});

  @override
  State<BatV3FlightMotionPoc> createState() => _BatV3FlightMotionPocState();
}

class _BatV3FlightMotionPocState extends State<BatV3FlightMotionPoc> {
  Timer? _timer;
  var _poseIndex = 0;
  var _cycleIndex = 0;
  var _milliseconds = 125;
  var _playing = false;
  var _flutter = true;
  var _crossing = false;
  var _leftToRight = true;
  var _inspectionScale = 1.0;
  var _view = BatV3View.raw;
  var _travel = 0.0;

  BatV3SourcePose get _pose => BatV3SourceSet.poses[_poseIndex];
  double get _flutterY =>
      _flutter ? BatV3SourceSet.flutterOffsets[_cycleIndex] : 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _select(int index) {
    _pause();
    setState(() {
      _poseIndex = index;
      _cycleIndex = BatV3SourceSet.cycle.indexOf(index);
    });
  }

  void _start() {
    if (_playing) return;
    setState(() => _playing = true);
    _run();
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    if (_playing && mounted) setState(() => _playing = false);
  }

  void _restart() {
    _timer?.cancel();
    setState(() {
      _poseIndex = 0;
      _cycleIndex = 0;
      _travel = 0;
      _playing = true;
    });
    _run();
  }

  void _run() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: _milliseconds), (_) {
      if (!mounted) return;
      setState(() {
        _cycleIndex = (_cycleIndex + 1) % BatV3SourceSet.cycle.length;
        _poseIndex = BatV3SourceSet.cycle[_cycleIndex];
        _travel = (_travel + .035) % 1;
      });
    });
  }

  void _timing(int value) {
    final resume = _playing;
    _timer?.cancel();
    setState(() => _milliseconds = value);
    if (resume) _run();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader(
        icon: Icons.document_scanner_outlined,
        title: 'BAT V3 — NEW 5-POSE SOURCE SET',
      ),
      AppSpacing.gapSM,
      OperationCard(
        key: const ValueKey('bat-v3-source-audit'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'FRAME ${_pose.index.toString().padLeft(2, '0')} · ${_pose.name}',
              key: const ValueKey('bat-v3-pose-label'),
            ),
            Text(_pose.asset, style: Theme.of(context).textTheme.bodySmall),
            AppSpacing.gapSM,
            _BatV3Image(
              pose: _pose,
              view: _view,
              leftToRight: _leftToRight,
              inspectionScale: _inspectionScale,
              flutterY: 0,
            ),
            AppSpacing.gapSM,
            _frames('bat-v3-source-frame'),
            AppSpacing.gapSM,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final view in BatV3View.values)
                  _choice(
                    'bat-v3-view-${view.name}',
                    switch (view) {
                      BatV3View.raw => 'RAW',
                      BatV3View.mask => 'MASK',
                      BatV3View.registered => 'REGISTERED',
                      BatV3View.bodyOverlay => 'BODY OVERLAY',
                    },
                    _view == view,
                    () => setState(() => _view = view),
                  ),
              ],
            ),
            AppSpacing.gapSM,
            Text(
              'REGISTRATION · SCALE ${_pose.scale.toStringAsFixed(2)} · dx ${_pose.translation.dx.toStringAsFixed(0)} · dy ${_pose.translation.dy.toStringAsFixed(0)}',
              key: const ValueKey('bat-v3-registration'),
            ),
            Text(
              'BODY ${_pose.body.width.toStringAsFixed(0)}×${_pose.body.height.toStringAsFixed(0)} · SOURCE ANCHOR ${BatV3SourceSet.registeredAnchorFor(_pose).dx.toStringAsFixed(0)}, ${BatV3SourceSet.registeredAnchorFor(_pose).dy.toStringAsFixed(0)}',
              key: const ValueKey('bat-v3-body-metrics'),
            ),
            const Text(
              'CANONICAL CANVAS 1122×1264 · BODY LOCK 349, 652 · SAFETY 64',
              key: ValueKey('bat-v3-canonical-metrics'),
            ),
          ],
        ),
      ),
      AppSpacing.gapLG,
      const SectionHeader(
        icon: Icons.motion_photos_on_outlined,
        title: 'BAT V3 BODY-REGISTERED FLAP CYCLE',
      ),
      AppSpacing.gapSM,
      OperationCard(
        key: const ValueKey('bat-v3-flap-poc'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _playing
                  ? 'PLAYING · $_milliseconds ms / POSE'
                  : 'PAUSED · $_milliseconds ms / POSE',
              key: const ValueKey('bat-v3-state'),
            ),
            if (_crossing) ...[
              const Text('48PX FLIGHT PREVIEW'),
              _BatV3Crossing(
                pose: _pose,
                leftToRight: _leftToRight,
                progress: _travel,
                flutterY: _flutterY,
                inspectionScale: _inspectionScale,
              ),
            ] else
              _BatV3Image(
                pose: _pose,
                view: BatV3View.registered,
                leftToRight: _leftToRight,
                inspectionScale: _inspectionScale,
                flutterY: _flutterY,
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _choice('bat-v3-play', 'PLAY', _playing, _start),
                _choice('bat-v3-pause', 'PAUSE', !_playing, _pause),
                _choice('bat-v3-restart', 'RESTART', false, _restart),
              ],
            ),
            AppSpacing.gapSM,
            _frames('bat-v3-frame'),
            AppSpacing.gapSM,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _choice(
                  'bat-v3-in-place',
                  'IN-PLACE',
                  !_crossing,
                  () => setState(() => _crossing = false),
                ),
                _choice(
                  'bat-v3-crossing',
                  'FLIGHT / CROSSING',
                  _crossing,
                  () => setState(() => _crossing = true),
                ),
                _choice(
                  'bat-v3-flutter-on',
                  'FLUTTER ON',
                  _flutter,
                  () => setState(() => _flutter = true),
                ),
                _choice(
                  'bat-v3-flutter-off',
                  'FLUTTER OFF',
                  !_flutter,
                  () => setState(() => _flutter = false),
                ),
              ],
            ),
            AppSpacing.gapSM,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in [100, 125, 150])
                  _choice(
                    'bat-v3-timing-$value',
                    value == 100
                        ? 'FAST 100 · 800ms'
                        : value == 125
                        ? 'NORMAL 125 · 1000ms'
                        : 'SLOW 150 · 1200ms',
                    _milliseconds == value,
                    () => _timing(value),
                  ),
              ],
            ),
            AppSpacing.gapSM,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _choice(
                  'bat-v3-ltr',
                  'L→R',
                  _leftToRight,
                  () => setState(() => _leftToRight = true),
                ),
                _choice(
                  'bat-v3-rtl',
                  'R→L',
                  !_leftToRight,
                  () => setState(() => _leftToRight = false),
                ),
                for (final value in [1.0, .5, .25])
                  _choice(
                    'bat-v3-scale-${value.toStringAsFixed(2)}',
                    '${value.toStringAsFixed(2)}×',
                    _inspectionScale == value,
                    () => setState(() => _inspectionScale = value),
                  ),
              ],
            ),
            AppSpacing.gapSM,
            const Text(
              '01 NEUTRAL → 02 TOP INTERMEDIATE → 03 TOP → 02 → 01 → 04 BOTTOM INTERMEDIATE → 05 BOTTOM → 04. SOURCE poses are immutable; registration and flutter are whole-pose presentation transforms only.',
            ),
          ],
        ),
      ),
    ],
  );

  Widget _frames(String prefix) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (var i = 0; i < 5; i++)
        _choice(
          '$prefix-${i + 1}',
          'FRAME ${(i + 1).toString().padLeft(2, '0')}',
          _poseIndex == i,
          () => _select(i),
        ),
    ],
  );
  Widget _choice(
    String key,
    String label,
    bool selected,
    VoidCallback action,
  ) => OutlinedButton(
    key: ValueKey(key),
    style: selected
        ? OutlinedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          )
        : null,
    onPressed: action,
    child: Text(label),
  );
}

class _BatV3Image extends StatelessWidget {
  const _BatV3Image({
    required this.pose,
    required this.view,
    required this.leftToRight,
    required this.inspectionScale,
    required this.flutterY,
  });
  final BatV3SourcePose pose;
  final BatV3View view;
  final bool leftToRight;
  final double inspectionScale;
  final double flutterY;
  @override
  Widget build(BuildContext context) {
    final isRaw = view == BatV3View.raw;
    if (isRaw) {
      return SizedBox(
        height: 180,
        child: Image.asset(pose.asset, fit: BoxFit.contain),
      );
    }
    return _BatV3CanonicalFrame(
      key: ValueKey('bat-v3-image-${inspectionScale.toStringAsFixed(2)}'),
      pose: pose,
      leftToRight: leftToRight,
      inspectionScale: inspectionScale,
      flutterY: flutterY,
      bodyOverlay: view == BatV3View.bodyOverlay,
      viewportHeight: 260,
    );
  }
}

class _BatV3SourceImage extends StatelessWidget {
  const _BatV3SourceImage({required this.asset, required this.mask});

  final String asset;
  final bool mask;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(asset, fit: BoxFit.contain);
    if (!mask) return image;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        -.333,
        -.333,
        -.333,
        0,
        255,
      ]),
      child: image,
    );
  }
}

class _BatV3BodyOverlayPainter extends CustomPainter {
  const _BatV3BodyOverlayPainter({required this.pose});

  final BatV3SourcePose pose;

  @override
  void paint(Canvas canvas, Size size) {
    final anchor = BatV3SourceSet.canonicalBodyAnchor;
    final bodySize = BatV3SourceSet.registeredBodySizeFor(pose);
    final body = Rect.fromCenter(
      center: anchor,
      width: bodySize.width,
      height: bodySize.height,
    );
    final paint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(body, paint);
    canvas.drawLine(
      Offset(anchor.dx - 8, anchor.dy),
      Offset(anchor.dx + 8, anchor.dy),
      paint,
    );
    canvas.drawLine(
      Offset(anchor.dx, anchor.dy - 8),
      Offset(anchor.dx, anchor.dy + 8),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BatV3BodyOverlayPainter oldDelegate) =>
      oldDelegate.pose != pose;
}

class _BatV3CanonicalFrame extends StatelessWidget {
  const _BatV3CanonicalFrame({
    super.key,
    required this.pose,
    required this.leftToRight,
    required this.inspectionScale,
    required this.flutterY,
    required this.bodyOverlay,
    required this.viewportHeight,
  });

  final BatV3SourcePose pose;
  final bool leftToRight;
  final double inspectionScale;
  final double flutterY;
  final bool bodyOverlay;
  final double viewportHeight;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: viewportHeight,
    child: FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: BatV3SourceSet.canonicalCanvas.width,
        height: BatV3SourceSet.canonicalCanvas.height,
        child: ClipRect(
          child: Transform.flip(
            flipX: !leftToRight,
            child: Transform.translate(
              offset: Offset(
                0,
                flutterY /
                    viewportHeight *
                    BatV3SourceSet.canonicalCanvas.height,
              ),
              child: Transform.scale(
                scale: inspectionScale,
                alignment: Alignment.center,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _BatV3RegisteredSource(pose: pose),
                    if (bodyOverlay)
                      CustomPaint(
                        painter: _BatV3BodyOverlayPainter(pose: pose),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _BatV3RegisteredSource extends StatelessWidget {
  const _BatV3RegisteredSource({required this.pose});

  final BatV3SourcePose pose;

  @override
  Widget build(BuildContext context) => Image.asset(
    pose.canonicalAsset,
    width: BatV3SourceSet.canonicalCanvas.width,
    height: BatV3SourceSet.canonicalCanvas.height,
    fit: BoxFit.fill,
  );
}

class _BatV3Crossing extends StatelessWidget {
  const _BatV3Crossing({
    required this.pose,
    required this.leftToRight,
    required this.progress,
    required this.flutterY,
    required this.inspectionScale,
  });

  final BatV3SourcePose pose;
  final bool leftToRight;
  final double progress;
  final double flutterY;
  final double inspectionScale;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('bat-v3-crossing-stage'),
    height: 48,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final frameWidth =
            48 *
            BatV3SourceSet.canonicalCanvas.width /
            BatV3SourceSet.canonicalCanvas.height;
        final x = -frameWidth + (constraints.maxWidth + frameWidth) * progress;
        return ClipRect(
          child: Transform.translate(
            offset: Offset(
              leftToRight ? x : constraints.maxWidth - x - frameWidth,
              flutterY,
            ),
            child: SizedBox(
              width: frameWidth,
              child: _BatV3CanonicalFrame(
                pose: pose,
                leftToRight: leftToRight,
                inspectionScale: inspectionScale,
                flutterY: 0,
                bodyOverlay: false,
                viewportHeight: 48,
              ),
            ),
          ),
        );
      },
    ),
  );
}
