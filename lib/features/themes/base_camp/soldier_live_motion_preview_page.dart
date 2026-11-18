import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/device_settings_controller.dart';
import '../../../core/widgets/operation_button.dart';
import 'base_camp_soldier_motion.dart';
import 'base_camp_soldier_pixelation.dart';

enum SoldierLivePreviewMode { breathingOnly, rifleOnly, overlay }

class SoldierLiveMotionPreviewPage extends StatefulWidget {
  const SoldierLiveMotionPreviewPage({
    super.key,
    this.alignmentController,
    this.dashboardViewport,
  });

  final BaseCampRifleAlignmentController? alignmentController;
  final Size? dashboardViewport;

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
  bool _pixelPreparing = false;
  Object? _pixelFailure;
  int _pixelSelectionGeneration = 0;
  Timer? _pixelProfileDebounce;
  Size? _previewViewport;
  Size? _pixelProfileViewport;
  double? _pixelProfileDevicePixelRatio;
  BaseCampRifleGlobalAlignment? _pixelProfileAlignment;
  BaseCampSoldierPixelProfile? _pixelProfile;

  BaseCampRifleAlignmentController get _alignmentController =>
      widget.alignmentController ?? baseCampRifleGlobalAlignment;

  BaseCampSoldierPixelProfile _profileFor(
    Size viewport,
    BaseCampRifleGlobalAlignment alignment,
  ) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    if (_pixelProfile != null &&
        _pixelProfileViewport == viewport &&
        _pixelProfileDevicePixelRatio == devicePixelRatio &&
        identical(_pixelProfileAlignment, alignment)) {
      return _pixelProfile!;
    }
    _pixelProfileViewport = viewport;
    _pixelProfileDevicePixelRatio = devicePixelRatio;
    _pixelProfileAlignment = alignment;
    return _pixelProfile = baseCampSoldierPixelProfile(
      viewport: viewport,
      devicePixelRatio: devicePixelRatio,
      globalX: alignment.x,
      globalY: alignment.y,
      globalScale: alignment.scale,
      frameOffsets: alignment.frameOffsets,
      frameScales: alignment.frameScales,
      verticalScaleX: alignment.verticalScaleX,
      horizontalScaleY: alignment.horizontalScaleY,
    );
  }

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
    final level =
        DeviceSettingsController.instance.value.soldierPixelationLevel;
    if (level != SoldierPixelationLevel.original) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_preparePixelLevel(level));
      });
    }
  }

  @override
  void dispose() {
    _pixelProfileDebounce?.cancel();
    final level =
        DeviceSettingsController.instance.value.soldierPixelationLevel;
    if (level != SoldierPixelationLevel.original) {
      final applied = _alignmentController.value;
      final viewport = widget.dashboardViewport;
      if (viewport != null && !viewport.isEmpty) {
        final profile = baseCampSoldierPixelProfile(
          viewport: viewport,
          devicePixelRatio: _pixelProfileDevicePixelRatio ?? 1,
          globalX: applied.x,
          globalY: applied.y,
          globalScale: applied.scale,
          frameOffsets: applied.frameOffsets,
          frameScales: applied.frameScales,
          verticalScaleX: applied.verticalScaleX,
          horizontalScaleY: applied.horizontalScaleY,
        );
        unawaited(
          BaseCampSoldierPixelCache.instance.prepareRequests(
            profile.requests,
            level,
          ),
        );
      }
    }
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

  Future<void> _selectPixelLevel(SoldierPixelationLevel level) async {
    final cache = BaseCampSoldierPixelCache.instance;
    cache.selectLevel(level);
    final settings = DeviceSettingsController.instance;
    settings.update(settings.value.copyWith(soldierPixelationLevel: level));
    await _preparePixelLevel(level);
  }

  Future<void> _preparePixelLevel(SoldierPixelationLevel level) async {
    final generation = ++_pixelSelectionGeneration;
    if (level == SoldierPixelationLevel.original) {
      BaseCampSoldierPixelCache.instance.selectLevel(level);
      if (mounted) {
        setState(() {
          _pixelPreparing = false;
          _pixelFailure = null;
        });
      }
      return;
    }
    final viewport = _previewViewport;
    if (viewport == null || viewport.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && generation == _pixelSelectionGeneration) {
          unawaited(_preparePixelLevel(level));
        }
      });
      return;
    }
    final profile = _profileFor(viewport, _working);
    setState(() {
      _pixelPreparing = true;
      _pixelFailure = null;
    });
    final prepared = await BaseCampSoldierPixelCache.instance.prepareRequests(
      profile.requests,
      level,
    );
    if (!mounted || generation != _pixelSelectionGeneration) return;
    setState(() {
      _pixelPreparing = false;
      _pixelFailure = prepared
          ? null
          : BaseCampSoldierPixelCache.instance.lastFailure ??
                StateError('Pixel profile preparation cancelled');
    });
  }

  void _schedulePixelProfilePreparation() {
    _pixelProfileDebounce?.cancel();
    final level =
        DeviceSettingsController.instance.value.soldierPixelationLevel;
    if (level == SoldierPixelationLevel.original) return;
    _pixelProfileDebounce = Timer(
      const Duration(milliseconds: 150),
      () => unawaited(_preparePixelLevel(level)),
    );
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
      _schedulePixelProfilePreparation();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('INVALID ALIGNMENT JSON')));
      }
    }
  }

  void _reloadReference() {
    setState(() {
      _working = const BaseCampRifleGlobalAlignment();
      _event.duration = Duration(milliseconds: _working.eventDurationMs);
    });
    _schedulePixelProfilePreparation();
  }

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
            child: LayoutBuilder(
              builder: (context, previewConstraints) {
                _previewViewport = previewConstraints.biggest;
                final pixelProfile = _profileFor(
                  previewConstraints.biggest,
                  _working,
                );
                return DecoratedBox(
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
                          pixelProfile: pixelProfile,
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
                          pixelProfile: pixelProfile,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text('PHASE: ${phase.name.toUpperCase()}'),
          const SizedBox(height: 8),
          ValueListenableBuilder<DeviceSettings>(
            valueListenable: DeviceSettingsController.instance,
            builder: (context, settings, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SegmentedButton<SoldierPixelationLevel>(
                  key: const ValueKey('soldier-live-pixel-level-controls'),
                  segments: const <ButtonSegment<SoldierPixelationLevel>>[
                    ButtonSegment<SoldierPixelationLevel>(
                      value: SoldierPixelationLevel.original,
                      label: Text('PIXEL LV.0'),
                    ),
                    ButtonSegment<SoldierPixelationLevel>(
                      value: SoldierPixelationLevel.fine,
                      label: Text('PIXEL LV.1'),
                    ),
                    ButtonSegment<SoldierPixelationLevel>(
                      value: SoldierPixelationLevel.medium,
                      label: Text('PIXEL LV.2'),
                    ),
                    ButtonSegment<SoldierPixelationLevel>(
                      value: SoldierPixelationLevel.coarse,
                      label: Text('PIXEL LV.3'),
                    ),
                    ButtonSegment<SoldierPixelationLevel>(
                      value: SoldierPixelationLevel.extreme,
                      label: Text('PIXEL LV.4'),
                    ),
                  ],
                  selected: <SoldierPixelationLevel>{
                    settings.soldierPixelationLevel,
                  },
                  showSelectedIcon: false,
                  expandedInsets: EdgeInsets.zero,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
                      EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                  onSelectionChanged: (selection) =>
                      unawaited(_selectPixelLevel(selection.single)),
                ),
                if (_pixelPreparing)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'PREPARING SELECTED PIXEL LEVEL...',
                      key: ValueKey('soldier-live-pixel-preparing'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_pixelFailure != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'PIXEL PREPARATION FAILED — ORIGINAL DISPLAY RETAINED',
                      key: ValueKey('soldier-live-pixel-failure'),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
          _slider('GLOBAL SCALE', _working.scale, .5, 1.5, (value) {
            _working = _working.copyWith(scale: value);
            _schedulePixelProfilePreparation();
          }),
          _slider('SCALE X — VERTICAL', _working.verticalScaleX, .5, 1.5, (
            value,
          ) {
            _working = _working.copyWith(verticalScaleX: value);
            _schedulePixelProfilePreparation();
          }, divisions: 100),
          _slider('SCALE Y — HORIZONTAL', _working.horizontalScaleY, .5, 1.5, (
            value,
          ) {
            _working = _working.copyWith(horizontalScaleY: value);
            _schedulePixelProfilePreparation();
          }, divisions: 100),
          OperationButton(
            key: const ValueKey('soldier-live-trigger-regrip'),
            text: 'TRIGGER REGRIP',
            icon: Icons.play_arrow,
            role: OperationActionRole.primary,
            onPressed: active || _pixelPreparing || _pixelFailure != null
                ? null
                : _trigger,
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
