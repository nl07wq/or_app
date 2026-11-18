import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:or_app/core/services/system_diagnostics.dart';
import 'package:or_app/features/themes/base_camp/base_camp_helicopter_configuration.dart';

const baseCampHelicopterBodyAsset = 'assets/base_camp/helicopter/body.png';

const baseCampHelicopterMainRotorAssets = <String>[
  'assets/base_camp/helicopter/main_rotor/frame_01.png',
  'assets/base_camp/helicopter/main_rotor/frame_02.png',
  'assets/base_camp/helicopter/main_rotor/frame_03.png',
  'assets/base_camp/helicopter/main_rotor/frame_04.png',
  'assets/base_camp/helicopter/main_rotor/frame_05.png',
  'assets/base_camp/helicopter/main_rotor/frame_06.png',
];

const baseCampHelicopterTailRotorAssets = <String>[
  'assets/base_camp/helicopter/tail_rotor/frame_01.png',
  'assets/base_camp/helicopter/tail_rotor/frame_02.png',
  'assets/base_camp/helicopter/tail_rotor/frame_03.png',
  'assets/base_camp/helicopter/tail_rotor/frame_04.png',
  'assets/base_camp/helicopter/tail_rotor/frame_05.png',
  'assets/base_camp/helicopter/tail_rotor/frame_06.png',
  'assets/base_camp/helicopter/tail_rotor/frame_07.png',
  'assets/base_camp/helicopter/tail_rotor/frame_08.png',
  'assets/base_camp/helicopter/tail_rotor/frame_09.png',
  'assets/base_camp/helicopter/tail_rotor/frame_10.png',
  'assets/base_camp/helicopter/tail_rotor/frame_11.png',
  'assets/base_camp/helicopter/tail_rotor/frame_12.png',
  'assets/base_camp/helicopter/tail_rotor/frame_13.png',
  'assets/base_camp/helicopter/tail_rotor/frame_14.png',
  'assets/base_camp/helicopter/tail_rotor/frame_15.png',
  'assets/base_camp/helicopter/tail_rotor/frame_16.png',
];

const baseCampHelicopterAssets = <String>[
  baseCampHelicopterBodyAsset,
  ...baseCampHelicopterMainRotorAssets,
  ...baseCampHelicopterTailRotorAssets,
];

enum BaseCampHelicopterDirection { leftToRight, rightToLeft }

/// Prevents the Dashboard scheduler from competing with MAP EDITOR previews.
final ValueNotifier<bool> baseCampHelicopterEditorActive = ValueNotifier<bool>(
  false,
);

@immutable
class BaseCampHelicopterSchedule {
  const BaseCampHelicopterSchedule({
    this.firstDelayMin = const Duration(seconds: 10),
    this.firstDelayMax = const Duration(seconds: 25),
    this.laterDelayMin = const Duration(seconds: 20),
    this.laterDelayMax = const Duration(seconds: 50),
    this.flightDurationMin = const Duration(seconds: 7),
    this.flightDurationMax = const Duration(seconds: 10),
  });

  final Duration firstDelayMin;
  final Duration firstDelayMax;
  final Duration laterDelayMin;
  final Duration laterDelayMax;
  final Duration flightDurationMin;
  final Duration flightDurationMax;

  Duration firstDelay(math.Random random) =>
      _randomDuration(random, firstDelayMin, firstDelayMax);

  Duration laterDelay(math.Random random) =>
      _randomDuration(random, laterDelayMin, laterDelayMax);

  Duration flightDuration(math.Random random) =>
      _randomDuration(random, flightDurationMin, flightDurationMax);
}

Duration _randomDuration(
  math.Random random,
  Duration minimum,
  Duration maximum,
) {
  assert(!maximum.isNegative && !minimum.isNegative);
  assert(maximum >= minimum);
  final span = maximum.inMilliseconds - minimum.inMilliseconds;
  if (span == 0) return minimum;
  return Duration(
    milliseconds: minimum.inMilliseconds + random.nextInt(span + 1),
  );
}

BaseCampHelicopterDirection baseCampHelicopterRandomDirection(
  math.Random random,
) => random.nextBool()
    ? BaseCampHelicopterDirection.leftToRight
    : BaseCampHelicopterDirection.rightToLeft;

double baseCampHelicopterLeft({
  required double progress,
  required double viewportWidth,
  required double spriteWidth,
  required BaseCampHelicopterDirection direction,
}) {
  final normalized = progress.clamp(0.0, 1.0);
  final start = direction == BaseCampHelicopterDirection.leftToRight
      ? -spriteWidth
      : viewportWidth;
  final end = direction == BaseCampHelicopterDirection.leftToRight
      ? viewportWidth
      : -spriteWidth;
  return start + (end - start) * normalized;
}

int baseCampHelicopterFrameIndex({
  required Duration elapsed,
  required int frameDurationMs,
  required int frameCount,
}) => (elapsed.inMilliseconds ~/ frameDurationMs) % frameCount;

typedef BaseCampHelicopterAssetLoader =
    Future<void> Function(BuildContext context, List<String> assets);

typedef BaseCampHelicopterEventRecorder =
    void Function(String category, String event, Map<String, Object?> fields);

/// A single, input-transparent ambient flyby scoped to the BASE CAMP map.
///
/// Nothing is scheduled or decoded until [dashboardInteractive] becomes true.
/// The decoded Flutter image-cache entries are then reused by every later pass.
class BaseCampHelicopterFlybyLayer extends StatefulWidget {
  const BaseCampHelicopterFlybyLayer({
    super.key,
    required this.dashboardInteractive,
    this.schedule = const BaseCampHelicopterSchedule(),
    this.random,
    this.assetLoader,
    this.eventRecorder,
    this.debugFlight,
    this.assembly = BaseCampHelicopterAssembly.defaults,
  });

  final ValueListenable<bool> dashboardInteractive;
  final BaseCampHelicopterSchedule schedule;
  final math.Random? random;
  final BaseCampHelicopterAssetLoader? assetLoader;
  final BaseCampHelicopterEventRecorder? eventRecorder;
  final BaseCampHelicopterAssembly assembly;

  @visibleForTesting
  final BaseCampHelicopterDebugFlight? debugFlight;

  @override
  State<BaseCampHelicopterFlybyLayer> createState() =>
      _BaseCampHelicopterFlybyLayerState();
}

@immutable
class BaseCampHelicopterDebugFlight {
  const BaseCampHelicopterDebugFlight({
    required this.progress,
    required this.direction,
    this.altitudeFactor = .1,
    this.mainRotorFrame = 0,
    this.tailRotorFrame = 0,
  });

  final double progress;
  final BaseCampHelicopterDirection direction;
  final double altitudeFactor;
  final int mainRotorFrame;
  final int tailRotorFrame;
}

class _BaseCampHelicopterFlybyLayerState
    extends State<BaseCampHelicopterFlybyLayer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final math.Random _random;
  late final AnimationController _flightController;
  late final AnimationController _rotorController;
  Timer? _spawnTimer;
  bool _appResumed = true;
  bool _motionAllowed = true;
  bool _assetsReady = false;
  bool _assetLoadStarted = false;
  bool _disabledAfterFailure = false;
  bool _active = false;
  bool _hasCompletedFlight = false;
  int _loadGeneration = 0;
  double _altitudeFactor = .1;
  BaseCampHelicopterDirection _direction =
      BaseCampHelicopterDirection.leftToRight;

  BaseCampHelicopterEventRecorder get _record =>
      widget.eventRecorder ?? _recordSystemDiagnostic;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appResumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _random = widget.random ?? math.Random();
    _flightController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..addStatusListener(_handleFlightStatus);
    _rotorController = AnimationController(
      vsync: this,
      // One bounded ticker drives both independently configured rotors. The
      // long period keeps elapsed time monotonic for a complete visible pass.
      duration: const Duration(days: 1),
    );
    widget.dashboardInteractive.addListener(_handleInteractiveChanged);
    baseCampHelicopterEditorActive.addListener(_handleEditorActiveChanged);
    if (widget.dashboardInteractive.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleNext(first: true);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final allowed =
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (_motionAllowed == allowed) return;
    _motionAllowed = allowed;
    if (!allowed) {
      _spawnTimer?.cancel();
      _flightController.stop(canceled: false);
      _rotorController.stop(canceled: false);
    } else if (_appResumed && widget.dashboardInteractive.value) {
      if (_active) {
        _flightController.forward();
        _rotorController.repeat();
      } else {
        _scheduleNext(first: !_hasCompletedFlight);
      }
    }
  }

  void _handleInteractiveChanged() {
    if (!widget.dashboardInteractive.value) {
      _spawnTimer?.cancel();
      return;
    }
    _scheduleNext(first: !_hasCompletedFlight);
  }

  void _handleEditorActiveChanged() {
    if (baseCampHelicopterEditorActive.value) {
      _spawnTimer?.cancel();
      _flightController.stop(canceled: false);
      _rotorController.stop(canceled: false);
      if (_active && mounted) setState(() => _active = false);
      return;
    }
    if (_appResumed && _motionAllowed && widget.dashboardInteractive.value) {
      _scheduleNext(first: true);
    }
  }

  void _scheduleNext({required bool first}) {
    if (!mounted ||
        widget.debugFlight != null ||
        !widget.dashboardInteractive.value ||
        !_appResumed ||
        !_motionAllowed ||
        baseCampHelicopterEditorActive.value ||
        _disabledAfterFailure ||
        _active) {
      return;
    }
    _spawnTimer?.cancel();
    final delay = first
        ? widget.schedule.firstDelay(_random)
        : widget.schedule.laterDelay(_random);
    _spawnTimer = Timer(delay, () => unawaited(_beginFlight()));
  }

  Future<void> _beginFlight() async {
    _spawnTimer = null;
    if (!mounted ||
        !widget.dashboardInteractive.value ||
        !_appResumed ||
        !_motionAllowed ||
        baseCampHelicopterEditorActive.value ||
        _disabledAfterFailure ||
        _active) {
      return;
    }
    if (!_assetsReady && !await _prepareAssets()) return;
    if (!mounted || !_appResumed || !_motionAllowed) return;
    final duration = widget.schedule.flightDuration(_random);
    setState(() {
      _active = true;
      _direction = baseCampHelicopterRandomDirection(_random);
      _altitudeFactor = .06 + _random.nextDouble() * .1;
      _flightController.duration = duration;
    });
    _record('BASE_CAMP', 'HELICOPTER_SPAWN', <String, Object?>{
      'direction': _direction.name,
      'flightDurationMs': duration.inMilliseconds,
      'altitudeFactor': _altitudeFactor,
    });
    _rotorController
      ..value = 0
      ..repeat();
    _flightController.forward(from: 0);
  }

  Future<bool> _prepareAssets() async {
    if (_assetsReady) return true;
    if (_assetLoadStarted) return false;
    _assetLoadStarted = true;
    final generation = ++_loadGeneration;
    final watch = Stopwatch()..start();
    _record('ASSET', 'HELICOPTER_ASSET_LOAD_START', <String, Object?>{
      'assetCount': baseCampHelicopterAssets.length,
      'trigger': 'firstScheduledFlyby',
      'afterDashboardInteractive': widget.dashboardInteractive.value,
    });
    try {
      await (widget.assetLoader ?? _precacheHelicopterAssets)(
        context,
        baseCampHelicopterAssets,
      );
      if (!mounted || generation != _loadGeneration) return false;
      _assetsReady = true;
      _record('ASSET', 'HELICOPTER_ASSET_LOAD_SUCCESS', <String, Object?>{
        'assetCount': baseCampHelicopterAssets.length,
        'durationMs': watch.elapsedMilliseconds,
        'cachedForLaterFlybys': true,
      });
      return true;
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return false;
      _disabledAfterFailure = true;
      _record('ASSET', 'HELICOPTER_ASSET_LOAD_FAILURE', <String, Object?>{
        'assetCount': baseCampHelicopterAssets.length,
        'durationMs': watch.elapsedMilliseconds,
        'errorType': error.runtimeType.toString(),
        'flybyDisabled': true,
      });
      return false;
    } finally {
      if (generation == _loadGeneration) _assetLoadStarted = false;
    }
  }

  void _handleFlightStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_active || !mounted) return;
    _rotorController.stop();
    setState(() {
      _active = false;
      _hasCompletedFlight = true;
    });
    _record('BASE_CAMP', 'HELICOPTER_EXIT', <String, Object?>{
      'direction': _direction.name,
      'fullyOutsideMap': true,
    });
    _scheduleNext(first: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (_appResumed == resumed) return;
    _appResumed = resumed;
    if (!resumed) {
      _spawnTimer?.cancel();
      _flightController.stop(canceled: false);
      _rotorController.stop(canceled: false);
      return;
    }
    if (!_motionAllowed || !widget.dashboardInteractive.value) return;
    if (_active) {
      _flightController.forward();
      _rotorController.repeat();
    } else {
      _scheduleNext(first: !_hasCompletedFlight);
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _spawnTimer?.cancel();
    widget.dashboardInteractive.removeListener(_handleInteractiveChanged);
    baseCampHelicopterEditorActive.removeListener(_handleEditorActiveChanged);
    WidgetsBinding.instance.removeObserver(this);
    _flightController
      ..removeStatusListener(_handleFlightStatus)
      ..dispose();
    _rotorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debug = widget.debugFlight;
    if (!_active && debug == null) return const SizedBox.expand();
    return IgnorePointer(
      key: const ValueKey('base-camp-helicopter-ignore-pointer'),
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final spriteWidth =
                constraints.maxWidth * .42 * widget.assembly.globalScale;
            final spriteHeight =
                spriteWidth *
                BaseCampHelicopterSprite.sourceSize.height /
                BaseCampHelicopterSprite.sourceSize.width;
            final altitude =
                constraints.maxHeight *
                (debug?.altitudeFactor ?? _altitudeFactor);
            Widget flightAt(
              double progress,
              BaseCampHelicopterDirection direction,
              int mainFrame,
              int tailFrame,
            ) => Positioned(
              key: const ValueKey('base-camp-helicopter-positioned'),
              left: baseCampHelicopterLeft(
                progress: progress,
                viewportWidth: constraints.maxWidth,
                spriteWidth: spriteWidth,
                direction: direction,
              ),
              top: altitude,
              width: spriteWidth,
              height: spriteHeight,
              child: BaseCampHelicopterSprite(
                direction: direction,
                mainRotorFrame: mainFrame,
                tailRotorFrame: tailFrame,
                assembly: widget.assembly,
              ),
            );

            if (debug != null) {
              return Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  flightAt(
                    debug.progress,
                    debug.direction,
                    debug.mainRotorFrame,
                    debug.tailRotorFrame,
                  ),
                ],
              );
            }
            return AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[
                _flightController,
                _rotorController,
              ]),
              builder: (context, _) {
                final elapsedMs =
                    (_rotorController.value *
                            _rotorController.duration!.inMilliseconds)
                        .floor();
                final elapsed = Duration(milliseconds: elapsedMs);
                return Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    flightAt(
                      Curves.easeInOut.transform(_flightController.value),
                      _direction,
                      baseCampHelicopterFrameIndex(
                        elapsed: elapsed,
                        frameDurationMs: widget.assembly.mainFrameMs,
                        frameCount: baseCampHelicopterMainRotorAssets.length,
                      ),
                      baseCampHelicopterFrameIndex(
                        elapsed: elapsed,
                        frameDurationMs: widget.assembly.tailFrameMs,
                        frameCount: baseCampHelicopterTailRotorAssets.length,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class BaseCampHelicopterSprite extends StatelessWidget {
  const BaseCampHelicopterSprite({
    super.key,
    required this.direction,
    required this.mainRotorFrame,
    required this.tailRotorFrame,
    this.assembly = BaseCampHelicopterAssembly.defaults,
    this.showMainRotor = true,
    this.showTailRotor = true,
  });

  static const sourceSize = BaseCampHelicopterAssembly.sourceSize;

  // Anchors are expressed once in the body canvas. Rotor frames are centered
  // on their own measured hubs, so every frame shares exactly the same mount.
  static const mainRotorHubOnBody = Offset(772, 273);
  static const mainRotorHubInFrame = Offset(359.5, 170);
  static const tailRotorHubOnBody = Offset(1250, 484);
  static const tailRotorHubInFrame = Offset(210, 210);
  static const tailRotorScale = .5;
  static const mainRotorSize = Size(719, 358);
  static const tailRotorSize = Size(420, 420);

  final BaseCampHelicopterDirection direction;
  final int mainRotorFrame;
  final int tailRotorFrame;
  final BaseCampHelicopterAssembly assembly;
  final bool showMainRotor;
  final bool showTailRotor;

  @override
  Widget build(BuildContext context) => Transform.flip(
    key: const ValueKey('base-camp-helicopter-direction-transform'),
    flipX: direction == BaseCampHelicopterDirection.leftToRight,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / sourceSize.width;
        final mainLeft =
            (assembly.mainHub.dx -
                mainRotorHubInFrame.dx * assembly.mainScale) *
            scale;
        final mainTop =
            (assembly.mainHub.dy -
                mainRotorHubInFrame.dy * assembly.mainScale) *
            scale;
        final tailWidth = tailRotorSize.width * assembly.tailScale * scale;
        final tailHeight = tailRotorSize.height * assembly.tailScale * scale;
        final tailLeft =
            (assembly.tailHub.dx -
                tailRotorHubInFrame.dx * assembly.tailScale) *
            scale;
        final tailTop =
            (assembly.tailHub.dy -
                tailRotorHubInFrame.dy * assembly.tailScale) *
            scale;
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: <Widget>[
            Image.asset(
              baseCampHelicopterBodyAsset,
              key: const ValueKey('base-camp-helicopter-body'),
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
              gaplessPlayback: true,
            ),
            if (showMainRotor)
              Positioned(
                left: mainLeft,
                top: mainTop,
                width: mainRotorSize.width * assembly.mainScale * scale,
                height: mainRotorSize.height * assembly.mainScale * scale,
                child: Image.asset(
                  baseCampHelicopterMainRotorAssets[mainRotorFrame %
                      baseCampHelicopterMainRotorAssets.length],
                  key: const ValueKey('base-camp-helicopter-main-rotor'),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                  gaplessPlayback: true,
                ),
              ),
            if (showTailRotor)
              Positioned(
                left: tailLeft,
                top: tailTop,
                width: tailWidth,
                height: tailHeight,
                child: Image.asset(
                  baseCampHelicopterTailRotorAssets[tailRotorFrame %
                      baseCampHelicopterTailRotorAssets.length],
                  key: const ValueKey('base-camp-helicopter-tail-rotor'),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                  gaplessPlayback: true,
                ),
              ),
          ],
        );
      },
    ),
  );
}

Future<void> _precacheHelicopterAssets(
  BuildContext context,
  List<String> assets,
) async {
  for (var index = 0; index < assets.length; index++) {
    if (!context.mounted) {
      throw StateError('Helicopter asset owner was disposed during preload');
    }
    await precacheImage(AssetImage(assets[index]), context);
    if ((index + 1) % 4 == 0) await Future<void>.value();
  }
}

void _recordSystemDiagnostic(
  String category,
  String event,
  Map<String, Object?> fields,
) {
  SystemDiagnostics.instance.record(category, event, fields: fields);
}
