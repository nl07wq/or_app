import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import 'bat_source_vector_rebuild_data.dart';

/// Sandbox-only audit surface for the five user-supplied BAT silhouette
/// sources. The frozen HIGH vectors deliberately have no playback timing or
/// flight behavior; motion is rebuilt only after real-device source approval.
class BatFlightMotionPoc extends StatefulWidget {
  const BatFlightMotionPoc({super.key});

  @override
  State<BatFlightMotionPoc> createState() => _BatFlightMotionPocState();
}

enum BatSourceInspectionMode { source, mask, vector, overlay, registered }

class _BatFlightMotionPocState extends State<BatFlightMotionPoc> {
  var _frameIndex = 0;
  var _leftToRight = true;
  var _zoom = 1;
  var _mode = BatSourceInspectionMode.source;

  BatSourceVectorFrame get _frame => BatSourceVectorRebuild.frames[_frameIndex];

  void _setFrame(int index) => setState(() => _frameIndex = index);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader(
        icon: Icons.document_scanner_outlined,
        title: 'BAT SOURCE VECTOR REBUILD V2',
      ),
      AppSpacing.gapSM,
      OperationCard(
        key: const ValueKey('bat-source-vector-rebuild-poc'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('SOURCE FIDELITY AUDIT · MOTION FROZEN'),
            Text(
              'FRAME ${_frame.sourceIndex.toString().padLeft(2, '0')} · '
              'SOURCE CORRESPONDENCE PASS',
              key: const ValueKey('bat-source-vector-selected-frame'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              _frame.sourceIdentifier,
              key: const ValueKey('bat-source-vector-source-identifier'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            AppSpacing.gapSM,
            _BatSourceCanvas(
              frame: _frame,
              mode: _mode,
              leftToRight: _leftToRight,
              zoom: _zoom,
            ),
            AppSpacing.gapSM,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (
                  var index = 0;
                  index < BatSourceVectorRebuild.frames.length;
                  index++
                )
                  _AuditButton(
                    key: ValueKey('bat-source-vector-frame-${index + 1}'),
                    label: 'FRAME ${(index + 1).toString().padLeft(2, '0')}',
                    selected: _frameIndex == index,
                    onPressed: () => _setFrame(index),
                  ),
              ],
            ),
            AppSpacing.gapMD,
            const Text('SOURCE / VECTOR INSPECTION'),
            AppSpacing.gapSM,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mode in BatSourceInspectionMode.values)
                  _AuditButton(
                    key: ValueKey('bat-source-vector-mode-${mode.name}'),
                    label: switch (mode) {
                      BatSourceInspectionMode.source => 'SOURCE',
                      BatSourceInspectionMode.mask => 'MASK',
                      BatSourceInspectionMode.vector => 'VECTOR',
                      BatSourceInspectionMode.overlay => 'OVERLAY',
                      BatSourceInspectionMode.registered =>
                        'REGISTERED PREVIEW',
                    },
                    selected: _mode == mode,
                    onPressed: () => setState(() => _mode = mode),
                  ),
              ],
            ),
            AppSpacing.gapMD,
            const Text('DIRECTION / INSPECTION SCALE'),
            AppSpacing.gapSM,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AuditButton(
                  key: const ValueKey('bat-source-vector-direction-ltr'),
                  label: 'L→R',
                  selected: _leftToRight,
                  onPressed: () => setState(() => _leftToRight = true),
                ),
                _AuditButton(
                  key: const ValueKey('bat-source-vector-direction-rtl'),
                  label: 'R→L',
                  selected: !_leftToRight,
                  onPressed: () => setState(() => _leftToRight = false),
                ),
                for (final zoom in [1, 2, 4])
                  _AuditButton(
                    key: ValueKey('bat-source-vector-zoom-$zoom'),
                    label: '$zoom×',
                    selected: _zoom == zoom,
                    onPressed: () => setState(() => _zoom = zoom),
                  ),
              ],
            ),
            AppSpacing.gapMD,
            _MetricPanel(frame: _frame),
            AppSpacing.gapMD,
            const Text('48PX VECTOR PREVIEW'),
            Semantics(
              label: 'Bat source-derived frozen HIGH vector at wildlife scale',
              child: SizedBox(
                key: const ValueKey('bat-source-vector-production-preview'),
                height: 48,
                child: CustomPaint(
                  painter: BatSourceVectorPainter(
                    frame: _frame,
                    mode: BatSourceInspectionMode.vector,
                    leftToRight: _leftToRight,
                    scale: 48 / BatSourceVectorRebuild.sourceCanvasSize.height,
                  ),
                ),
              ),
            ),
            AppSpacing.gapSM,
            const Text(
              'MASK is derived from the source-local foreground contour. HIGH '
              'vectors are frozen before registration; registered preview uses '
              'translation only. No source raster, animation timing, morph, '
              'travel, scheduler, or Production BAT behavior is present.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    ],
  );
}

class _MetricPanel extends StatelessWidget {
  const _MetricPanel({required this.frame});

  final BatSourceVectorFrame frame;

  @override
  Widget build(BuildContext context) => Text(
    'RAW ${frame.rawPointCount} pts · HIGH ${frame.highPointCount} pts\n'
    'IoU ${(frame.iou * 100).toStringAsFixed(3)}% · '
    'DISAGREEMENT ${(frame.disagreement * 100).toStringAsFixed(3)}%\n'
    'REGISTERED Δx ${frame.registrationTranslation.dx.toStringAsFixed(0)} '
    'Δy ${frame.registrationTranslation.dy.toStringAsFixed(0)} · '
    'SCALE ${BatSourceVectorFrame.uniformScale.toStringAsFixed(2)}',
    key: const ValueKey('bat-source-vector-metrics'),
    style: Theme.of(context).textTheme.bodySmall,
  );
}

class _AuditButton extends StatelessWidget {
  const _AuditButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    style: selected
        ? OutlinedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          )
        : null,
    onPressed: onPressed,
    child: Text(label),
  );
}

class _BatSourceCanvas extends StatelessWidget {
  const _BatSourceCanvas({
    required this.frame,
    required this.mode,
    required this.leftToRight,
    required this.zoom,
  });

  final BatSourceVectorFrame frame;
  final BatSourceInspectionMode mode;
  final bool leftToRight;
  final int zoom;

  @override
  Widget build(BuildContext context) {
    final scale = .22 * zoom;
    final size = BatSourceVectorRebuild.sourceCanvasSize;
    return SizedBox(
      height: size.height * scale + 8,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          key: ValueKey('bat-source-vector-inspection-$zoom'),
          width: size.width * scale + 8,
          height: size.height * scale + 8,
          child: CustomPaint(
            painter: BatSourceVectorPainter(
              frame: frame,
              mode: mode,
              leftToRight: leftToRight,
              scale: scale,
            ),
          ),
        ),
      ),
    );
  }
}

class BatSourceVectorPainter extends CustomPainter {
  const BatSourceVectorPainter({
    required this.frame,
    required this.mode,
    required this.leftToRight,
    required this.scale,
  });

  final BatSourceVectorFrame frame;
  final BatSourceInspectionMode mode;
  final bool leftToRight;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF101010),
    );
    final sourceSize = BatSourceVectorRebuild.sourceCanvasSize;
    final renderedWidth = sourceSize.width * scale;
    final renderedHeight = sourceSize.height * scale;
    canvas.save();
    canvas.translate(
      (size.width - renderedWidth) / 2,
      (size.height - renderedHeight) / 2,
    );
    if (!leftToRight) {
      canvas.translate(renderedWidth, 0);
      canvas.scale(-1, 1);
    }
    canvas.scale(scale);
    if (mode == BatSourceInspectionMode.registered) {
      canvas.translate(
        frame.registrationTranslation.dx,
        frame.registrationTranslation.dy,
      );
    }
    _paintMode(canvas);
    canvas.restore();
  }

  void _paintMode(Canvas canvas) {
    final raw = frame.rawContour();
    final high = frame.highVector();
    switch (mode) {
      case BatSourceInspectionMode.source:
        canvas.drawPath(raw, Paint()..color = const Color(0xFFE6E6E6));
      case BatSourceInspectionMode.mask:
        canvas.drawPath(raw, Paint()..color = const Color(0xFF9DB6C5));
      case BatSourceInspectionMode.vector:
      case BatSourceInspectionMode.registered:
        canvas.drawPath(high, Paint()..color = const Color(0xFFCFD8DC));
      case BatSourceInspectionMode.overlay:
        canvas.drawPath(
          raw,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFFE57373),
        );
        canvas.drawPath(
          high,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFF80CBC4),
        );
    }
  }

  @override
  bool shouldRepaint(covariant BatSourceVectorPainter old) =>
      old.frame != frame ||
      old.mode != mode ||
      old.leftToRight != leftToRight ||
      old.scale != scale;
}
