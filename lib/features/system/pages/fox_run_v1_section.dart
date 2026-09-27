import 'package:flutter/material.dart';

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
  var _frameDuration = FoxRunV1Motion.frameDuration;
  var _leftToRight = true;
  var _crossingCycles = FoxRunV1Motion.crossingCycles;
  Duration get _crossingDuration => FoxRunV1Motion.durationForCycles(
    _crossingCycles,
    celDuration: _frameDuration,
  );
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
      return;
    }
    _crossing.repeat();
    _syncFrameToCrossing();
  }

  void _syncFrameToCrossing() {
    if (!mounted || !_crossing.isAnimating) return;
    final nextFrame = FoxRunV1Motion.frameAtCrossingProgress(
      _crossing.value,
      celDuration: _frameDuration,
      runDuration: _crossingDuration,
    );
    if (nextFrame != _frame) setState(() => _frame = nextFrame);
  }

  void _restart() {
    setState(() => _frame = 0);
    _crossing
      ..stop()
      ..value = 0;
    _setPlayback(true);
  }

  void _setFrameDuration(int milliseconds) {
    setState(() => _frameDuration = Duration(milliseconds: milliseconds));
    _crossing.duration = _crossingDuration;
    _syncFrameToCrossing();
  }

  void _setCrossingCycles(int cycles) {
    setState(() => _crossingCycles = cycles);
    _crossing.duration = _crossingDuration;
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
      const Text('FRAME TIMING'),
      Wrap(
        spacing: AppSpacing.xs,
        children: [60, 80, 100]
            .map(
              (value) => ChoiceChip(
                label: Text('${value}ms'),
                selected: _frameDuration.inMilliseconds == value,
                onSelected: (_) => _setFrameDuration(value),
              ),
            )
            .toList(),
      ),
      AppSpacing.gapSM,
      const Text('CROSSING SPEED'),
      Wrap(
        spacing: AppSpacing.xs,
        children: [3, 4, 5]
            .map(
              (cycles) => ChoiceChip(
                label: Text('$cycles CYCLES'),
                selected: _crossingCycles == cycles,
                onSelected: (_) => _setCrossingCycles(cycles),
              ),
            )
            .toList(),
      ),
      AppSpacing.gapSM,
      Text(
        'CURRENT: canonical FOX • ${_frameDuration.inMilliseconds}ms/frame • ${_crossingDuration.inMilliseconds}ms crossing • display body ${FoxRunV1ProductionGeometry.displayedTorsoLength.toStringAsFixed(0)}px',
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
  static const frameDuration = Duration(milliseconds: 80);
  static const cycleDuration = Duration(milliseconds: frameCount * 80);
  static const crossingCycles = 4;
  static const crossingDuration = Duration(
    milliseconds: frameCount * 80 * crossingCycles,
  );

  static Duration durationForCycles(int cycles, {Duration? celDuration}) =>
      Duration(
        microseconds:
            (celDuration ?? frameDuration).inMicroseconds * frameCount * cycles,
      );

  static int frameAtCrossingProgress(
    double progress, {
    Duration? celDuration,
    Duration? runDuration,
  }) {
    final resolvedCelDuration = celDuration ?? frameDuration;
    final resolvedRunDuration = runDuration ?? crossingDuration;
    final safeProgress = progress.clamp(0.0, 0.999999).toDouble();
    final elapsedMicroseconds =
        (resolvedRunDuration.inMicroseconds * safeProgress).round();
    return (elapsedMicroseconds ~/ resolvedCelDuration.inMicroseconds) %
        frameCount;
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

  /// Union of all registered canonical silhouette bounds.  This is the
  /// endpoint authority; it intentionally excludes transparent canvas area.
  static const visibleBoundsCanonical = Rect.fromLTRB(
    96.0,
    96.0,
    1548.675,
    685.215,
  );

  static Size get scaledCanvas =>
      Size(canvasSize.width * displayScale, canvasSize.height * displayScale);

  static double stageGroundY(double stageHeight) => stageHeight - groundInset;

  static Offset imageTopLeft({
    required double bodyCenterX,
    required double stageGroundY,
  }) => Offset(
    bodyCenterX - bodyOrigin.dx * displayScale,
    stageGroundY - virtualGround * displayScale,
  );

  static Rect visibleBounds({
    required double bodyCenterX,
    required double stageGroundY,
    required bool leftToRight,
  }) {
    final image = imageTopLeft(
      bodyCenterX: bodyCenterX,
      stageGroundY: stageGroundY,
    );
    final relativeLeft =
        (visibleBoundsCanonical.left - bodyOrigin.dx) * displayScale;
    final relativeRight =
        (visibleBoundsCanonical.right - bodyOrigin.dx) * displayScale;
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
  }) {
    final relativeLeft =
        (visibleBoundsCanonical.left - bodyOrigin.dx) * displayScale;
    final relativeRight =
        (visibleBoundsCanonical.right - bodyOrigin.dx) * displayScale;
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
  });
  final Animation<double> crossing;
  final String asset;
  final bool leftToRight;
  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('fox-run-v1-production-stage'),
    height: FoxRunV1ProductionGeometry.stageHeight,
    child: LayoutBuilder(
      builder: (context, constraints) => ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: .22),
              ),
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
                    );
                final image = FoxRunV1ProductionGeometry.imageTopLeft(
                  bodyCenterX: bodyCenter,
                  stageGroundY: stageGround,
                );
                final canvas = FoxRunV1ProductionGeometry.scaledCanvas;
                return Positioned(
                  left: image.dx,
                  top: image.dy,
                  width: canvas.width,
                  height: canvas.height,
                  child: Transform(
                    alignment: Alignment(
                      (FoxRunV1ProductionGeometry.bodyOrigin.dx /
                                  FoxRunV1ProductionGeometry.canvasSize.width) *
                              2 -
                          1,
                      (FoxRunV1ProductionGeometry.bodyOrigin.dy /
                                  FoxRunV1ProductionGeometry
                                      .canvasSize
                                      .height) *
                              2 -
                          1,
                    ),
                    transform: Matrix4.diagonal3Values(
                      leftToRight ? 1 : -1,
                      1,
                      1,
                    ),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        Colors.grey.shade300,
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(asset, fit: BoxFit.fill),
                    ),
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
