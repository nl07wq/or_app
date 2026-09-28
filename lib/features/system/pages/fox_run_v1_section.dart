import 'package:flutter/material.dart';
import 'fox_pattern_preview.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

/// Sandbox-only FOX V1 audit and canonical-preview surface.  The source PNGs
/// are inspection-only; motion always reads the pre-baked canonical cels.
class FoxRunV1Section extends StatefulWidget {
  const FoxRunV1Section({super.key});

  @override
  State<FoxRunV1Section> createState() => _FoxRunV1SectionState();
}

enum _FoxAuditMode { source, canonical, overlay }

enum FoxRunV1Speed { slow, current, fast, faster, fastest, maximum, over }

enum FoxRunV1BodySize { half, sevenTenths, full }

enum FoxRunV1VerticalFlutter { off, half, one, two }

enum FoxRunV1BodyFlex { off, half, one, two, four }

enum FoxRunV1BodyFlexMotion { current, smooth, hold }

enum FoxRunV1BodyShrink { off, on }

enum FoxRunV1Pattern { off, fox }

class _FoxRunV1SectionState extends State<FoxRunV1Section>
    with TickerProviderStateMixin {
  static const _canvasSize = Size(1646, 783);
  static const _origin = Offset(897.4332949552927, 366.7165635675376);
  static const _ground = 687.0;
  static const _torso = 516.0;
  static const _frameCount = FoxRunV1Motion.frameCount;

  var _expanded = false;
  var _frame = 0;
  var _auditMode = _FoxAuditMode.canonical;
  var _inspectionScale = 0.5;
  var _leftToRight = true;
  var _speed = FoxRunV1Speed.fastest;
  var _bodySize = FoxRunV1BodySize.full;
  var _verticalFlutter = FoxRunV1VerticalFlutter.one;
  var _bodyFlex = FoxRunV1BodyFlex.two;
  var _bodyFlexMotion = FoxRunV1BodyFlexMotion.smooth;
  var _bodyShrink = FoxRunV1BodyShrink.off;
  var _pattern = FoxRunV1Pattern.off;
  var _flutterPhase = 0;
  var _frameElapsedOffset = Duration.zero;
  final _selectedFrames = <int>{0, 2, 4, 5, 6};
  Duration get _crossingDuration => FoxRunV1Motion.durationForSpeed(_speed);
  double get _bodyScale => FoxRunV1ProductionGeometry.scaleFor(_bodySize);
  double get _verticalFlutterOffset => _crossing.isAnimating
      ? FoxRunV1Motion.verticalFlutterOffset(
          phase: _flutterPhase,
          amplitude: FoxRunV1Motion.flutterAmplitude(_verticalFlutter),
        )
      : 0;
  double get _bodyFlexOffset => _crossing.isAnimating
      ? FoxRunV1Motion.bodyFlexOffsetAtElapsed(
          elapsed:
              _frameElapsedOffset +
              (_crossing.lastElapsedDuration ?? Duration.zero),
          amplitude: FoxRunV1Motion.bodyFlexAmplitude(_bodyFlex),
          shrinkEnabled: _bodyShrink == FoxRunV1BodyShrink.on,
          motion: _bodyFlexMotion,
        )
      : 0;
  List<int> get _orderedSelectedFrames => _selectedFrames.toList()..sort();
  late final AnimationController _crossing = AnimationController(
    vsync: this,
    duration: _crossingDuration,
  )..addListener(_syncFrameToCrossing);

  @override
  void dispose() {
    _crossing.dispose();
    super.dispose();
  }

  String _asset({required bool source}) =>
      'assets/animations/sandbox/fox_v1/${source ? 'source' : 'canonical'}/'
      'frame_${(_frame + 1).toString().padLeft(2, '0')}.png';

  void _setPlayback(bool playing) {
    if (!playing) {
      _crossing.stop();
      setState(() => _flutterPhase = 0);
      return;
    }
    _crossing.repeat();
    _syncFrameToCrossing();
  }

  void _syncFrameToCrossing() {
    if (!mounted || !_crossing.isAnimating) return;
    final elapsed =
        _frameElapsedOffset + (_crossing.lastElapsedDuration ?? Duration.zero);
    final nextFrame = FoxRunV1Motion.frameAtElapsed(
      elapsed,
      selectedFrames: _orderedSelectedFrames,
    );
    final nextFlutterPhase = FoxRunV1Motion.flutterPhaseAtElapsed(elapsed);
    if (nextFrame != _frame || nextFlutterPhase != _flutterPhase) {
      setState(() {
        _frame = nextFrame;
        _flutterPhase = nextFlutterPhase;
      });
    }
  }

  void _restart() {
    setState(() {
      _frame = _orderedSelectedFrames.first;
      _frameElapsedOffset = Duration.zero;
      _flutterPhase = 0;
    });
    _crossing
      ..stop()
      ..value = 0;
    _setPlayback(true);
  }

  void _setSpeed(FoxRunV1Speed speed) {
    if (_speed == speed) return;
    final wasAnimating = _crossing.isAnimating;
    final progress = _crossing.value;
    if (wasAnimating) {
      _frameElapsedOffset += _crossing.lastElapsedDuration ?? Duration.zero;
      _crossing.stop();
    }
    setState(() => _speed = speed);
    _crossing.duration = _crossingDuration;
    _crossing.value = progress;
    if (wasAnimating) {
      _crossing.repeat(period: _crossingDuration);
      _syncFrameToCrossing();
    }
  }

  void _toggleFrame(int frame) {
    if (_selectedFrames.contains(frame) && _selectedFrames.length == 1) return;
    setState(() {
      if (!_selectedFrames.remove(frame)) _selectedFrames.add(frame);
      if (!_selectedFrames.contains(_frame)) {
        _frame = _orderedSelectedFrames.first;
      }
    });
    _syncFrameToCrossing();
  }

  void _setBodySize(FoxRunV1BodySize bodySize) {
    if (_bodySize == bodySize) return;
    setState(() => _bodySize = bodySize);
  }

  void _setVerticalFlutter(FoxRunV1VerticalFlutter verticalFlutter) {
    if (_verticalFlutter == verticalFlutter) return;
    setState(() => _verticalFlutter = verticalFlutter);
  }

  void _setBodyFlex(FoxRunV1BodyFlex bodyFlex) {
    if (_bodyFlex == bodyFlex) return;
    setState(() => _bodyFlex = bodyFlex);
  }

  void _setBodyFlexMotion(FoxRunV1BodyFlexMotion motion) {
    if (_bodyFlexMotion == motion) return;
    setState(() => _bodyFlexMotion = motion);
  }

  void _setBodyShrink(FoxRunV1BodyShrink bodyShrink) {
    if (_bodyShrink == bodyShrink) return;
    setState(() => _bodyShrink = bodyShrink);
  }

  void _setPattern(FoxRunV1Pattern pattern) {
    if (_pattern == pattern) return;
    setState(() => _pattern = pattern);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OperationCard(
        child: InkWell(
          key: const ValueKey('fox-run-v1-disclosure'),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.pets_outlined),
                const SizedBox(width: 12),
                const Expanded(child: Text('FOX RUN V1 — 10-FRAME SOURCE SET')),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
      ),
      if (_expanded) ...[
        AppSpacing.gapSM,
        OperationCard(child: _buildAudit(context)),
      ],
      AppSpacing.gapXL,
      const SectionHeader(
        icon: Icons.directions_run,
        title: 'FOX RUN — PRODUCTION PREVIEW',
      ),
      AppSpacing.gapSM,
      OperationCard(child: _buildPreview(context)),
    ],
  );

  Widget _buildAudit(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: List.generate(
          _frameCount,
          (index) => ChoiceChip(
            key: ValueKey('fox-audit-frame-${index + 1}'),
            label: Text('FRAME ${(index + 1).toString().padLeft(2, '0')}'),
            selected: _frame == index,
            onSelected: (_) => setState(() => _frame = index),
          ),
        ),
      ),
      AppSpacing.gapSM,
      Wrap(
        spacing: AppSpacing.xs,
        children: _FoxAuditMode.values
            .map(
              (mode) => ChoiceChip(
                label: Text(
                  mode == _FoxAuditMode.source
                      ? 'SOURCE'
                      : mode == _FoxAuditMode.canonical
                      ? 'CANONICAL'
                      : 'BODY OVERLAY',
                ),
                selected: _auditMode == mode,
                onSelected: (_) => setState(() => _auditMode = mode),
              ),
            )
            .toList(),
      ),
      AppSpacing.gapSM,
      Wrap(
        spacing: AppSpacing.xs,
        children: [1.0, .5, .25]
            .map(
              (scale) => ChoiceChip(
                label: Text('${scale.toStringAsFixed(2)}×'),
                selected: _inspectionScale == scale,
                onSelected: (_) => setState(() => _inspectionScale = scale),
              ),
            )
            .toList(),
      ),
      AppSpacing.gapSM,
      Center(
        child: SizedBox(
          width: _canvasSize.width * _inspectionScale,
          height: _canvasSize.height * _inspectionScale,
          child: _FoxCel(
            asset: _asset(source: _auditMode == _FoxAuditMode.source),
            mirror: false,
            overlay: _auditMode == _FoxAuditMode.overlay,
            source: _auditMode == _FoxAuditMode.source,
          ),
        ),
      ),
      AppSpacing.gapSM,
      Text(
        'FRAME ${(_frame + 1).toString().padLeft(2, '0')}  •  ${_auditMode.name.toUpperCase()}  •  canvas 1646×783',
      ),
      Text(
        'origin ${_origin.dx.toStringAsFixed(2)}, ${_origin.dy.toStringAsFixed(2)}  •  torso ${_torso.toStringAsFixed(0)}px  •  ground y=${_ground.toStringAsFixed(0)}${_frame == 9 ? '  •  source correction 0.7633' : ''}',
      ),
    ],
  );

  Widget _buildPreview(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FoxRunV1ProductionStage(
        crossing: _crossing,
        asset: _asset(source: false),
        leftToRight: _leftToRight,
        bodyScale: _bodyScale,
        verticalFlutterOffset: _verticalFlutterOffset,
        bodyFlexOffsetProvider: () => _bodyFlexOffset,
        pattern: _pattern,
      ),
      AppSpacing.gapSM,
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          _button('PLAY / RESTART', _restart, 'fox-preview-play'),
          _button('PAUSE', () => _setPlayback(false), 'fox-preview-pause'),
          _button(
            _leftToRight ? 'L→R' : 'R→L',
            () => setState(() => _leftToRight = !_leftToRight),
            'fox-preview-direction',
          ),
        ],
      ),
      AppSpacing.gapSM,
      const Text('SPEED'),
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: FoxRunV1Speed.values
            .map(
              (speed) => ChoiceChip(
                key: ValueKey('fox-preview-speed-${speed.name}'),
                label: Text(speed.name.toUpperCase()),
                selected: _speed == speed,
                onSelected: (_) => _setSpeed(speed),
              ),
            )
            .toList(),
      ),
      AppSpacing.gapSM,
      const Text('BODY SIZE'),
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: FoxRunV1BodySize.values
            .map(
              (bodySize) => ChoiceChip(
                key: ValueKey('fox-preview-body-size-${bodySize.name}'),
                label: Text(switch (bodySize) {
                  FoxRunV1BodySize.half => '0.5×',
                  FoxRunV1BodySize.sevenTenths => '0.7×',
                  FoxRunV1BodySize.full => '1×',
                }),
                selected: _bodySize == bodySize,
                onSelected: (_) => _setBodySize(bodySize),
              ),
            )
            .toList(),
      ),
      AppSpacing.gapSM,
      const Text('VERTICAL FLUTTER'),
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: FoxRunV1VerticalFlutter.values
            .map(
              (verticalFlutter) => ChoiceChip(
                key: ValueKey(
                  'fox-preview-vertical-flutter-${verticalFlutter.name}',
                ),
                label: Text(FoxRunV1Motion.flutterLabel(verticalFlutter)),
                selected: _verticalFlutter == verticalFlutter,
                onSelected: (_) => _setVerticalFlutter(verticalFlutter),
              ),
            )
            .toList(),
      ),
      AppSpacing.gapSM,
      const Text('BODY FLEX'),
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: FoxRunV1BodyFlex.values
            .map(
              (bodyFlex) => ChoiceChip(
                key: ValueKey('fox-preview-body-flex-${bodyFlex.name}'),
                label: Text(FoxRunV1Motion.bodyFlexLabel(bodyFlex)),
                selected: _bodyFlex == bodyFlex,
                onSelected: (_) => _setBodyFlex(bodyFlex),
              ),
            )
            .toList(),
      ),
      AppSpacing.gapSM,
      const Text('BODY FLEX MOTION'),
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: FoxRunV1BodyFlexMotion.values
            .map(
              (motion) => ChoiceChip(
                key: ValueKey('fox-preview-body-flex-motion-${motion.name}'),
                label: Text(motion.name.toUpperCase()),
                selected: _bodyFlexMotion == motion,
                onSelected: (_) => _setBodyFlexMotion(motion),
              ),
            )
            .toList(),
      ),
      AppSpacing.gapSM,
      const Text('BODY SHRINK'),
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: FoxRunV1BodyShrink.values
            .map(
              (bodyShrink) => ChoiceChip(
                key: ValueKey('fox-preview-body-shrink-${bodyShrink.name}'),
                label: Text(bodyShrink.name.toUpperCase()),
                selected: _bodyShrink == bodyShrink,
                onSelected: (_) => _setBodyShrink(bodyShrink),
              ),
            )
            .toList(),
      ),
      AppSpacing.gapSM,
      const Text('FOX PATTERN'),
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: FoxRunV1Pattern.values
            .map(
              (pattern) => ChoiceChip(
                key: ValueKey('fox-preview-pattern-${pattern.name}'),
                label: Text(pattern.name.toUpperCase()),
                selected: _pattern == pattern,
                onSelected: (_) => _setPattern(pattern),
              ),
            )
            .toList(),
      ),
      AppSpacing.gapSM,
      const Text('FRAMES'),
      Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 288),
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: List.generate(
              _frameCount,
              (frame) => SizedBox(
                width: 51.2,
                child: FilterChip(
                  key: ValueKey('fox-preview-frame-${frame + 1}'),
                  label: Text((frame + 1).toString().padLeft(2, '0')),
                  selected: _selectedFrames.contains(frame),
                  onSelected: (_) => _toggleFrame(frame),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
        ),
      ),
      AppSpacing.gapSM,
      Text(
        '${_speed.name.toUpperCase()}: canonical FOX • ${FoxRunV1Motion.frameDuration.inMilliseconds}ms/frame • ${_crossingDuration.inMilliseconds}ms crossing • display body ${FoxRunV1ProductionGeometry.displayedTorsoLengthFor(_bodyScale).toStringAsFixed(0)}px • flutter ${FoxRunV1Motion.flutterLabel(_verticalFlutter)} • flex ${FoxRunV1Motion.bodyFlexLabel(_bodyFlex)} • flex motion ${_bodyFlexMotion.name.toUpperCase()} • shrink ${_bodyShrink.name.toUpperCase()} • pattern ${_pattern.name.toUpperCase()}',
      ),
    ],
  );

  Widget _button(String label, VoidCallback onPressed, String key) =>
      OutlinedButton(
        key: ValueKey(key),
        onPressed: onPressed,
        child: Text(label),
      );
}

/// Couples the canonical 01→10 gait cycle to crossing progress so translation
/// and cel playback share one timeline and restart on the same phase.
abstract final class FoxRunV1Motion {
  static const frameCount = 10;
  static const orderedFrames = <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
  static const frameDuration = Duration(milliseconds: 80);
  static const cycleDuration = Duration(milliseconds: frameCount * 80);
  static const crossingDuration = Duration(milliseconds: 2200);
  static const slowCrossingDuration = Duration(milliseconds: 3200);
  static const fastCrossingDuration = Duration(milliseconds: 2000);
  static const fasterCrossingDuration = Duration(milliseconds: 1800);
  static const fastestCrossingDuration = Duration(milliseconds: 1600);
  static const maximumCrossingDuration = Duration(milliseconds: 1400);
  static const overCrossingDuration = Duration(milliseconds: 1200);
  static const flutterPhaseCount = 8;
  static const bodyFlexPeakHoldDuration = Duration(milliseconds: 40);
  static const _bodyFlexHoldFractionPerSide = .25;
  static const _flutterWave = <double>[0, -.5, -1, -.5, 0, .5, 1, .5];
  static const _bodyFlexWave = <double>[0, .5, 1, .5, 0, 0, 0, 0];
  static const _bodyFlexShrinkWave = <double>[0, .5, 1, .5, 0, -.5, -1, -.5];

  static Duration durationForSpeed(FoxRunV1Speed speed) => switch (speed) {
    FoxRunV1Speed.slow => slowCrossingDuration,
    FoxRunV1Speed.current => crossingDuration,
    FoxRunV1Speed.fast => fastCrossingDuration,
    FoxRunV1Speed.faster => fasterCrossingDuration,
    FoxRunV1Speed.fastest => fastestCrossingDuration,
    FoxRunV1Speed.maximum => maximumCrossingDuration,
    FoxRunV1Speed.over => overCrossingDuration,
  };

  static Duration durationForCycles(int cycles, {Duration? celDuration}) =>
      Duration(
        microseconds:
            (celDuration ?? frameDuration).inMicroseconds * frameCount * cycles,
      );

  static double flutterAmplitude(FoxRunV1VerticalFlutter verticalFlutter) =>
      switch (verticalFlutter) {
        FoxRunV1VerticalFlutter.off => 0,
        FoxRunV1VerticalFlutter.half => .5,
        FoxRunV1VerticalFlutter.one => 1,
        FoxRunV1VerticalFlutter.two => 2,
      };

  static String flutterLabel(FoxRunV1VerticalFlutter verticalFlutter) =>
      switch (verticalFlutter) {
        FoxRunV1VerticalFlutter.off => 'OFF',
        FoxRunV1VerticalFlutter.half => '0.5px',
        FoxRunV1VerticalFlutter.one => '1px',
        FoxRunV1VerticalFlutter.two => '2px',
      };

  static int flutterPhaseAtElapsed(Duration elapsed) =>
      (elapsed.inMicroseconds ~/ frameDuration.inMicroseconds) %
      flutterPhaseCount;

  static double verticalFlutterOffset({
    required int phase,
    required double amplitude,
  }) => _flutterWave[phase % flutterPhaseCount] * amplitude;

  static double bodyFlexAmplitude(FoxRunV1BodyFlex bodyFlex) =>
      switch (bodyFlex) {
        FoxRunV1BodyFlex.off => 0,
        FoxRunV1BodyFlex.half => .5,
        FoxRunV1BodyFlex.one => 1,
        FoxRunV1BodyFlex.two => 2,
        FoxRunV1BodyFlex.four => 4,
      };

  static String bodyFlexLabel(FoxRunV1BodyFlex bodyFlex) => switch (bodyFlex) {
    FoxRunV1BodyFlex.off => 'OFF',
    FoxRunV1BodyFlex.half => '0.5px',
    FoxRunV1BodyFlex.one => '1px',
    FoxRunV1BodyFlex.two => '2px',
    FoxRunV1BodyFlex.four => '4px',
  };

  static double bodyFlexOffset({
    required int phase,
    required double amplitude,
    bool shrinkEnabled = false,
  }) =>
      (shrinkEnabled ? _bodyFlexShrinkWave : _bodyFlexWave)[phase %
          flutterPhaseCount] *
      amplitude;

  static double bodyFlexOffsetAtElapsed({
    required Duration elapsed,
    required double amplitude,
    required FoxRunV1BodyFlexMotion motion,
    bool shrinkEnabled = false,
  }) {
    if (amplitude == 0) return 0;
    final phasePosition = elapsed.inMicroseconds / frameDuration.inMicroseconds;
    final phase = phasePosition.floor() % flutterPhaseCount;
    if (motion == FoxRunV1BodyFlexMotion.current) {
      return bodyFlexOffset(
        phase: phase,
        amplitude: amplitude,
        shrinkEnabled: shrinkEnabled,
      );
    }

    final wave = shrinkEnabled ? _bodyFlexShrinkWave : _bodyFlexWave;
    final start = wave[phase];
    final end = wave[(phase + 1) % flutterPhaseCount];
    final fraction = phasePosition - phasePosition.floor();
    if (motion == FoxRunV1BodyFlexMotion.hold) {
      if (end.abs() == 1) {
        if (fraction >= 1 - _bodyFlexHoldFractionPerSide) {
          return end * amplitude;
        }
        return _interpolate(
              start,
              end,
              fraction / (1 - _bodyFlexHoldFractionPerSide),
            ) *
            amplitude;
      }
      if (start.abs() == 1) {
        if (fraction <= _bodyFlexHoldFractionPerSide) {
          return start * amplitude;
        }
        return _interpolate(
              start,
              end,
              (fraction - _bodyFlexHoldFractionPerSide) /
                  (1 - _bodyFlexHoldFractionPerSide),
            ) *
            amplitude;
      }
    }
    return _interpolate(start, end, fraction) * amplitude;
  }

  static double _interpolate(double start, double end, double fraction) {
    final smoothFraction = fraction * fraction * (3 - 2 * fraction);
    return start + (end - start) * smoothFraction;
  }

  static int frameAtCrossingProgress(
    double progress, {
    Duration? celDuration,
    Duration? runDuration,
    List<int> selectedFrames = orderedFrames,
  }) {
    assert(selectedFrames.isNotEmpty);
    final resolvedCelDuration = celDuration ?? frameDuration;
    final resolvedRunDuration = runDuration ?? crossingDuration;
    final safeProgress = progress.clamp(0.0, 0.999999).toDouble();
    final elapsedMicroseconds =
        (resolvedRunDuration.inMicroseconds * safeProgress).round();
    final selectedIndex =
        (elapsedMicroseconds ~/ resolvedCelDuration.inMicroseconds) %
        selectedFrames.length;
    return selectedFrames[selectedIndex];
  }

  static int frameAtElapsed(
    Duration elapsed, {
    List<int> selectedFrames = orderedFrames,
  }) {
    assert(selectedFrames.isNotEmpty);
    final selectedIndex =
        (elapsed.inMicroseconds ~/ frameDuration.inMicroseconds) %
        selectedFrames.length;
    return selectedFrames[selectedIndex];
  }
}

class _FoxCel extends StatelessWidget {
  const _FoxCel({
    required this.asset,
    required this.mirror,
    this.overlay = false,
    this.source = false,
  });
  final String asset;
  final bool mirror;
  final bool overlay;
  final bool source;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (source) const ColoredBox(color: Colors.white),
      Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(mirror ? -1 : 1, 1, 1),
        child: source
            ? Image.asset(asset, fit: BoxFit.contain)
            : ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.grey.shade300,
                  BlendMode.srcIn,
                ),
                child: Image.asset(asset, fit: BoxFit.contain),
              ),
      ),
      if (overlay)
        const IgnorePointer(
          child: CustomPaint(painter: _FoxBodyOverlayPainter()),
        ),
    ],
  );
}

/// Shared, frame-independent mapping from the canonical FOX coordinate system
/// to the Production Preview stage.  The canvas is deliberately transparent
/// around the animal, so its edges are never a registration authority.
abstract final class FoxRunV1ProductionGeometry {
  static const canvasSize = Size(1646, 783);
  static const bodyOrigin = Offset(897.4332949552927, 366.7165635675376);
  static const virtualGround = 687.0;
  static const torsoLength = 516.0;
  static const previousDisplayedTorsoLength = 110.0;

  /// Restores the original intentional preview scale: the 1646px canonical
  /// canvas rendered at 220px wide before BODY registration was introduced.
  static const displayedCanvasWidth = 220.0;
  static const displayScale = displayedCanvasWidth / 1646.0;
  static const displayedTorsoLength = torsoLength * displayScale;
  static const stageHeight = 150.0;
  static const groundInset = 28.0;
  static const crossingSafetyGap = 8.0;
  static const groundVerticalOffset = 2.0;

  /// Union of all registered canonical silhouette bounds.  This is the
  /// endpoint authority; it intentionally excludes transparent canvas area.
  static const visibleBoundsCanonical = Rect.fromLTRB(
    96.0,
    96.0,
    1548.675,
    685.215,
  );

  static double scaleFor(FoxRunV1BodySize bodySize) => switch (bodySize) {
    FoxRunV1BodySize.half => 0.5,
    FoxRunV1BodySize.sevenTenths => 0.7,
    FoxRunV1BodySize.full => 1.0,
  };

  static Size get scaledCanvas => scaledCanvasFor(1);

  static Size scaledCanvasFor(double bodyScale) => Size(
    canvasSize.width * displayScale * bodyScale,
    canvasSize.height * displayScale * bodyScale,
  );

  static double displayedTorsoLengthFor(double bodyScale) =>
      displayedTorsoLength * bodyScale;

  /// Converts a requested torso displacement into a Y scale around the
  /// canonical ground anchor, keeping the contact point stationary.
  static double bodyFlexScale({
    required double bodyScale,
    required double bodyFlexOffset,
  }) {
    final torsoToGround =
        (virtualGround - bodyOrigin.dy) * displayScale * bodyScale;
    return 1 + bodyFlexOffset / torsoToGround;
  }

  static double stageGroundY(double stageHeight) => stageHeight - groundInset;

  static Offset imageTopLeft({
    required double bodyCenterX,
    required double stageGroundY,
    double bodyScale = 1,
    double verticalFlutterOffset = 0,
  }) => Offset(
    bodyCenterX - bodyOrigin.dx * displayScale * bodyScale,
    stageGroundY -
        virtualGround * displayScale * bodyScale +
        groundVerticalOffset +
        verticalFlutterOffset,
  );

  static Rect visibleBounds({
    required double bodyCenterX,
    required double stageGroundY,
    required bool leftToRight,
    double bodyScale = 1,
    double verticalFlutterOffset = 0,
  }) {
    final image = imageTopLeft(
      bodyCenterX: bodyCenterX,
      stageGroundY: stageGroundY,
      bodyScale: bodyScale,
      verticalFlutterOffset: verticalFlutterOffset,
    );
    final relativeLeft =
        (visibleBoundsCanonical.left - bodyOrigin.dx) *
        displayScale *
        bodyScale;
    final relativeRight =
        (visibleBoundsCanonical.right - bodyOrigin.dx) *
        displayScale *
        bodyScale;
    final renderedLeft = leftToRight ? relativeLeft : -relativeRight;
    final renderedRight = leftToRight ? relativeRight : -relativeLeft;
    return Rect.fromLTRB(
      bodyCenterX + renderedLeft,
      image.dy + visibleBoundsCanonical.top * displayScale,
      bodyCenterX + renderedRight,
      image.dy + visibleBoundsCanonical.bottom * displayScale,
    );
  }

  static double bodyCenterForProgress({
    required double stageWidth,
    required double progress,
    required bool leftToRight,
    double bodyScale = 1,
  }) {
    final relativeLeft =
        (visibleBoundsCanonical.left - bodyOrigin.dx) *
        displayScale *
        bodyScale;
    final relativeRight =
        (visibleBoundsCanonical.right - bodyOrigin.dx) *
        displayScale *
        bodyScale;
    final renderedLeft = leftToRight ? relativeLeft : -relativeRight;
    final renderedRight = leftToRight ? relativeRight : -relativeLeft;
    final leftExit = -crossingSafetyGap - renderedRight;
    final rightExit = stageWidth + crossingSafetyGap - renderedLeft;
    return leftToRight
        ? leftExit + (rightExit - leftExit) * progress
        : rightExit - (rightExit - leftExit) * progress;
  }
}

class FoxRunV1ProductionStage extends StatelessWidget {
  const FoxRunV1ProductionStage({
    super.key,
    required this.crossing,
    required this.asset,
    required this.leftToRight,
    this.bodyScale = 1,
    this.verticalFlutterOffset = 0,
    this.bodyFlexOffset = 0,
    this.bodyFlexOffsetProvider,
    this.pattern = FoxRunV1Pattern.off,
  });
  final Animation<double> crossing;
  final String asset;
  final bool leftToRight;
  final double bodyScale;
  final double verticalFlutterOffset;
  final double bodyFlexOffset;
  final double Function()? bodyFlexOffsetProvider;
  final FoxRunV1Pattern pattern;
  static const previewBackgroundColor = Color(0xFF101010);
  static const silhouetteColor = Color(0xFF7A7A7A);
  static const patternLightColor = Color(0xFF9F9F9F);
  static const patternDarkColor = Color(0xFF535353);

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('fox-run-v1-production-stage'),
    height: FoxRunV1ProductionGeometry.stageHeight,
    child: LayoutBuilder(
      builder: (context, constraints) => ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: const ColoredBox(color: previewBackgroundColor),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Divider(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            AnimatedBuilder(
              key: const ValueKey('fox-run-v1-crossing'),
              animation: crossing,
              builder: (_, child) {
                final t = crossing.value;
                final stageGround = FoxRunV1ProductionGeometry.stageGroundY(
                  constraints.maxHeight,
                );
                final bodyCenter =
                    FoxRunV1ProductionGeometry.bodyCenterForProgress(
                      stageWidth: constraints.maxWidth,
                      progress: t,
                      leftToRight: leftToRight,
                      bodyScale: bodyScale,
                    );
                final image = FoxRunV1ProductionGeometry.imageTopLeft(
                  bodyCenterX: bodyCenter,
                  stageGroundY: stageGround,
                  bodyScale: bodyScale,
                  verticalFlutterOffset: verticalFlutterOffset,
                );
                final canvas = FoxRunV1ProductionGeometry.scaledCanvasFor(
                  bodyScale,
                );
                final resolvedBodyFlexOffset =
                    bodyFlexOffsetProvider?.call() ?? bodyFlexOffset;
                return Positioned(
                  left: image.dx,
                  top: image.dy,
                  width: canvas.width,
                  height: canvas.height,
                  child: Transform(
                    key: const ValueKey('fox-run-v1-body-flex'),
                    alignment: Alignment(
                      (FoxRunV1ProductionGeometry.bodyOrigin.dx /
                                  FoxRunV1ProductionGeometry.canvasSize.width) *
                              2 -
                          1,
                      (FoxRunV1ProductionGeometry.virtualGround /
                                  FoxRunV1ProductionGeometry
                                      .canvasSize
                                      .height) *
                              2 -
                          1,
                    ),
                    transform: Matrix4.diagonal3Values(
                      leftToRight ? 1 : -1,
                      FoxRunV1ProductionGeometry.bodyFlexScale(
                        bodyScale: bodyScale,
                        bodyFlexOffset: resolvedBodyFlexOffset,
                      ),
                      1,
                    ),
                    child: _FoxPatternCel(asset: asset, pattern: pattern),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _FoxPatternCel extends StatelessWidget {
  const _FoxPatternCel({required this.asset, required this.pattern});

  final String asset;
  final FoxRunV1Pattern pattern;

  @override
  Widget build(BuildContext context) {
    final base = _coloredCel(
      key: const ValueKey('fox-run-v1-pattern-base'),
      color: FoxRunV1ProductionStage.silhouetteColor,
    );
    if (pattern == FoxRunV1Pattern.off) return base;
    return Stack(
      fit: StackFit.expand,
      children: [
        base,
        _patternRegion(
          key: const ValueKey('fox-run-v1-pattern-tail-tip'),
          region: _FoxPatternRegion.tailTip,
          color: FoxRunV1ProductionStage.patternLightColor,
        ),
        _patternRegion(
          key: const ValueKey('fox-run-v1-pattern-jaw-throat'),
          region: _FoxPatternRegion.jawThroat,
          color: FoxRunV1ProductionStage.patternLightColor,
        ),
        _patternRegion(
          key: const ValueKey('fox-run-v1-pattern-feet'),
          region: _FoxPatternRegion.feet,
          color: FoxRunV1ProductionStage.patternDarkColor,
        ),
      ],
    );
  }

  Widget _patternRegion({
    required Key key,
    required _FoxPatternRegion region,
    required Color color,
  }) => ClipPath(
    key: key,
    clipper: _FoxPatternRegionClipper(
      region,
      int.tryParse(RegExp(r'frame_(\d+)').firstMatch(asset)?.group(1) ?? '') ??
          5,
    ),
    child: _coloredCel(color: color),
  );

  Widget _coloredCel({Key? key, required Color color}) => ColorFiltered(
    key: key,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    child: Image.asset(asset, fit: BoxFit.fill),
  );
}

enum _FoxPatternRegion { tailTip, jawThroat, feet }

class _FoxPatternRegionClipper extends CustomClipper<Path> {
  const _FoxPatternRegionClipper(this.region, this.frame);

  final _FoxPatternRegion region;
  final int frame;

  @override
  Path getClip(Size size) {
    final part = switch (region) {
      _FoxPatternRegion.tailTip => 'tail',
      _FoxPatternRegion.jawThroat => 'jaw',
      _FoxPatternRegion.feet => 'feet',
    };
    return FoxPatternProductionGeometry.path(
      frame: FoxPatternPreview.frames.contains(frame) ? frame : 5,
      part: part,
      size: size,
    );
    /*return switch (region) {
      _FoxPatternRegion.tailTip =>
        Path()
          ..moveTo(size.width * .035, size.height * .50)
          ..cubicTo(
            size.width * .058,
            size.height * .43,
            size.width * .092,
            size.height * .365,
            size.width * .125,
            size.height * .34,
          )
          ..cubicTo(
            size.width * .148,
            size.height * .322,
            size.width * .17,
            size.height * .31,
            size.width * .18,
            size.height * .302,
          )
          ..cubicTo(
            size.width * .198,
            size.height * .35,
            size.width * .198,
            size.height * .402,
            size.width * .192,
            size.height * .445,
          )
          ..cubicTo(
            size.width * .186,
            size.height * .49,
            size.width * .172,
            size.height * .528,
            size.width * .153,
            size.height * .55,
          )
          ..cubicTo(
            size.width * .112,
            size.height * .56,
            size.width * .073,
            size.height * .54,
            size.width * .035,
            size.height * .50,
          )
          ..close(),
      _FoxPatternRegion.jawThroat =>
        Path()
          ..moveTo(size.width * .982, size.height * .382)
          ..cubicTo(
            size.width * .968,
            size.height * .4,
            size.width * .951,
            size.height * .409,
            size.width * .932,
            size.height * .414,
          )
          ..cubicTo(
            size.width * .905,
            size.height * .423,
            size.width * .892,
            size.height * .445,
            size.width * .877,
            size.height * .473,
          )
          ..cubicTo(
            size.width * .855,
            size.height * .504,
            size.width * .835,
            size.height * .536,
            size.width * .806,
            size.height * .568,
          )
          ..quadraticBezierTo(
            size.width * .784,
            size.height * .588,
            size.width * .76,
            size.height * .583,
          )
          ..cubicTo(
            size.width * .779,
            size.height * .555,
            size.width * .795,
            size.height * .526,
            size.width * .812,
            size.height * .502,
          )
          ..cubicTo(
            size.width * .83,
            size.height * .479,
            size.width * .845,
            size.height * .455,
            size.width * .861,
            size.height * .431,
          )
          ..cubicTo(
            size.width * .883,
            size.height * .404,
            size.width * .91,
            size.height * .385,
            size.width * .937,
            size.height * .374,
          )
          ..cubicTo(
            size.width * .954,
            size.height * .365,
            size.width * .97,
            size.height * .368,
            size.width * .982,
            size.height * .382,
          )
          ..close(),
      _FoxPatternRegion.feet =>
        Path()..addPolygon([
          point(.34, .62),
          point(.74, .62),
          point(.74, .93),
          point(.34, .93),
        ], true),
    };*/
  }

  @override
  bool shouldReclip(covariant _FoxPatternRegionClipper oldClipper) =>
      oldClipper.region != region || oldClipper.frame != frame;
}

class _FoxBodyOverlayPainter extends CustomPainter {
  const _FoxBodyOverlayPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final origin = Offset(
      size.width * (897.4332949552927 / 1646),
      size.height * (366.7165635675376 / 783),
    );
    final ground = size.height * (687 / 783);
    canvas.drawLine(Offset(0, ground), Offset(size.width, ground), p);
    canvas.drawCircle(origin, 5, p);
    canvas.drawLine(
      origin - const Offset(55, 0),
      origin + const Offset(55, 0),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
