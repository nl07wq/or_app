import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/operation_button.dart';
import 'base_camp_soldier_motion.dart';

enum SoldierLivePreviewMode { breathingOnly, rifleOnly, overlay }

class SoldierLiveMotionPreviewPage extends StatefulWidget {
  const SoldierLiveMotionPreviewPage({super.key});

  @override
  State<SoldierLiveMotionPreviewPage> createState() =>
      _SoldierLiveMotionPreviewPageState();
}

class _SoldierLiveMotionPreviewPageState
    extends State<SoldierLiveMotionPreviewPage>
    with TickerProviderStateMixin {
  late final AnimationController _breathing;
  late final AnimationController _event;
  SoldierLivePreviewMode _mode = SoldierLivePreviewMode.overlay;
  double _x = baseCampApprovedRifleGlobalX;
  double _y = baseCampApprovedRifleGlobalY;
  double _scale = baseCampApprovedRifleGlobalScale;

  @override
  void initState() {
    super.initState();
    _breathing = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _event =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: baseCampRifleRegripEventMs),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _event.value = 0;
            _breathing.repeat();
            setState(() {});
          }
        });
  }

  @override
  void dispose() {
    _breathing.dispose();
    _event.dispose();
    super.dispose();
  }

  void _trigger() {
    if (_event.isAnimating) return;
    _breathing
      ..stop()
      ..value = 0;
    _event.forward(from: 0);
    setState(() {});
  }

  Map<String, Object?> _json() => <String, Object?>{
    'schema': 'soldier_alignment_v2',
    'reference': 'breathing_soldier',
    'target': 'rifle_regrip',
    'sourceCanvasPx': <int>[512, 512],
    'drawingAnchor': 'normal_visible_foot_center',
    'frameOffsetsPx': <Object?>[
      for (
        var frame = 0;
        frame < baseCampApprovedRifleFrameOffsets.length;
        frame++
      )
        <String, Object?>{
          'frame': frame,
          'x': baseCampApprovedRifleFrameOffsets[frame].dx,
          'y': baseCampApprovedRifleFrameOffsets[frame].dy,
          'scale': baseCampApprovedRifleFrameScales[frame],
        },
    ],
    'alignment': <String, double>{
      'offsetXdp': _x,
      'offsetYdp': _y,
      'scale': _scale,
    },
    'color': const <String, double>{
      'brightness': 0,
      'contrast': 1,
      'saturation': 1,
      'warmth': 0,
    },
    'frameDurationsMs': baseCampRifleRegripFrameDurations,
  };

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(text: const JsonEncoder.withIndent('  ').convert(_json())),
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ALIGNMENT JSON COPIED')));
    }
  }

  Future<void> _import() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('IMPORT ALIGNMENT JSON'),
        content: TextField(
          key: const ValueKey('soldier-live-import-field'),
          controller: controller,
          maxLines: 12,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('IMPORT'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null) return;
    try {
      final decoded = jsonDecode(text);
      final alignment = decoded is Map ? decoded['alignment'] : null;
      final offsets = decoded is Map ? decoded['frameOffsetsPx'] : null;
      final durations = decoded is Map ? decoded['frameDurationsMs'] : null;
      if (decoded is! Map ||
          decoded['schema'] != 'soldier_alignment_v2' ||
          decoded['drawingAnchor'] != 'normal_visible_foot_center' ||
          alignment is! Map ||
          offsets is! List ||
          offsets.length != 6 ||
          durations is! List ||
          durations.join(',') != baseCampRifleRegripFrameDurations.join(',')) {
        throw const FormatException();
      }
      final x = (alignment['offsetXdp'] as num).toDouble();
      final y = (alignment['offsetYdp'] as num).toDouble();
      final scale = (alignment['scale'] as num).toDouble();
      if (!x.isFinite ||
          !y.isFinite ||
          !scale.isFinite ||
          x.abs() > 100 ||
          y.abs() > 100 ||
          scale < .5 ||
          scale > 1.5) {
        throw const FormatException();
      }
      setState(() {
        _x = x;
        _y = y;
        _scale = scale;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('INVALID ALIGNMENT JSON')));
      }
    }
  }

  void _reloadReference() => setState(() {
    _x = baseCampApprovedRifleGlobalX;
    _y = baseCampApprovedRifleGlobalY;
    _scale = baseCampApprovedRifleGlobalScale;
  });

  void _apply() {
    baseCampRifleGlobalAlignment.value = BaseCampRifleGlobalAlignment(
      x: _x,
      y: _y,
      scale: _scale,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('APPLIED TO DASHBOARD FOR THIS SESSION')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SOLDIER LIVE MOTION PREVIEW')),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_breathing, _event]),
        builder: (context, _) {
          final active = _event.isAnimating;
          final elapsed = (_event.value * baseCampRifleRegripEventMs).floor();
          final phase = active
              ? baseCampRifleRegripPhase(elapsed)
              : BaseCampRifleRegripPhase.breathing;
          final frame = phase == BaseCampRifleRegripPhase.rifleRegrip
              ? baseCampRifleRegripFrameIndex(elapsed)
              : phase == BaseCampRifleRegripPhase.postIdle
              ? 5
              : 0;
          final showRifle = active
              ? _mode != SoldierLivePreviewMode.breathingOnly &&
                    (phase == BaseCampRifleRegripPhase.rifleRegrip ||
                        phase == BaseCampRifleRegripPhase.postIdle)
              : _mode == SoldierLivePreviewMode.rifleOnly;
          final showBreathing =
              _mode != SoldierLivePreviewMode.rifleOnly &&
              (!active ||
                  _mode == SoldierLivePreviewMode.overlay ||
                  phase == BaseCampRifleRegripPhase.preIdle);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AspectRatio(
                aspectRatio: 1.35,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xff161b12),
                    border: Border.all(color: const Color(0xff718268)),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.hardEdge,
                    children: [
                      if (showBreathing)
                        BaseCampBreathingSoldier(
                          dy: active
                              ? 0
                              : baseCampBreathingOffset(
                                  _breathing.value * 2400,
                                ),
                          opacity:
                              _mode == SoldierLivePreviewMode.overlay &&
                                  showRifle
                              ? .5
                              : 1,
                        ),
                      if (showRifle)
                        BaseCampRifleRegripFrame(
                          key: ValueKey('soldier-live-rifle-frame-$frame'),
                          frame: frame,
                          globalX: _x,
                          globalY: _y,
                          globalScale: _scale,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('PHASE: ${phase.name.toUpperCase()}'),
              SegmentedButton<SoldierLivePreviewMode>(
                segments: const <ButtonSegment<SoldierLivePreviewMode>>[
                  ButtonSegment(
                    value: SoldierLivePreviewMode.breathingOnly,
                    label: Text('BREATHING ONLY'),
                  ),
                  ButtonSegment(
                    value: SoldierLivePreviewMode.rifleOnly,
                    label: Text('RIFLE ONLY'),
                  ),
                  ButtonSegment(
                    value: SoldierLivePreviewMode.overlay,
                    label: Text('OVERLAY'),
                  ),
                ],
                selected: <SoldierLivePreviewMode>{_mode},
                onSelectionChanged: (value) =>
                    setState(() => _mode = value.single),
              ),
              _slider('GLOBAL X', _x, -100, 100, (value) => _x = value),
              _slider('GLOBAL Y', _y, -100, 100, (value) => _y = value),
              _slider(
                'GLOBAL SCALE',
                _scale,
                .5,
                1.5,
                (value) => _scale = value,
              ),
              OperationButton(
                key: const ValueKey('soldier-live-trigger-regrip'),
                text: 'TRIGGER REGRIP',
                icon: Icons.play_arrow,
                role: OperationActionRole.primary,
                onPressed: active ? null : _trigger,
              ),
              OperationButton(
                key: const ValueKey('soldier-live-copy-json'),
                text: 'COPY JSON',
                icon: Icons.copy,
                onPressed: _copy,
              ),
              OperationButton(
                key: const ValueKey('soldier-live-import-json'),
                text: 'IMPORT JSON',
                icon: Icons.upload_file,
                onPressed: _import,
              ),
              OperationButton(
                key: const ValueKey('soldier-live-reference-reload'),
                text: 'REFERENCE RELOAD',
                icon: Icons.restart_alt,
                onPressed: _reloadReference,
              ),
              OperationButton(
                key: const ValueKey('soldier-live-apply-dashboard'),
                text: 'APPLY TO DASHBOARD (SESSION)',
                icon: Icons.publish,
                onPressed: _apply,
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> assign,
  ) => Row(
    children: [
      SizedBox(width: 112, child: Text(label)),
      Expanded(
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: (next) => setState(() => assign(next)),
        ),
      ),
      SizedBox(width: 62, child: Text(value.toStringAsFixed(3))),
    ],
  );
}
