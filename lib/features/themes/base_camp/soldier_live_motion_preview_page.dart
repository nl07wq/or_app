import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/operation_button.dart';
import 'base_camp_soldier_motion.dart';

enum SoldierLivePreviewMode { breathingOnly, rifleOnly, overlay }

class SoldierLiveMotionPreviewPage extends StatefulWidget {
  const SoldierLiveMotionPreviewPage({super.key, this.alignmentController});

  final BaseCampRifleAlignmentController? alignmentController;

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
  BaseCampRifleGlobalAlignment _working = const BaseCampRifleGlobalAlignment();
  bool _loading = true;
  bool _applying = false;

  BaseCampRifleAlignmentController get _alignmentController =>
      widget.alignmentController ?? baseCampRifleGlobalAlignment;

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
          duration: Duration(milliseconds: _working.eventDurationMs),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _event.value = 0;
            _breathing.repeat();
            setState(() {});
          }
        });
    _loadAppliedAlignment();
  }

  Future<void> _loadAppliedAlignment() async {
    await _alignmentController.load();
    if (!mounted) return;
    setState(() {
      _working = _alignmentController.value;
      _event.duration = Duration(milliseconds: _working.eventDurationMs);
      _loading = false;
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
    _event.duration = Duration(milliseconds: _working.eventDurationMs);
    _breathing
      ..stop()
      ..value = 0;
    _event.forward(from: 0);
    setState(() {});
  }

  Map<String, Object?> _json() => _working.toJson();

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
      final imported = BaseCampRifleGlobalAlignment.fromJson(decoded);
      setState(() {
        _working = imported;
        _event.duration = Duration(milliseconds: _working.eventDurationMs);
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
    _working = const BaseCampRifleGlobalAlignment();
    _event.duration = Duration(milliseconds: _working.eventDurationMs);
  });

  Future<void> _apply() async {
    if (_applying) return;
    setState(() => _applying = true);
    try {
      await _alignmentController.save(_working);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SAVED AND APPLIED TO DASHBOARD')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('APPLY FAILED — EDITED VALUES RETAINED')),
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SOLDIER LIVE MOTION PREVIEW')),
    body: SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    ),
  );

  Widget _buildBody() => AnimatedBuilder(
    animation: Listenable.merge(<Listenable>[_breathing, _event]),
    builder: (context, _) {
      final active = _event.isAnimating;
      final elapsed = (_event.value * _working.eventDurationMs).floor();
      final phase = active
          ? baseCampRifleRegripPhase(
              elapsed,
              frameDurations: _working.frameDurationsMs,
            )
          : BaseCampRifleRegripPhase.breathing;
      final frame = phase == BaseCampRifleRegripPhase.rifleRegrip
          ? baseCampRifleRegripFrameIndex(
              elapsed,
              frameDurations: _working.frameDurationsMs,
            )
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
                          : baseCampBreathingOffset(_breathing.value * 2400),
                      opacity:
                          _mode == SoldierLivePreviewMode.overlay && showRifle
                          ? .5
                          : 1,
                    ),
                  if (showRifle)
                    BaseCampRifleRegripFrame(
                      key: ValueKey('soldier-live-rifle-frame-$frame'),
                      frame: frame,
                      globalX: _working.x,
                      globalY: _working.y,
                      globalScale: _working.scale,
                      verticalScaleX: _working.verticalScaleX,
                      horizontalScaleY: _working.horizontalScaleY,
                      frameOffsets: _working.frameOffsets,
                      frameScales: _working.frameScales,
                      brightness: _working.brightness,
                      contrast: _working.contrast,
                      saturation: _working.saturation,
                      warmth: _working.warmth,
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
            onSelectionChanged: (value) => setState(() => _mode = value.single),
          ),
          _slider(
            'GLOBAL X',
            _working.x,
            -100,
            100,
            (value) => _working = _working.copyWith(x: value),
          ),
          _slider(
            'GLOBAL Y',
            _working.y,
            -100,
            100,
            (value) => _working = _working.copyWith(y: value),
          ),
          _slider(
            'GLOBAL SCALE',
            _working.scale,
            .5,
            1.5,
            (value) => _working = _working.copyWith(scale: value),
          ),
          _slider(
            'SCALE X — VERTICAL',
            _working.verticalScaleX,
            .5,
            1.5,
            (value) => _working = _working.copyWith(verticalScaleX: value),
            divisions: 100,
          ),
          _slider(
            'SCALE Y — HORIZONTAL',
            _working.horizontalScaleY,
            .5,
            1.5,
            (value) => _working = _working.copyWith(horizontalScaleY: value),
            divisions: 100,
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
            text: _applying ? 'APPLYING...' : 'APPLY TO DASHBOARD',
            icon: Icons.publish,
            onPressed: _applying ? null : _apply,
          ),
        ],
      );
    },
  );

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> assign, {
    int? divisions,
  }) => Row(
    children: [
      SizedBox(width: 112, child: Text(label)),
      Expanded(
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: (next) => setState(() => assign(next)),
        ),
      ),
      SizedBox(width: 62, child: Text(value.toStringAsFixed(3))),
    ],
  );
}
