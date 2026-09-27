import 'dart:async';

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
  static const _frameCount = 10;

  var _expanded = false;
  var _frame = 0;
  var _auditMode = _FoxAuditMode.canonical;
  var _inspectionScale = 0.5;
  var _frameDuration = const Duration(milliseconds: 80);
  var _leftToRight = true;
  var _crossingDuration = const Duration(milliseconds: 3000);
  late final AnimationController _inPlace = AnimationController(vsync: this);
  late final AnimationController _crossing =
      AnimationController(vsync: this, duration: _crossingDuration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            _crossing.forward(from: 0);
          }
        });
  Timer? _frameTimer;

  @override
  void dispose() {
    _frameTimer?.cancel();
    _inPlace.dispose();
    _crossing.dispose();
    super.dispose();
  }

  String _asset({required bool source}) =>
      'assets/animations/sandbox/fox_v1/${source ? 'source' : 'canonical'}/'
      'frame_${(_frame + 1).toString().padLeft(2, '0')}.png';

  void _setPlayback(bool playing) {
    _frameTimer?.cancel();
    if (!playing) {
      _inPlace.stop();
      _crossing.stop();
      return;
    }
    _inPlace.repeat();
    _crossing.repeat();
    _frameTimer = Timer.periodic(_frameDuration, (_) {
      if (mounted) setState(() => _frame = (_frame + 1) % _frameCount);
    });
  }

  void _restart() {
    setState(() => _frame = 0);
    _setPlayback(true);
  }

  void _setFrameDuration(int milliseconds) {
    setState(() => _frameDuration = Duration(milliseconds: milliseconds));
    if (_frameTimer != null) _setPlayback(true);
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
      _FoxStage(
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
        children: [2250, 3000, 3750]
            .map(
              (value) => ChoiceChip(
                label: Text(
                  value == 3000
                      ? '1× CAT REF'
                      : value < 3000
                      ? '1.25×'
                      : '0.75×',
                ),
                selected: _crossingDuration.inMilliseconds == value,
                onSelected: (_) => setState(() {
                  _crossingDuration = Duration(milliseconds: value);
                  _crossing.duration = _crossingDuration;
                }),
              ),
            )
            .toList(),
      ),
      AppSpacing.gapSM,
      Text(
        'CURRENT: canonical FOX • ${_frameDuration.inMilliseconds}ms/frame • ${_crossingDuration.inMilliseconds}ms crossing • display body 110px',
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

class _FoxStage extends StatelessWidget {
  const _FoxStage({
    required this.crossing,
    required this.asset,
    required this.leftToRight,
  });
  final Animation<double> crossing;
  final String asset;
  final bool leftToRight;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 150,
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
              animation: crossing,
          builder: (_, child) {
                const visibleWidth = 220.0;
                final t = crossing.value;
                final x = leftToRight
                    ? -visibleWidth +
                          (constraints.maxWidth + visibleWidth * 2) * t
                    : constraints.maxWidth +
                          visibleWidth -
                          (constraints.maxWidth + visibleWidth * 2) * t;
                return Positioned(
                  left: x,
                  bottom: 29,
                  width: visibleWidth,
                  height: 105,
                  child: _FoxCel(asset: asset, mirror: !leftToRight),
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
