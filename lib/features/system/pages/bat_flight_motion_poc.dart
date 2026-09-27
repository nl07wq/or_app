import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import 'bat_source_vector_rebuild_data.dart';
import 'bat_semantic_motion.dart';

/// Sandbox-only source audit and discrete flap-cycle POC. Both surfaces share
/// the accepted HIGH vectors; playback changes only the selected frame index.
class BatFlightMotionPoc extends StatefulWidget {
  const BatFlightMotionPoc({super.key});

  @override
  State<BatFlightMotionPoc> createState() => _BatFlightMotionPocState();
}

enum BatSourceInspectionMode { source, mask, vector, overlay, registered }

class _BatFlightMotionPocState extends State<BatFlightMotionPoc> {
  Timer? _playbackTimer;
  var _frameIndex = 0;
  var _sequencePosition = 0;
  var _leftToRight = true;
  var _zoom = 1;
  var _timing = BatMotionTiming.normal;
  var _isPlaying = false;
  var _mode = BatSourceInspectionMode.source;
  var _semanticLayer = BatSemanticLayer.all;

  BatSourceVectorFrame get _frame => BatSourceVectorRebuild.frames[_frameIndex];
  Duration get _stepDuration => Duration(milliseconds: _timing.milliseconds);
  BatSemanticMotionFrame get _motionFrame =>
      BatSemanticMotion.cycle[_sequencePosition];

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _setFrame(int index) {
    _pause();
    setState(() {
      _frameIndex = index;
      _sequencePosition = BatSemanticMotion.cycle.indexWhere(
        (motion) => motion.keyIndex == index,
      );
    });
  }

  void _play() {
    if (_isPlaying) {
      return;
    }
    setState(() => _isPlaying = true);
    _startTimer();
  }

  void _pause() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    if (_isPlaying && mounted) {
      setState(() => _isPlaying = false);
    }
  }

  void _restart() {
    _playbackTimer?.cancel();
    setState(() {
      _frameIndex = 0;
      _sequencePosition = 0;
      _isPlaying = true;
    });
    _startTimer();
  }

  void _startTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(_stepDuration, (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sequencePosition =
            (_sequencePosition + 1) % BatSemanticMotion.cycle.length;
        final key = _motionFrame.keyIndex;
        if (key != null) _frameIndex = key;
      });
    });
  }

  void _setTiming(BatMotionTiming timing) {
    if (_timing == timing) {
      return;
    }
    final resume = _isPlaying;
    _playbackTimer?.cancel();
    setState(() => _timing = timing);
    if (resume) {
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader(
        icon: Icons.document_scanner_outlined,
        title: 'BAT SOURCE VECTOR REBUILD V2',
      ),
      AppSpacing.gapSM,
      _buildSourceAudit(context),
      AppSpacing.gapLG,
      const SectionHeader(
        icon: Icons.motion_photos_on_outlined,
        title: 'BAT 5-FRAME FLAP CYCLE',
      ),
      AppSpacing.gapSM,
      _buildFlapCycle(context),
    ],
  );

  Widget _buildSourceAudit(BuildContext context) => OperationCard(
    key: const ValueKey('bat-source-vector-rebuild-poc'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('SOURCE FIDELITY AUDIT · HIGH GEOMETRY FROZEN'),
        _selectedFrameLabel(context),
        Text(
          _frame.sourceIdentifier,
          key: const ValueKey('bat-source-vector-source-identifier'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        AppSpacing.gapSM,
        _BatVectorCanvas(
          keyPrefix: 'bat-source-vector-inspection',
          frame: _frame,
          mode: _mode,
          leftToRight: _leftToRight,
          zoom: _zoom,
        ),
        AppSpacing.gapSM,
        _frameControls('bat-source-vector-frame'),
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
                  BatSourceInspectionMode.registered => 'REGISTERED PREVIEW',
                },
                selected: _mode == mode,
                onPressed: () => setState(() => _mode = mode),
              ),
          ],
        ),
        AppSpacing.gapMD,
        _directionAndScaleControls(),
        AppSpacing.gapMD,
        _MetricPanel(frame: _frame),
        AppSpacing.gapMD,
        const Text('48PX VECTOR PREVIEW'),
        _preview48(
          key: const ValueKey('bat-source-vector-production-preview'),
          mode: BatSourceInspectionMode.vector,
          semanticsLabel:
              'Bat source-derived frozen HIGH vector at wildlife scale',
        ),
        AppSpacing.gapSM,
        const Text(
          'MASK is derived from the source-local foreground contour. SOURCE, '
          'MASK, VECTOR, OVERLAY, and REGISTERED PREVIEW all consume the '
          'same frozen source data.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
  );

  Widget _buildFlapCycle(BuildContext context) => OperationCard(
    key: const ValueKey('bat-flap-cycle-poc'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('SEMANTIC LAYER MOTION · TOPOLOGY-SAFE PLAYBACK'),
        Text(
          _isPlaying
              ? 'PLAYING · ${_timing.milliseconds}MS / STEP'
              : 'PAUSED · ${_timing.milliseconds}MS / STEP',
          key: const ValueKey('bat-flap-playback-state'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        _selectedFrameLabel(context),
        AppSpacing.gapSM,
        _BatMotionCanvas(
          keyPrefix: 'bat-flap-inspection',
          motionFrame: _motionFrame,
          leftToRight: _leftToRight,
          zoom: _zoom,
          layer: _semanticLayer,
        ),
        AppSpacing.gapSM,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _AuditButton(
              key: const ValueKey('bat-flap-play'),
              label: 'PLAY',
              selected: _isPlaying,
              onPressed: _play,
            ),
            _AuditButton(
              key: const ValueKey('bat-flap-pause'),
              label: 'PAUSE',
              selected: !_isPlaying,
              onPressed: _pause,
            ),
            _AuditButton(
              key: const ValueKey('bat-flap-restart'),
              label: 'RESTART',
              selected: false,
              onPressed: _restart,
            ),
          ],
        ),
        AppSpacing.gapSM,
        _frameControls('bat-flap-frame'),
        AppSpacing.gapSM,
        const Text('SEMANTIC LAYERS · FAR WING → BODY → NEAR WING'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final layer in BatSemanticLayer.values)
              _AuditButton(
                key: ValueKey('bat-semantic-layer-${layer.name}'),
                label: switch (layer) {
                  BatSemanticLayer.all => 'ALL',
                  BatSemanticLayer.body => 'BODY',
                  BatSemanticLayer.nearWing => 'NEAR WING',
                  BatSemanticLayer.farWing => 'FAR WING',
                },
                selected: _semanticLayer == layer,
                onPressed: () => setState(() => _semanticLayer = layer),
              ),
          ],
        ),
        AppSpacing.gapMD,
        const Text('CYCLE TIMING'),
        AppSpacing.gapSM,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final timing in BatMotionTiming.values)
              _AuditButton(
                key: ValueKey('bat-flap-timing-${timing.name}'),
                label: '${timing.label} ${timing.milliseconds}ms',
                selected: _timing == timing,
                onPressed: () => _setTiming(timing),
              ),
          ],
        ),
        AppSpacing.gapMD,
        _directionAndScaleControls(prefix: 'bat-flap'),
        AppSpacing.gapMD,
        _BodyDiagnosticPanel(frameIndex: _frameIndex),
        AppSpacing.gapMD,
        const Text('48PX ANIMATED PREVIEW'),
        _motionPreview48(),
        AppSpacing.gapSM,
        const Text(
          'SOURCE HIGH keys remain frozen. Two manual semantic-layer '
          'intermediates per transition are composited FAR WING → BODY → '
          'NEAR WING; no single-outline interpolation or Production BAT.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
  );

  Widget _selectedFrameLabel(BuildContext context) => Text(
    'FRAME ${_frame.sourceIndex.toString().padLeft(2, '0')} · '
    'SOURCE CORRESPONDENCE PASS',
    key: const ValueKey('bat-source-vector-selected-frame'),
    style: Theme.of(context).textTheme.titleSmall,
  );

  Widget _frameControls(String prefix) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (var index = 0; index < BatSourceVectorRebuild.frames.length; index++)
        _AuditButton(
          key: ValueKey('$prefix-${index + 1}'),
          label: 'FRAME ${(index + 1).toString().padLeft(2, '0')}',
          selected: _frameIndex == index,
          onPressed: () => _setFrame(index),
        ),
    ],
  );

  Widget _directionAndScaleControls({String prefix = 'bat-source-vector'}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('DIRECTION / INSPECTION SCALE'),
          AppSpacing.gapSM,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AuditButton(
                key: ValueKey('$prefix-direction-ltr'),
                label: 'L→R',
                selected: _leftToRight,
                onPressed: () => setState(() => _leftToRight = true),
              ),
              _AuditButton(
                key: ValueKey('$prefix-direction-rtl'),
                label: 'R→L',
                selected: !_leftToRight,
                onPressed: () => setState(() => _leftToRight = false),
              ),
              for (final zoom in [1, 2, 4])
                _AuditButton(
                  key: ValueKey('$prefix-zoom-$zoom'),
                  label: '$zoom×',
                  selected: _zoom == zoom,
                  onPressed: () => setState(() => _zoom = zoom),
                ),
            ],
          ),
        ],
      );

  Widget _preview48({
    required Key key,
    required BatSourceInspectionMode mode,
    required String semanticsLabel,
    Offset presentationPadding = Offset.zero,
  }) {
    final presentationSize = _presentationSize(presentationPadding);
    return Semantics(
      label: semanticsLabel,
      child: SizedBox(
        key: key,
        height: 48,
        child: CustomPaint(
          painter: BatSourceVectorPainter(
            frame: _frame,
            mode: mode,
            leftToRight: _leftToRight,
            scale: 48 / presentationSize.height,
            presentationPadding: presentationPadding,
          ),
        ),
      ),
    );
  }

  Widget _motionPreview48() => Semantics(
    label: 'Bat topology-safe semantic-layer motion at wildlife scale',
    child: SizedBox(
      key: const ValueKey('bat-flap-production-preview'),
      height: 48,
      child: CustomPaint(
        painter: BatSemanticMotionPainter(
          motionFrame: _motionFrame,
          leftToRight: _leftToRight,
          scale: 48 / BatSourceVectorRebuild.sourceCanvasSize.height,
          layer: _semanticLayer,
        ),
      ),
    ),
  );
}

Size _presentationSize(Offset padding) {
  final source = BatSourceVectorRebuild.sourceCanvasSize;
  return Size(source.width + padding.dx * 2, source.height + padding.dy * 2);
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

class _BodyDiagnosticPanel extends StatelessWidget {
  const _BodyDiagnosticPanel({required this.frameIndex});

  final int frameIndex;

  @override
  Widget build(BuildContext context) {
    final diagnostic = BatSourceVectorRebuild.bodyDiagnosticFor(frameIndex);
    final translation =
        BatSourceVectorRebuild.frames[frameIndex].registrationTranslation;
    return Text(
      'BODY SCALE DIAGNOSTIC\n'
      'HEAD→PELVIS ${diagnostic.headToPelvisDistance.toStringAsFixed(1)} · '
      'TORSO ${diagnostic.torsoLength.toStringAsFixed(1)}\n'
      'REGISTERED SHOULDER '
      '${(diagnostic.shoulder + translation).dx.toStringAsFixed(0)}, '
      '${(diagnostic.shoulder + translation).dy.toStringAsFixed(0)} · '
      'SCALE 1.00',
      key: const ValueKey('bat-flap-body-diagnostic'),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
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

class _BatVectorCanvas extends StatelessWidget {
  const _BatVectorCanvas({
    required this.keyPrefix,
    required this.frame,
    required this.mode,
    required this.leftToRight,
    required this.zoom,
  });

  final String keyPrefix;
  final BatSourceVectorFrame frame;
  final BatSourceInspectionMode mode;
  final bool leftToRight;
  final int zoom;

  @override
  Widget build(BuildContext context) {
    final scale = .22 * zoom;
    final size = _presentationSize(Offset.zero);
    return SizedBox(
      height: size.height * scale + 8,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          key: ValueKey('$keyPrefix-$zoom'),
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

class _BatMotionCanvas extends StatelessWidget {
  const _BatMotionCanvas({
    required this.keyPrefix,
    required this.motionFrame,
    required this.leftToRight,
    required this.zoom,
    required this.layer,
  });

  final String keyPrefix;
  final BatSemanticMotionFrame motionFrame;
  final bool leftToRight;
  final int zoom;
  final BatSemanticLayer layer;

  @override
  Widget build(BuildContext context) {
    final scale = .22 * zoom;
    final size = BatSourceVectorRebuild.sourceCanvasSize;
    return SizedBox(
      height: size.height * scale + 8,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          key: ValueKey('$keyPrefix-$zoom'),
          width: size.width * scale + 8,
          height: size.height * scale + 8,
          child: CustomPaint(
            painter: BatSemanticMotionPainter(
              motionFrame: motionFrame,
              leftToRight: leftToRight,
              scale: scale,
              layer: layer,
            ),
          ),
        ),
      ),
    );
  }
}

class BatSemanticMotionPainter extends CustomPainter {
  const BatSemanticMotionPainter({
    required this.motionFrame,
    required this.leftToRight,
    required this.scale,
    this.layer = BatSemanticLayer.all,
  });

  final BatSemanticMotionFrame motionFrame;
  final bool leftToRight;
  final double scale;
  final BatSemanticLayer layer;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF101010),
    );
    final renderedSize = BatSourceVectorRebuild.sourceCanvasSize * scale;
    canvas.save();
    canvas.translate(
      (size.width - renderedSize.width) / 2,
      (size.height - renderedSize.height) / 2,
    );
    if (!leftToRight) {
      canvas.translate(renderedSize.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.scale(scale);
    canvas.translate(
      motionFrame.registrationTranslation.dx,
      motionFrame.registrationTranslation.dy,
    );
    if (motionFrame.isKeyPose) {
      canvas.drawPath(
        BatSourceVectorRebuild.frames[motionFrame.keyIndex!].highVector(),
        Paint()..color = const Color(0xFFCFD8DC),
      );
    } else {
      const color = Color(0xFFCFD8DC);
      if (layer == BatSemanticLayer.all || layer == BatSemanticLayer.farWing) {
        canvas.drawPath(motionFrame.farWing!.path(), Paint()..color = color);
      }
      if (layer == BatSemanticLayer.all || layer == BatSemanticLayer.body) {
        canvas.drawPath(motionFrame.body!.path(), Paint()..color = color);
      }
      if (layer == BatSemanticLayer.all || layer == BatSemanticLayer.nearWing) {
        canvas.drawPath(motionFrame.nearWing!.path(), Paint()..color = color);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BatSemanticMotionPainter old) =>
      old.motionFrame != motionFrame ||
      old.leftToRight != leftToRight ||
      old.scale != scale ||
      old.layer != layer;
}

class BatSourceVectorPainter extends CustomPainter {
  const BatSourceVectorPainter({
    required this.frame,
    required this.mode,
    required this.leftToRight,
    required this.scale,
    this.presentationPadding = Offset.zero,
  });

  final BatSourceVectorFrame frame;
  final BatSourceInspectionMode mode;
  final bool leftToRight;
  final double scale;
  final Offset presentationPadding;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF101010),
    );
    final renderedSize = _presentationSize(presentationPadding) * scale;
    canvas.save();
    canvas.translate(
      (size.width - renderedSize.width) / 2,
      (size.height - renderedSize.height) / 2,
    );
    if (!leftToRight) {
      canvas.translate(renderedSize.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.scale(scale);
    canvas.translate(presentationPadding.dx, presentationPadding.dy);
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
      old.scale != scale ||
      old.presentationPadding != presentationPadding;
}
