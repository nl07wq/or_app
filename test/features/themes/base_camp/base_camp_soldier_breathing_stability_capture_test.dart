import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/features/themes/base_camp/base_camp_soldier_motion.dart';
import 'package:or_app/features/themes/base_camp/base_camp_soldier_pixelation.dart';

const _captureDirectory = String.fromEnvironment(
  'SOLDIER_BREATHING_STABILITY_CAPTURE_DIR',
);
const _viewport = Size(360, 324);
const _baselinePhaseSteps = 64;

enum _ComparisonPath { currentPhaseDependent, fixedImage, physicalPixelAligned }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    BaseCampSoldierPixelCache.instance.resetForTesting();
    DeviceSettingsController.instance.resetForTesting(const DeviceSettings());
  });

  tearDown(BaseCampSoldierPixelCache.instance.resetForTesting);

  for (final dpr in <double>[1, 3]) {
    for (final level in <SoldierPixelationLevel>[
      SoldierPixelationLevel.original,
      SoldierPixelationLevel.fine,
      SoldierPixelationLevel.coarse,
      SoldierPixelationLevel.extreme,
    ]) {
      testWidgets(
        'captures A B C breathing comparison ${level.name} at DPR $dpr',
        (tester) async {
          tester.view.devicePixelRatio = dpr;
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.binding.setSurfaceSize(
            Size(_viewport.width * 3, _viewport.height + 32),
          );
          addTearDown(() => tester.binding.setSurfaceSize(null));

          DeviceSettingsController.instance.resetForTesting(
            DeviceSettings(breathingPixelLevel: level),
          );
          final experiment = _BreathingExperiment.create(
            viewport: _viewport,
            devicePixelRatio: dpr,
          );
          if (level != SoldierPixelationLevel.original) {
            await tester.runAsync(
              () => Future.wait(<Future<bool>>[
                BaseCampSoldierPixelCache.instance.prepareMotionRequests(
                  experiment.currentRequests,
                  BaseCampSoldierMotion.breathing,
                  level,
                ),
                BaseCampSoldierPixelCache.instance.prepareMotionRequests(
                  experiment.fixedRequests,
                  BaseCampSoldierMotion.breathing,
                  level,
                ),
                BaseCampSoldierPixelCache.instance.prepareMotionRequests(
                  experiment.alignedRequests,
                  BaseCampSoldierMotion.breathing,
                  level,
                ),
              ]),
            );
          }

          final boundaryKey = GlobalKey();
          final dy = ValueNotifier<double>(0);
          addTearDown(dy.dispose);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                backgroundColor: const Color(0xff273326),
                body: RepaintBoundary(
                  key: boundaryKey,
                  child: ValueListenableBuilder<double>(
                    valueListenable: dy,
                    builder: (context, value, _) => KeyedSubtree(
                      key: ValueKey<double>(value),
                      child: Row(
                        children: <Widget>[
                          for (final path in _ComparisonPath.values)
                            SizedBox(
                              width: _viewport.width,
                              child: _ComparisonCell(
                                label: switch (path) {
                                  _ComparisonPath.currentPhaseDependent =>
                                    'A · 65 PHASE',
                                  _ComparisonPath.fixedImage =>
                                    'B · FIXED IMAGE',
                                  _ComparisonPath.physicalPixelAligned =>
                                    'C · FIXED + PHYSICAL ALIGN',
                                },
                                child: _ExperimentalBreathingSoldier(
                                  experiment: experiment,
                                  path: path,
                                  dy: value,
                                  devicePixelRatio: dpr,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);

          for (var sample = 0; sample <= 36; sample++) {
            final elapsedMs = sample * 200.0;
            dy.value = baseCampBreathingOffset(elapsedMs);
            await tester.pump(const Duration(milliseconds: 16));
            await tester.pump(const Duration(milliseconds: 16));
            await _captureBoundary(
              tester,
              boundaryKey,
              'dpr${dpr.toInt()}_${level.name}_${sample.toString().padLeft(2, '0')}.png',
            );
          }
        },
      );
    }
  }

  testWidgets('captures corrected production breathing over three cycles', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(_viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const level = SoldierPixelationLevel.extreme;
    DeviceSettingsController.instance.resetForTesting(
      const DeviceSettings(breathingPixelLevel: level, regripPixelLevel: level),
    );
    final profile = baseCampSoldierPixelProfile(
      viewport: _viewport,
      devicePixelRatio: 3,
    );
    await tester.runAsync(
      () => BaseCampSoldierPixelCache.instance.prepareRequests(
        profile.requests,
        level,
      ),
    );

    final boundaryKey = GlobalKey();
    final dy = ValueNotifier<double>(0);
    addTearDown(dy.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: boundaryKey,
          child: ColoredBox(
            color: const Color(0xff273326),
            child: ValueListenableBuilder<double>(
              valueListenable: dy,
              builder: (context, value, _) => KeyedSubtree(
                key: ValueKey<double>(value),
                child: BaseCampBreathingSoldier(
                  dy: value,
                  pixelProfile: profile,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    for (var sample = 0; sample <= 36; sample++) {
      dy.value = baseCampBreathingOffset(sample * 200.0);
      await tester.pump(const Duration(milliseconds: 16));
      await _captureBoundary(
        tester,
        boundaryKey,
        'corrected_lv4_${sample.toString().padLeft(2, '0')}.png',
      );
    }

    expect(
      BaseCampSoldierPixelCache.instance.processedImageCount,
      baseCampSoldierPixelFrameCount,
    );
    expect(BaseCampSoldierPixelCache.instance.cachedImageCount, 8);
  });

  testWidgets('captures corrected upper lower boundary and regrip control', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(720, 324));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const level = SoldierPixelationLevel.extreme;
    DeviceSettingsController.instance.resetForTesting(
      const DeviceSettings(breathingPixelLevel: level, regripPixelLevel: level),
    );
    final profile = baseCampSoldierPixelProfile(
      viewport: _viewport,
      devicePixelRatio: 3,
    );
    await tester.runAsync(
      () => BaseCampSoldierPixelCache.instance.prepareRequests(
        profile.requests,
        level,
      ),
    );
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: boundaryKey,
          child: ColoredBox(
            color: const Color(0xff273326),
            child: Row(
              children: <Widget>[
                SizedBox.fromSize(
                  size: _viewport,
                  child: ClipRect(
                    child: Transform.scale(
                      scale: 1.8,
                      alignment: Alignment.center,
                      child: BaseCampBreathingSoldier(
                        dy: -.5,
                        pixelProfile: profile,
                      ),
                    ),
                  ),
                ),
                SizedBox.fromSize(
                  size: _viewport,
                  child: BaseCampRifleRegripFrame(
                    frame: 3,
                    pixelProfile: profile,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await _captureBoundary(
      tester,
      boundaryKey,
      'corrected_boundary_closeup_regrip_lv4.png',
    );
    expect(tester.takeException(), isNull);
  });

  test('phase-dependent processing changes the processed source image', () {
    final experiment = _BreathingExperiment.create(
      viewport: _viewport,
      devicePixelRatio: 3,
    );
    final first = experiment.currentUpperRequests.first;
    final adjacent = experiment.currentUpperRequests[1];
    final fixed = experiment.fixedUpper;

    expect(first.targetRect, isNot(adjacent.targetRect));
    expect(
      first.cacheKey(SoldierPixelationLevel.extreme),
      isNot(adjacent.cacheKey(SoldierPixelationLevel.extreme)),
    );
    expect(
      experiment.fixedUpperFor(-1),
      same(fixed),
      reason: 'fixed-image motion must not exchange the processed source',
    );
  });

  test('physical-pixel alignment introduces discrete translation plateaus', () {
    final smooth = <double>{};
    final dpr1 = <double>{};
    final dpr3 = <double>{};
    for (var sample = 0; sample <= 24; sample++) {
      final dy = baseCampBreathingOffset(sample * 100);
      smooth.add(dy);
      dpr1.add(_alignToPhysicalPixel(dy, 1));
      dpr3.add(_alignToPhysicalPixel(dy, 3));
    }
    expect(smooth.length, greaterThan(10));
    expect(dpr1.length, 2);
    expect(dpr3.length, 4);
  });
}

class _BreathingExperiment {
  const _BreathingExperiment({
    required this.currentLower,
    required this.currentUpperRequests,
    required this.fixedLower,
    required this.fixedUpper,
    required this.alignedLower,
    required this.alignedUpper,
  });

  factory _BreathingExperiment.create({
    required Size viewport,
    required double devicePixelRatio,
  }) {
    final released = baseCampSoldierPixelProfile(
      viewport: viewport,
      devicePixelRatio: devicePixelRatio,
    );
    final releasedLower = released.requestFor(
      baseCampBreathingSoldierLowerAsset,
    );
    final releasedUpper = released.requestFor(
      baseCampBreathingSoldierUpperAsset,
    );

    BaseCampSoldierPixelRequest copy({
      required BaseCampSoldierPixelRequest source,
      required String cacheId,
      required String profileKey,
      Rect? targetRect,
    }) => BaseCampSoldierPixelRequest(
      asset: source.asset,
      cacheId: cacheId,
      profileKey: profileKey,
      viewport: source.viewport,
      targetRect: targetRect ?? source.targetRect,
      sourceSize: source.sourceSize,
      devicePixelRatio: source.devicePixelRatio,
      density: source.density,
    );

    final currentUpperRequests = <BaseCampSoldierPixelRequest>[
      for (var phase = 0; phase <= _baselinePhaseSteps; phase++)
        copy(
          source: releasedUpper,
          cacheId: 'breathing-upper-phase-$phase',
          profileKey: '${released.key}:experiment-a',
          targetRect: releasedUpper.targetRect.translate(
            0,
            -phase / _baselinePhaseSteps,
          ),
        ),
    ];
    return _BreathingExperiment(
      currentLower: copy(
        source: releasedLower,
        cacheId: 'breathing-lower',
        profileKey: '${released.key}:experiment-a',
      ),
      currentUpperRequests: currentUpperRequests,
      fixedLower: copy(
        source: releasedLower,
        cacheId: 'breathing-lower',
        profileKey: '${released.key}:experiment-b',
      ),
      fixedUpper: copy(
        source: releasedUpper,
        cacheId: 'breathing-upper-fixed',
        profileKey: '${released.key}:experiment-b',
      ),
      alignedLower: copy(
        source: releasedLower,
        cacheId: 'breathing-lower',
        profileKey: '${released.key}:experiment-c',
      ),
      alignedUpper: copy(
        source: releasedUpper,
        cacheId: 'breathing-upper-fixed',
        profileKey: '${released.key}:experiment-c',
      ),
    );
  }

  final BaseCampSoldierPixelRequest currentLower;
  final List<BaseCampSoldierPixelRequest> currentUpperRequests;
  final BaseCampSoldierPixelRequest fixedLower;
  final BaseCampSoldierPixelRequest fixedUpper;
  final BaseCampSoldierPixelRequest alignedLower;
  final BaseCampSoldierPixelRequest alignedUpper;

  List<BaseCampSoldierPixelRequest> get currentRequests =>
      <BaseCampSoldierPixelRequest>[currentLower, ...currentUpperRequests];
  List<BaseCampSoldierPixelRequest> get fixedRequests =>
      <BaseCampSoldierPixelRequest>[fixedLower, fixedUpper];
  List<BaseCampSoldierPixelRequest> get alignedRequests =>
      <BaseCampSoldierPixelRequest>[alignedLower, alignedUpper];

  BaseCampSoldierPixelRequest currentUpperFor(double dy) =>
      currentUpperRequests[_baselinePhase(dy)];
  BaseCampSoldierPixelRequest fixedUpperFor(double dy) => fixedUpper;
}

class _ExperimentalBreathingSoldier extends StatelessWidget {
  const _ExperimentalBreathingSoldier({
    required this.experiment,
    required this.path,
    required this.dy,
    required this.devicePixelRatio,
  });

  final _BreathingExperiment experiment;
  final _ComparisonPath path;
  final double dy;
  final double devicePixelRatio;

  @override
  Widget build(BuildContext context) {
    final effectiveDy = path == _ComparisonPath.physicalPixelAligned
        ? _alignToPhysicalPixel(dy, devicePixelRatio)
        : dy;
    final lower = switch (path) {
      _ComparisonPath.currentPhaseDependent => experiment.currentLower,
      _ComparisonPath.fixedImage => experiment.fixedLower,
      _ComparisonPath.physicalPixelAligned => experiment.alignedLower,
    };
    final upper = switch (path) {
      _ComparisonPath.currentPhaseDependent => experiment.currentUpperFor(dy),
      _ComparisonPath.fixedImage => experiment.fixedUpper,
      _ComparisonPath.physicalPixelAligned => experiment.alignedUpper,
    };
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: <Widget>[
        BaseCampSoldierAssetImage(request: lower, fit: BoxFit.contain),
        BaseCampSoldierAssetImage(
          request: upper,
          fit: BoxFit.contain,
          originalOffset: Offset(0, effectiveDy),
        ),
      ],
    );
  }
}

class _ComparisonCell extends StatelessWidget {
  const _ComparisonCell({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xffaeb894)),
    ),
    child: Column(
      children: <Widget>[
        SizedBox(
          height: 32,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xffaeb894), fontSize: 11),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}

double _alignToPhysicalPixel(double dy, double devicePixelRatio) =>
    (dy * devicePixelRatio).round() / devicePixelRatio;

int _baselinePhase(double dy) =>
    ((-dy).clamp(0.0, 1.0) * _baselinePhaseSteps).round();

Future<void> _captureBoundary(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String name,
) async {
  if (_captureDirectory.isEmpty) return;
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  boundary.markNeedsPaint();
  await tester.pump();
  await tester.runAsync(() async {
    final directory = Directory(_captureDirectory)..createSync(recursive: true);
    final image = await boundary.toImage(
      pixelRatio: tester.view.devicePixelRatio,
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '${directory.path}/$name',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
