import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/core/services/system_diagnostics.dart';
import 'package:or_app/features/themes/base_camp/base_camp_facility_assets.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_configuration.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_editor_page.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_map.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_water_surface_v3b.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('presentation theme defaults and restores as STANDARD safely', () {
    expect(
      const DeviceSettings().presentationTheme,
      AppPresentationTheme.standard,
    );
    expect(
      DeviceSettings.fromJson(<String, Object?>{}).presentationTheme,
      AppPresentationTheme.standard,
    );
    expect(
      DeviceSettings.fromJson({
        'presentationTheme': 'newTheme',
      }).presentationTheme,
      AppPresentationTheme.baseCamp,
    );
  });

  test('V2.7 square map asset is registered and decodes losslessly', () async {
    final data = await rootBundle.load(baseCampMapAsset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 1254);
    expect(frame.image.height, 1254);
    frame.image.dispose();
    codec.dispose();
  });

  test('day and night boundaries use local wall-clock time', () {
    expect(baseCampMapNightOverlayColor.toARGB32(), 0x560A2230);
    expect(baseCampMapUsesNightFilter(DateTime(2026, 11, 15, 5, 59)), isTrue);
    expect(baseCampMapUsesNightFilter(DateTime(2026, 11, 15, 6)), isFalse);
    expect(baseCampMapUsesNightFilter(DateTime(2026, 11, 15, 17, 59)), isFalse);
    expect(baseCampMapUsesNightFilter(DateTime(2026, 11, 15, 18)), isTrue);
    expect(
      baseCampNextDayNightBoundary(DateTime(2026, 11, 15, 5, 30)),
      DateTime(2026, 11, 15, 6),
    );
    expect(
      baseCampNextDayNightBoundary(DateTime(2026, 11, 15, 12)),
      DateTime(2026, 11, 15, 18),
    );
    expect(
      baseCampNextDayNightBoundary(DateTime(2026, 11, 15, 23)),
      DateTime(2026, 11, 16, 6),
    );
  });

  testWidgets('night filter re-evaluates on resume without covering map UI', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 15, 17, 59);
    SystemDiagnostics.instance.clear();
    addTearDown(SystemDiagnostics.instance.clear);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: BaseCampMap(
              onFacilityPressed: _ignoreFacility,
              now: () => now,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('base-camp-night-filter')), findsNothing);

    now = DateTime(2026, 11, 15, 18);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    final night = find.byKey(const ValueKey('base-camp-night-filter'));
    expect(night, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('base-camp-map')),
        matching: night,
      ),
      findsOneWidget,
    );
    final nightColor = tester.widget<ColoredBox>(
      find.descendant(of: night, matching: find.byType(ColoredBox)),
    );
    expect(nightColor.color, baseCampMapNightOverlayColor);
    expect(find.byKey(const ValueKey('base-camp-reset')), findsOneWidget);
    final trace = SystemDiagnostics.instance.copyText();
    expect(trace, contains('NIGHT_FILTER_STATE_APPLIED'));
    expect(trace, contains('"state": "day"'));
    expect(trace, contains('"state": "night"'));
    expect(trace, contains('"reason": "resume"'));
  });

  testWidgets('square map starts unpanned with no internal scroll viewport', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: BaseCampMap(onFacilityPressed: _ignoreFacility),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));
    final map = tester.widget<InteractiveViewer>(
      find.byKey(const ValueKey('base-camp-map')),
    );
    expect(map.transformationController!.value, Matrix4.identity());
    expect(find.byType(SingleChildScrollView), findsNothing);
    final size = tester.getSize(find.byKey(const ValueKey('base-camp-map')));
    expect(size.width, closeTo(size.height, .01));
    expect(find.byKey(const ValueKey('base-camp-water-fx')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map lifecycle records bounded dashboard diagnostics', (
    tester,
  ) async {
    SystemDiagnostics.instance.clear();
    addTearDown(SystemDiagnostics.instance.clear);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: BaseCampMap(onFacilityPressed: _ignoreFacility),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await _pumpUntilFacilityLayer(tester);

    final trace = SystemDiagnostics.instance.copyText();
    expect(trace, contains('MAP_BACKGROUND_LOAD_START'));
    expect(trace, contains('MAP_BACKGROUND_LOAD_COMPLETE'));
    expect(trace, contains('MAP_BACKGROUND_READY'));
    expect(trace, contains('MAP_DISPLAY_COMPLETE'));
    expect(trace, contains('FACILITY_OBJECTS_ATOMIC_PREPARE_START'));
  });

  testWidgets('visible facilities publish atomically after preparation', (
    tester,
  ) async {
    SystemDiagnostics.instance.clear();
    addTearDown(SystemDiagnostics.instance.clear);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: BaseCampMap(onFacilityPressed: _ignoreFacility),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('base-camp-facility-object-layer')),
      findsNothing,
    );
    await _pumpUntilFacilityLayer(tester);
    expect(
      find.byKey(const ValueKey('base-camp-facility-object-layer')),
      findsOneWidget,
    );

    final trace = SystemDiagnostics.instance.copyText();
    final mapDisplayed = trace.indexOf('MAP_DISPLAY_COMPLETE');
    final prepareStart = trace.indexOf('FACILITY_OBJECTS_ATOMIC_PREPARE_START');
    final prepareComplete = trace.indexOf(
      'FACILITY_OBJECTS_ATOMIC_PREPARE_COMPLETE',
    );
    final displayComplete = trace.indexOf('FACILITY_OBJECTS_DISPLAY_COMPLETE');
    final interactive = trace.indexOf('DASHBOARD_INTERACTIVE');
    expect(mapDisplayed, greaterThanOrEqualTo(0));
    expect(prepareStart, greaterThanOrEqualTo(0));
    expect(prepareComplete, greaterThan(prepareStart));
    expect(displayComplete, greaterThan(mapDisplayed));
    expect(displayComplete, greaterThan(prepareComplete));
    expect(interactive, greaterThan(displayComplete));
    expect(trace, contains('"atomicReveal": true'));
  });

  test('facility preparation no longer depends on MAP display completion', () {
    final source = File(
      'lib/features/themes/base_camp/widgets/base_camp_map.dart',
    ).readAsStringSync();
    final start = source.indexOf('void _startInitialFacilityBatchIfReady()');
    final end = source.indexOf('_facilityBatchStarted = true;', start);
    final method = source.substring(start, end);

    expect(method, contains('!_dependenciesReady'));
    expect(method, contains('!_configurationReady'));
    expect(method, isNot(contains('!_mapDisplayed')));
    expect(
      source,
      contains("'startedBeforeMapDisplay':"),
      reason: 'production diagnostics must prove whether preparation overlaps',
    );
  });

  test('asset staging yields to events instead of throttled render frames', () {
    final source = File(
      'lib/features/themes/base_camp/widgets/base_camp_map.dart',
    ).readAsStringSync();
    for (final methodName in <String>[
      'Future<void> _initializeWaterFx()',
      'Future<void> _prepareInitialFacilityBatch()',
      'Future<void> _warmWalkerFrames()',
    ]) {
      final start = source.indexOf(methodName);
      final end = source.indexOf('\n  Future<', start + methodName.length);
      final method = source.substring(start, end < 0 ? source.length : end);
      expect(method, contains('Future<void>.value()'));
      expect(method, isNot(contains('SchedulerBinding.instance.endOfFrame')));
    }
    expect(source, contains("'schedulingStrategy':"));
    expect(source, contains("'cacheReuseCount':"));
    expect(source, contains("'frameTimings':"));
  });

  test('asset acquisition is bounded and cache reuse uses real status', () {
    final helpers = File(
      'lib/features/themes/base_camp/base_camp_facility_assets.dart',
    ).readAsStringSync();
    final map = File(
      'lib/features/themes/base_camp/widgets/base_camp_map.dart',
    ).readAsStringSync();

    expect(helpers, contains('baseCampAssetAcquisitionConcurrency = 4'));
    expect(helpers, contains('baseCampAcquireAssetBytes'));
    expect(map, contains("cache['cacheReused'] == true"));
    expect(map, isNot(contains("cache['cacheStatus'] != 'miss'")));
    expect(map, contains("'acquisitionMs': acquisition.durationMs"));
  });

  test(
    'compressed asset acquisition enforces the shared concurrency bound',
    () async {
      var active = 0;
      var maximumActive = 0;
      final result = await baseCampAcquireAssetBytes(
        List<String>.generate(12, (index) => 'asset-$index'),
        loader: (asset) async {
          active++;
          maximumActive = math.max(maximumActive, active);
          await Future<void>.delayed(const Duration(milliseconds: 2));
          active--;
          if (asset == 'asset-7') {
            throw StateError('synthetic acquisition miss');
          }
          return ByteData(1);
        },
      );

      expect(maximumActive, baseCampAssetAcquisitionConcurrency);
      expect(result.assetCount, 12);
      expect(result.loadedCount, 11);
      expect(result.failedCount, 1);
    },
  );

  test('facility alpha masks do not wait for throttled rendered frames', () {
    final source = File(
      'lib/features/themes/base_camp/widgets/base_camp_map.dart',
    ).readAsStringSync();
    final start = source.indexOf(
      'Future<T> _scheduleAlphaDecode<T>(Future<T> Function() decode)',
    );
    final end = source.indexOf('\n  void invalidate(', start);
    final method = source.substring(start, end);

    expect(method, contains('await Future<void>.value()'));
    expect(method, isNot(contains('SchedulerBinding.instance.endOfFrame')));
  });

  testWidgets('WATER V3B overlay is clipped to masks and protected land', (
    tester,
  ) async {
    final original = baseCampMapConfigurationController.value;
    addTearDown(() => baseCampMapConfigurationController.value = original);
    baseCampMapConfigurationController.value =
        BaseCampMapConfiguration.defaults();
    SystemDiagnostics.instance.clear();
    addTearDown(SystemDiagnostics.instance.clear);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: BaseCampMap(
              onFacilityPressed: _ignoreFacility,
              now: () => DateTime(2026, 11, 15, 12),
            ),
          ),
        ),
      ),
    );
    await _pumpUntilFacilityLayer(tester);
    await _pumpUntilWaterFx(tester);

    final water = find.byKey(const ValueKey('base-camp-water-fx'));
    final clipFinder = find.byKey(const ValueKey('base-camp-water-mask-clip'));
    expect(water, findsOneWidget);
    expect(clipFinder, findsOneWidget);
    expect(
      find.byKey(const ValueKey('base-camp-water-v3b-overlay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('base-camp-water-surface-reflection')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('base-camp-water-arc-fragments')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('base-camp-water-pattern-primary')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('base-camp-water-pattern-secondary')),
      findsNothing,
    );
    final clip = tester.widget<ClipPath>(clipFinder);
    final clipSize = tester.getSize(clipFinder);
    final path = clip.clipper!.getClip(clipSize);
    final geometry = BaseCampMapGeometry.contain(clipSize);
    expect(
      path.contains(geometry.artworkToViewport(const Offset(10, 200))),
      isTrue,
    );
    expect(
      path.contains(geometry.artworkToViewport(const Offset(50, 50))),
      isFalse,
    );
    expect(
      path.contains(geometry.artworkToViewport(const Offset(600, 600))),
      isFalse,
    );

    expect(
      find.descendant(of: water, matching: find.byType(Image)),
      findsNWidgets(
        baseCampMapConfigurationController
            .value
            .waterFx['water']!
            .effectiveAreas
            .fold<int>(
              0,
              (count, area) =>
                  count +
                  baseCampWaterV3BVisiblePlacementsForArea(area: area).length,
            ),
      ),
    );
    await tester.pump(baseCampWaterV3BFrameDuration);
    expect(tester.takeException(), isNull);

    final trace = SystemDiagnostics.instance.copyText();
    expect(trace, contains('WATER_FX_INIT_START'));
    expect(trace, contains('WATER_FX_INIT_COMPLETE'));
    expect(trace, contains('WATER_FX_ACTIVE_STATE'));
    expect(trace, contains('"patternLayers": 1'));
    expect(trace, contains('"frameCount": 24'));
    expect(trace, contains('"frameDurationMs": 140'));
    expect(trace, contains('"loopDurationMs": 3360'));
    expect(trace, contains('approvedV3BRoundingV2RgbaFrames'));
    final deferredStart = trace.indexOf('DEFERRED_MAP_ANIMATION_PREPARE_START');
    final waterStart = trace.indexOf('WATER_FX_INIT_START');
    final walkerStart = trace.indexOf('WALKER_STAGED_PRECACHE_START');
    final walkerComplete = trace.indexOf('WALKER_STAGED_PRECACHE_COMPLETE');
    expect(deferredStart, greaterThanOrEqualTo(0));
    expect(waterStart, greaterThan(deferredStart));
    expect(walkerStart, greaterThan(waterStart));
    expect(
      walkerComplete < 0 || waterStart < walkerComplete,
      isTrue,
      reason: 'WATER must not wait for the full WALKER precache',
    );
    expect(trace, contains('"maxConcurrentDecodeTasks": 2'));
  });

  test('WATER V3B uses exact frame order, timing, and seamless loop', () {
    expect(baseCampWaterV3BFrameAssets, hasLength(24));
    expect(baseCampWaterV3BFrameAssets.toSet(), hasLength(24));
    for (var index = 0; index < baseCampWaterV3BFrameCount; index++) {
      expect(
        baseCampWaterV3BFrameAssets[index],
        endsWith('frame_${index.toString().padLeft(2, '0')}.png'),
      );
      expect(baseCampWaterV3BFrameIndex(index), index);
    }
    expect(baseCampWaterV3BFrameDuration, const Duration(milliseconds: 140));
    expect(baseCampWaterV3BLoopDuration, const Duration(milliseconds: 3360));
    expect(baseCampWaterV3BFrameIndex(24), 0);
    expect(baseCampWaterV3BFrameIndex(47), 23);
  });

  test('WATER V3B applies only the approved per-area intensities', () {
    expect(baseCampWaterV3BAreaIntensityMultipliers, const [.55, .65, 1, 1]);
    expect(baseCampWaterV3BAreaIntensity(0), .55);
    expect(baseCampWaterV3BAreaIntensity(1), .65);
    expect(baseCampWaterV3BAreaIntensity(2), 1);
    expect(baseCampWaterV3BAreaIntensity(3), 1);
    expect(baseCampWaterV3BAreaIntensity(4), 1);
  });

  testWidgets('WATER V3B layer selects the controlled frame exactly', (
    tester,
  ) async {
    final tick = ValueNotifier<int>(0);
    addTearDown(tick.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 390,
          child: BaseCampWaterSurfaceV3BLayer(
            water: BaseCampMapConfiguration.defaults().waterFx['water']!,
            imageRect: const Rect.fromLTWH(0, 0, 390, 390),
            artworkSize: baseCampMapArtworkSize,
            frameTick: tick,
          ),
        ),
      ),
    );
    final water = BaseCampMapConfiguration.defaults().waterFx['water']!;
    final placements = baseCampWaterV3BVisiblePlacementsForArea(
      area: water.effectiveAreas.first,
    );
    final expectedTileCount = water.effectiveAreas.fold<int>(
      0,
      (count, area) =>
          count + baseCampWaterV3BVisiblePlacementsForArea(area: area).length,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('base-camp-water-v3b-overlay')),
        matching: find.byType(Image),
      ),
      findsNWidgets(expectedTileCount),
    );
    final firstTile = find.byKey(
      const ValueKey('base-camp-water-v3b-area-0-tile-0'),
    );
    expect(
      find.descendant(of: firstTile, matching: find.byType(ShaderMask)),
      findsNWidgets(2),
    );
    expect(
      find.descendant(
        of: firstTile,
        matching: find.byKey(
          ValueKey('base-camp-water-v3b-frame-${placements.first.phaseOffset}'),
        ),
      ),
      findsOneWidget,
    );
    final image = tester.widget<Image>(
      find.descendant(of: firstTile, matching: find.byType(Image)),
    );
    expect(image.color, isNull);
    expect(image.colorBlendMode, isNull);
    expect(image.fit, BoxFit.fill);
    expect(image.filterQuality, FilterQuality.medium);
    tick.value = 1;
    await tester.pump();
    expect(
      find.descendant(
        of: firstTile,
        matching: find.byKey(
          ValueKey(
            'base-camp-water-v3b-frame-${baseCampWaterV3BFrameIndex(placements.first.phaseOffset + 1)}',
          ),
        ),
      ),
      findsOneWidget,
    );
    tick.value = 24;
    await tester.pump();
    expect(
      find.descendant(
        of: firstTile,
        matching: find.byKey(
          ValueKey('base-camp-water-v3b-frame-${placements.first.phaseOffset}'),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('WATER V3B applies intensity after each area tile composite', (
    tester,
  ) async {
    final tick = ValueNotifier<int>(0);
    addTearDown(tick.dispose);
    final water = BaseCampMapConfiguration.defaults().waterFx['water']!;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 390,
          child: BaseCampWaterSurfaceV3BLayer(
            water: water,
            imageRect: const Rect.fromLTWH(0, 0, 390, 390),
            artworkSize: baseCampMapArtworkSize,
            frameTick: tick,
          ),
        ),
      ),
    );

    for (var areaIndex = 0; areaIndex < 4; areaIndex++) {
      final opacityFinder = find.byKey(
        ValueKey('base-camp-water-v3b-area-$areaIndex-opacity'),
      );
      final compositeFinder = find.byKey(
        ValueKey('base-camp-water-v3b-area-$areaIndex-composite'),
      );
      expect(
        tester.widget<Opacity>(opacityFinder).opacity,
        baseCampWaterV3BAreaIntensity(areaIndex),
      );
      expect(
        find.ancestor(of: compositeFinder, matching: opacityFinder),
        findsOneWidget,
      );
    }
  });

  testWidgets('WATER V3B keeps all four areas active for three full loops', (
    tester,
  ) async {
    final tick = ValueNotifier<int>(0);
    addTearDown(tick.dispose);
    final water = BaseCampMapConfiguration.defaults().waterFx['water']!;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 390,
          child: BaseCampWaterSurfaceV3BLayer(
            water: water,
            imageRect: const Rect.fromLTWH(0, 0, 390, 390),
            artworkSize: baseCampMapArtworkSize,
            frameTick: tick,
          ),
        ),
      ),
    );

    for (var frame = 0; frame < baseCampWaterV3BFrameCount * 3; frame++) {
      tick.value = frame;
      await tester.pump(baseCampWaterV3BFrameDuration);
      for (var areaIndex = 0; areaIndex < 4; areaIndex++) {
        expect(
          find.byKey(ValueKey('base-camp-water-v3b-area-$areaIndex-composite')),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    }
    expect(tick.value, baseCampWaterV3BFrameCount * 3 - 1);
  });

  test('WATER V3B area clips exclude masks and never double-render', () {
    final areas =
        BaseCampMapConfiguration.defaults().waterFx['water']!.effectiveAreas;
    final clips = <Path>[];
    for (var areaIndex = 0; areaIndex < areas.length; areaIndex++) {
      clips.add(
        baseCampWaterV3BAreaClipPath(
          area: areas[areaIndex],
          claimedAreas: areas.take(areaIndex).toList(growable: false),
          imageRect: const Rect.fromLTWH(0, 0, 1254, 1254),
          artworkSize: baseCampMapArtworkSize,
        ),
      );
    }
    for (var left = 0; left < clips.length; left++) {
      for (var right = left + 1; right < clips.length; right++) {
        expect(
          Path.combine(
            PathOperation.intersect,
            clips[left],
            clips[right],
          ).computeMetrics(),
          isEmpty,
        );
      }
    }
    expect(clips[0].contains(const Offset(50, 50)), isFalse);
  });

  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    testWidgets('WATER V3B overlay has no overflow at width $width', (
      tester,
    ) async {
      final tick = ValueNotifier<int>(0);
      addTearDown(tick.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox.square(
            dimension: width,
            child: BaseCampWaterSurfaceV3BLayer(
              water: BaseCampMapConfiguration.defaults().waterFx['water']!,
              imageRect: Rect.fromLTWH(0, 0, width, width),
              artworkSize: baseCampMapArtworkSize,
              frameTick: tick,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('base-camp-water-v3b-overlay')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('base-camp-water-v3b-overlay')),
          matching: find.byType(Image),
        ),
        findsNWidgets(
          BaseCampMapConfiguration.defaults().waterFx['water']!.effectiveAreas
              .fold<int>(
                0,
                (count, area) =>
                    count +
                    baseCampWaterV3BVisiblePlacementsForArea(area: area).length,
              ),
        ),
      );
    });
  }

  test('WATER V3B uses deterministic source-space staggered placements', () {
    final placements = baseCampWaterV3BPlacements();
    expect(baseCampWaterV3BPatternScale, 1);
    expect(placements, hasLength(40));
    expect(
      placements.map((placement) => placement.phaseOffset).toSet().length,
      greaterThan(8),
    );
    for (final placement in placements) {
      expect(placement.sourceRect.size, baseCampWaterV3BSourceSize);
    }
    final union = placements
        .map((placement) => placement.sourceRect)
        .reduce((left, right) => left.expandToInclude(right));
    expect(union.left, lessThanOrEqualTo(0));
    expect(union.top, lessThanOrEqualTo(0));
    expect(union.right, greaterThanOrEqualTo(baseCampMapArtworkSize.width));
    expect(union.bottom, greaterThanOrEqualTo(baseCampMapArtworkSize.height));
  });

  test(
    'approved WATER geometry renders only intersecting source tiles',
    () async {
      final configuration = BaseCampMapConfiguration.tryParse(
        jsonDecode(
          await File('assets/data/WATER_IMPORT_CORRECTED.json').readAsString(),
        ),
      );
      final water = configuration!.waterFx['water']!;
      final visible = baseCampWaterV3BVisiblePlacements(water: water);

      expect(visible, hasLength(27));
      expect(visible.length, lessThan(baseCampWaterV3BPlacements().length));
      for (final area in water.effectiveAreas) {
        final areaBounds = (Path()..addPolygon(area.mask, true)).getBounds();
        expect(
          visible.any((placement) => placement.sourceRect.overlaps(areaBounds)),
          isTrue,
        );
      }
    },
  );

  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    test('WATER V3B follows the MAP transform at width $width', () {
      final placement = baseCampWaterV3BPlacements().first;
      final viewport = baseCampWaterV3BViewportRect(
        sourceRect: placement.sourceRect,
        imageRect: Rect.fromLTWH(0, 0, width, width),
        artworkSize: baseCampMapArtworkSize,
      );
      final mapScale = width / baseCampMapArtworkSize.width;
      expect(
        viewport.width,
        closeTo(baseCampWaterV3BSourceSize.width * mapScale, .000001),
      );
      expect(
        viewport.height,
        closeTo(baseCampWaterV3BSourceSize.height * mapScale, .000001),
      );
      expect(viewport.width / viewport.height, closeTo(440 / 248, .000001));
    });
  }

  test('approved WATER V3B manifest and RGBA frames are bundled', () async {
    final manifestData = await rootBundle.loadString(
      'assets/images/themes/base_camp/water_v3b/manifest.json',
    );
    final manifest = jsonDecode(manifestData) as Map<String, dynamic>;
    expect(manifest['reference'], 'WATER V3B rounding_v2 / prototype 5');
    expect(manifest['width'], 440);
    expect(manifest['height'], 248);
    expect(manifest['frames'], 24);
    expect(manifest['frame_duration_ms'], 140);
    expect(manifest['loop_ms'], 3360);

    for (final asset in baseCampWaterV3BFrameAssets) {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 440, reason: asset);
      expect(frame.image.height, 248, reason: asset);
      frame.image.dispose();
      codec.dispose();
    }

    final firstData = await rootBundle.load(baseCampWaterV3BFrameAssets.first);
    final firstCodec = await ui.instantiateImageCodec(
      firstData.buffer.asUint8List(),
    );
    final firstFrame = await firstCodec.getNextFrame();
    final pixels = await firstFrame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    expect(pixels, isNotNull);
    var hasTransparentPixel = false;
    var hasVisiblePixel = false;
    for (var offset = 3; offset < pixels!.lengthInBytes; offset += 4) {
      final alpha = pixels.getUint8(offset);
      hasTransparentPixel |= alpha == 0;
      hasVisiblePixel |= alpha > 0;
      if (hasTransparentPixel && hasVisiblePixel) break;
    }
    expect(hasTransparentPixel, isTrue);
    expect(hasVisiblePixel, isTrue);
    firstFrame.image.dispose();
    firstCodec.dispose();
  });

  testWidgets('one failed facility does not block the atomic reveal', (
    tester,
  ) async {
    final original = baseCampMapConfigurationController.value;
    addTearDown(() => baseCampMapConfigurationController.value = original);
    SystemDiagnostics.instance.clear();
    addTearDown(SystemDiagnostics.instance.clear);
    baseCampMapConfigurationController.value = original.copyWith(
      objects: <String, BaseCampMapObject>{
        ...original.objects,
        'flag': original.objects['flag']!.copyWith(
          assetId: 'missing-test-asset',
        ),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: BaseCampMap(onFacilityPressed: _ignoreFacility),
          ),
        ),
      ),
    );
    await _pumpUntilFacilityLayer(tester);

    expect(
      find.byKey(const ValueKey('base-camp-facility-object-layer')),
      findsOneWidget,
    );
    expect(find.text('MISSING\nASSET'), findsOneWidget);
    final trace = SystemDiagnostics.instance.copyText();
    expect(trace, contains('FACILITY_OBJECT_PREPARE_FAILED'));
    expect(trace, contains('missing-test-asset'));
    expect(trace, contains('FACILITY_OBJECTS_DISPLAY_COMPLETE'));
  });

  testWidgets('post-reveal configuration updates never hide normal objects', (
    tester,
  ) async {
    final original = baseCampMapConfigurationController.value;
    addTearDown(() => baseCampMapConfigurationController.value = original);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: BaseCampMap(onFacilityPressed: _ignoreFacility),
          ),
        ),
      ),
    );
    await _pumpUntilFacilityLayer(tester);

    baseCampMapConfigurationController.value = original.copyWith(
      objects: <String, BaseCampMapObject>{
        ...original.objects,
        'flag': original.objects['flag']!.copyWith(visible: false),
      },
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('base-camp-facility-object-layer')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('base-camp-object-flag')), findsNothing);
    expect(
      find.byKey(const ValueKey('base-camp-object-status')),
      findsOneWidget,
    );
  });

  test(
    'local map asset resolver shares reads and invalidates updates',
    () async {
      var reads = 0;
      final resolver = BaseCampMapAssetResolver(
        reader: (assetId) async {
          reads++;
          return null;
        },
      );

      final first = resolver.read('local-facility');
      final duplicate = resolver.read('local-facility');
      expect(identical(first, duplicate), isTrue);
      await Future.wait([first, duplicate]);
      expect(reads, 1);

      resolver.invalidate('local-facility');
      await resolver.read('local-facility');
      expect(reads, 2);
    },
  );

  test(
    'Base Camp restore failure preserves defaults without escaping boot',
    () async {
      final controller = BaseCampMapConfigurationController(
        preferencesLoader: () => throw StateError('storage unavailable'),
      );

      await controller.load();

      expect(
        controller.value.encode(),
        BaseCampMapConfiguration.defaults().encode(),
      );
      expect(controller.lastLoadFailureStage, 'storage_or_restore_StateError');
    },
  );

  testWidgets(
    'facility selection waits for YES before navigating by callback',
    (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: BaseCampMap(
                onFacilityPressed: (facility) => selected.add(facility.id),
              ),
            ),
          ),
        ),
      );

      expect(baseCampFacilities, hasLength(5));
      await _pumpUntilFacilityLayer(tester);
      expect(find.bySemanticsLabel('STATUS facility'), findsOneWidget);
      for (var index = 0; index < baseCampFacilities.length; index++) {
        final facility = baseCampFacilities[index];
        await _tapOpaqueFacility(tester, facility.id);
        expect(selected, hasLength(index));
        expect(find.text('BASE CAMP / FACILITY SELECT'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('base-camp-confirm-yes')));
        await tester.pump();
      }

      expect(
        selected,
        baseCampFacilities.map((facility) => facility.id).toList(),
      );
    },
  );

  testWidgets('RESET retains all Base Camp facility hit regions', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: BaseCampMap(
              onFacilityPressed: (facility) => selected = facility.id,
            ),
          ),
        ),
      ),
    );
    await _pumpUntilFacilityLayer(tester);

    await tester.drag(
      find.byKey(const ValueKey('base-camp-map')),
      const Offset(40, 0),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('base-camp-reset')));
    await tester.pump();
    await _tapOpaqueFacility(tester, 'command-center');
    expect(selected, isNull);
    await tester.tap(find.byKey(const ValueKey('base-camp-confirm-yes')));
    await tester.pump();

    expect(selected, 'command-center');
  });

  testWidgets('NO clears selection and another facility replaces it', (
    tester,
  ) async {
    final selected = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: BaseCampMap(
              onFacilityPressed: (facility) => selected.add(facility.id),
            ),
          ),
        ),
      ),
    );
    await _pumpUntilFacilityLayer(tester);

    await _tapOpaqueFacility(tester, 'status');
    expect(find.text('STATUS'), findsOneWidget);
    await _tapOpaqueFacility(tester, 'food');
    expect(find.text('FOOD'), findsOneWidget);
    expect(selected, isEmpty);
    await tester.tap(find.byKey(const ValueKey('base-camp-confirm-no')));
    await tester.pump();
    expect(find.text('BASE CAMP / FACILITY SELECT'), findsNothing);
    expect(selected, isEmpty);
  });

  testWidgets('facility label taps use the same confirmation flow', (
    tester,
  ) async {
    SystemDiagnostics.instance.clear();
    addTearDown(SystemDiagnostics.instance.clear);
    final selected = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: BaseCampMap(
              onFacilityPressed: (facility) => selected.add(facility.id),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    for (final facility in baseCampFacilities) {
      final target = find
          .byKey(ValueKey('base-camp-label-target-${facility.id}'))
          .first;
      expect(target, findsOneWidget);
      await tester.tap(target);
      await tester.pump();
      expect(find.text('BASE CAMP / FACILITY SELECT'), findsOneWidget);
      expect(find.text(facility.label), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('base-camp-confirm-yes')));
      await tester.pump();
    }
    expect(selected, baseCampFacilities.map((facility) => facility.id));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    final trace = SystemDiagnostics.instance.copyText();
    expect(trace, contains('ENTRY_PRELOAD_START'));
    for (final facility in baseCampFacilities) {
      expect(trace, contains(baseCampFacilityEntryAssetForId(facility.id)));
    }
  });

  testWidgets('map drags do not trigger facility navigation', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: BaseCampMap(
              onFacilityPressed: (facility) => selected = facility.id,
            ),
          ),
        ),
      ),
    );

    final status = find.byKey(const ValueKey('base-camp-facility-status'));
    final gesture = await tester.startGesture(tester.getCenter(status));
    await gesture.moveBy(const Offset(56, 8));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 180));

    expect(selected, isNull);
  });

  testWidgets('transparent image pixels do not select a facility', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BaseCampMap(onFacilityPressed: _ignoreFacility)),
      ),
    );
    await _pumpUntilFacilityLayer(tester);
    final status = find.byKey(const ValueKey('base-camp-facility-status'));
    final rect = tester.getRect(status);
    await tester.tapAt(rect.topLeft + const Offset(2, 2));
    await tester.pump();
    expect(find.text('BASE CAMP / FACILITY SELECT'), findsNothing);
    await _tapOpaqueFacility(tester, 'status');
    expect(find.text('STATUS'), findsOneWidget);
  });

  test('two approved walkers use the white-line digitised B/C routes', () {
    expect(baseCampWalkerRoutes.map((route) => route.id), [
      'route-b',
      'route-c',
    ]);
    expect(baseCampWalkerRoutes, hasLength(2));
    expect(
      baseCampWalkerRoutes.first.sourcePoints.first,
      const Offset(882, 275),
    );
    expect(
      baseCampWalkerRoutes.first.sourcePoints.last,
      const Offset(1112, 404),
    );
    expect(
      baseCampWalkerRoutes.last.sourcePoints.first,
      const Offset(616, 474),
    );
    expect(baseCampWalkerRoutes.last.sourcePoints.last, const Offset(808, 604));
    expect(
      baseCampWalkerRoutes.first.normalizedPoints.first.dx,
      closeTo(.689, .001),
    );
    expect(
      baseCampWalkerRoutes.last.normalizedPoints.last.dy,
      closeTo(.839, .001),
    );
    for (final route in baseCampWalkerRoutes) {
      expect(
        route.pausePatternSeconds,
        everyElement(inInclusiveRange(2.0, 4.0)),
      );
    }
  });

  test('Route A uses five approved 160ms forward and return frames', () {
    expect(baseCampRouteA.sourcePoints, hasLength(greaterThanOrEqualTo(2)));
    expect(
      baseCampWalkerFrameAssets(baseCampWalkerRearUpperRightAsset),
      hasLength(5),
    );
    expect(baseCampWalkerFrameAssets(baseCampWalkerFrontAsset), hasLength(5));
    expect(
      baseCampWalkerFrameDuration(baseCampWalkerRearUpperRightAsset),
      const Duration(milliseconds: 160),
    );
    expect(
      baseCampWalkerFrameDuration(baseCampWalkerFrontAsset),
      const Duration(milliseconds: 160),
    );
  });

  test('schema v8 water, labels and static soldiers round-trip', () {
    final defaults = BaseCampMapConfiguration.defaults().copyWith(
      staticSoldiers: const <BaseCampStaticSoldier>[
        BaseCampStaticSoldier(
          id: 'guard-1',
          position: Offset(421, 315),
          direction: 'left',
          scale: .8,
        ),
      ],
    );

    final restored = BaseCampMapConfiguration.tryParse(defaults.toJson());

    expect(restored, isNotNull);
    expect(restored!.waterFx.keys, const <String>['water']);
    expect(
      restored.waterFx['water']!.toJson(),
      defaults.waterFx['water']!.toJson(),
    );
    expect(restored.staticSoldiers.single.id, 'guard-1');
  });

  test('redline reference defines four editable default water areas', () {
    final water = BaseCampMapConfiguration.defaults().waterFx['water']!;

    expect(water.effectiveAreas, hasLength(4));
    expect(water.effectiveAreas[0].mask.first, Offset.zero);
    expect(water.effectiveAreas[1].mask, contains(const Offset(1254, 0)));
    expect(water.effectiveAreas[2].mask.first.dy, closeTo(748, .01));
    expect(water.effectiveAreas[3].mask, contains(const Offset(1254, 1254)));
  });

  test('water FX preserves independent layers and per-area exclusions', () {
    final defaults = BaseCampMapConfiguration.defaults();
    final water = defaults.waterFx['water']!;
    final first = water.effectiveAreas.first;
    final changed = water.copyWith(
      shimmerEnabled: false,
      rippleEnabled: true,
      foamEnabled: false,
      areas: <BaseCampWaterArea>[
        BaseCampWaterArea(
          mask: first.mask,
          shoreline: first.shoreline,
          exclusionMasks: const <List<Offset>>[
            <Offset>[
              Offset(20, 100),
              Offset(45, 94),
              Offset(49, 136),
              Offset(24, 149),
            ],
          ],
        ),
        ...water.effectiveAreas.skip(1),
      ],
    );

    final restored = BaseCampMapConfiguration.tryParse(
      defaults
          .copyWith(waterFx: <String, BaseCampWaterFx>{'water': changed})
          .toJson(),
    )!;

    expect(restored.waterFx['water']!.shimmerEnabled, isFalse);
    expect(restored.waterFx['water']!.rippleEnabled, isTrue);
    expect(restored.waterFx['water']!.foamEnabled, isFalse);
    expect(
      restored.waterFx['water']!.effectiveAreas.first.exclusionMasks,
      hasLength(1),
    );
  });

  test('v7 keeps legacy FX as compatibility and installs approved water', () {
    final defaults = BaseCampMapConfiguration.defaults();
    const rock = BaseCampWaterFx(
      mask: <Offset>[Offset(0, 800), Offset(100, 850), Offset(0, 1000)],
      shoreline: <Offset>[Offset(0, 800), Offset(100, 850)],
      intensity: 1.25,
      foam: 1.3,
    );
    const coast = BaseCampWaterFx(
      mask: <Offset>[Offset(0, 100), Offset(90, 160), Offset(0, 300)],
      shoreline: <Offset>[Offset(0, 100), Offset(90, 160)],
      shimmerEnabled: false,
      exclusionMasks: <List<Offset>>[
        <Offset>[Offset(10, 110), Offset(20, 120), Offset(10, 130)],
      ],
    );
    final v7 = <String, Object?>{
      ...defaults.toJson(),
      'schemaVersion': 7,
      'waterFx': <String, Object?>{
        'rock-foam': rock.toJson(),
        'coast-ripple': coast.toJson(),
      },
    }..remove('compatibilityWaterFxV7');

    final migrated = BaseCampMapConfiguration.tryParse(v7)!;

    expect(migrated.waterFx.keys, const <String>['water']);
    expect(migrated.waterFx['water']!.effectiveAreas, hasLength(4));
    expect(
      migrated.waterFx['water']!.effectiveAreas.map((area) => area.toJson()),
      BaseCampWaterFx.defaults()['water']!.effectiveAreas.map(
        (area) => area.toJson(),
      ),
    );
    expect(migrated.compatibilityWaterFxV7['rock-foam']!.intensity, 1.25);
    expect(
      migrated.compatibilityWaterFxV7['coast-ripple']!.shimmerEnabled,
      isFalse,
    );
    expect(
      migrated.compatibilityWaterFxV7['coast-ripple']!.exclusionMasks.single,
      coast.exclusionMasks.single,
    );
    expect(
      BaseCampMapConfiguration.tryParse(migrated.toJson())!.toJson(),
      migrated.toJson(),
    );
  });

  test('v6 water follows the same non-destructive migration', () {
    final defaults = BaseCampMapConfiguration.defaults();
    const rock = BaseCampWaterFx(
      mask: <Offset>[Offset(0, 800), Offset(100, 850), Offset(0, 1000)],
      shoreline: <Offset>[Offset(0, 800), Offset(100, 850)],
    );
    const coast = BaseCampWaterFx(
      mask: <Offset>[Offset(0, 100), Offset(90, 160), Offset(0, 300)],
      shoreline: <Offset>[Offset(0, 100), Offset(90, 160)],
    );
    final v6 = <String, Object?>{
      ...defaults.toJson(),
      'schemaVersion': 6,
      'waterFx': <String, Object?>{
        'rock-foam': rock.toJson(),
        'coast-ripple': coast.toJson(),
      },
    }..remove('compatibilityWaterFxV7');

    final migrated = BaseCampMapConfiguration.tryParse(v6);

    expect(migrated, isNotNull);
    expect(migrated!.waterFx['water']!.effectiveAreas, hasLength(4));
    expect(
      migrated.compatibilityWaterFxV7.keys,
      containsAll(<String>['rock-foam', 'coast-ripple']),
    );
  });

  test('untouched legacy-derived v8 areas repair once to approved four', () {
    final defaults = BaseCampMapConfiguration.defaults();
    const rock = BaseCampWaterFx(
      mask: <Offset>[Offset(0, 800), Offset(100, 850), Offset(0, 1000)],
      shoreline: <Offset>[Offset(0, 800), Offset(100, 850)],
    );
    const coast = BaseCampWaterFx(
      mask: <Offset>[Offset(0, 100), Offset(90, 160), Offset(0, 300)],
      shoreline: <Offset>[Offset(0, 100), Offset(90, 160)],
    );
    final legacyAreas = <BaseCampWaterArea>[
      ...rock.effectiveAreas,
      ...coast.effectiveAreas,
    ];
    final oldUnified = rock.copyWith(
      areas: legacyAreas,
      mask: legacyAreas.first.mask,
      shoreline: legacyAreas.first.shoreline,
    );
    final raw = <String, Object?>{
      ...defaults.toJson(),
      'waterFx': <String, Object?>{'water': oldUnified.toJson()},
      'compatibilityWaterFxV7': <String, Object?>{
        'rock-foam': rock.toJson(),
        'coast-ripple': coast.toJson(),
      },
    };

    final repaired = BaseCampMapConfiguration.tryParse(raw)!;

    expect(repaired.waterFx['water']!.effectiveAreas, hasLength(4));
    expect(repaired.compatibilityWaterFxV7, hasLength(2));
    expect(
      BaseCampMapConfiguration.tryParse(repaired.toJson())!.toJson(),
      repaired.toJson(),
    );
  });

  test('edited v8 water never gets replaced by approved defaults', () {
    final defaults = BaseCampMapConfiguration.defaults();
    const rock = BaseCampWaterFx(
      mask: <Offset>[Offset(0, 800), Offset(100, 850), Offset(0, 1000)],
      shoreline: <Offset>[Offset(0, 800), Offset(100, 850)],
    );
    const coast = BaseCampWaterFx(
      mask: <Offset>[Offset(0, 100), Offset(90, 160), Offset(0, 300)],
      shoreline: <Offset>[Offset(0, 100), Offset(90, 160)],
    );
    final editedAreas = <BaseCampWaterArea>[
      BaseCampWaterArea(
        mask: <Offset>[...rock.mask]..[1] = const Offset(140, 860),
        shoreline: rock.shoreline,
      ),
      ...coast.effectiveAreas,
    ];
    final edited = rock.copyWith(
      areas: editedAreas,
      mask: editedAreas.first.mask,
      shoreline: editedAreas.first.shoreline,
    );
    final raw = <String, Object?>{
      ...defaults.toJson(),
      'waterFx': <String, Object?>{'water': edited.toJson()},
      'compatibilityWaterFxV7': <String, Object?>{
        'rock-foam': rock.toJson(),
        'coast-ripple': coast.toJson(),
      },
    };

    final restored = BaseCampMapConfiguration.tryParse(raw)!;

    expect(restored.waterFx['water']!.effectiveAreas, hasLength(2));
    expect(
      restored.waterFx['water']!.effectiveAreas.first.mask[1],
      const Offset(140, 860),
    );
  });

  test('multiple water areas round-trip and their union remains drawable', () {
    final defaults = BaseCampMapConfiguration.defaults();
    const first = BaseCampWaterArea(
      mask: <Offset>[
        Offset(20, 20),
        Offset(120, 20),
        Offset(120, 120),
        Offset(20, 120),
      ],
      shoreline: <Offset>[Offset(20, 90), Offset(120, 90)],
    );
    const second = BaseCampWaterArea(
      mask: <Offset>[
        Offset(960, 960),
        Offset(1080, 960),
        Offset(1080, 1080),
        Offset(960, 1080),
      ],
      shoreline: <Offset>[Offset(960, 1040), Offset(1080, 1040)],
      exclusionMasks: <List<Offset>>[
        <Offset>[Offset(990, 990), Offset(1010, 990), Offset(1010, 1010)],
      ],
    );
    final fx = defaults.waterFx['water']!.copyWith(
      areas: const <BaseCampWaterArea>[first, second],
      mask: first.mask,
      shoreline: first.shoreline,
    );
    final restored = BaseCampMapConfiguration.tryParse(
      defaults
          .copyWith(waterFx: <String, BaseCampWaterFx>{'water': fx})
          .toJson(),
    )!;
    final parsed = restored.waterFx['water']!;
    expect(parsed.effectiveAreas, hasLength(2));
    expect(parsed.effectiveAreas.first.mask, first.mask);
    expect(parsed.effectiveAreas.last.mask, second.mask);
    expect(parsed.effectiveAreas.last.exclusionMasks, second.exclusionMasks);
  });

  test('water area preserves mask shoreline and exclusion coordinates', () {
    const area = BaseCampWaterArea(
      mask: <Offset>[
        Offset(0, 0),
        Offset(200, 0),
        Offset(200, 200),
        Offset(0, 200),
      ],
      shoreline: <Offset>[Offset(0, 100), Offset(200, 100)],
      exclusionMasks: <List<Offset>>[
        <Offset>[
          Offset(40, 40),
          Offset(80, 40),
          Offset(80, 80),
          Offset(40, 80),
        ],
      ],
    );
    final effect = BaseCampWaterFx(
      mask: area.mask,
      shoreline: area.shoreline,
      areas: <BaseCampWaterArea>[area],
    );
    final restored = BaseCampWaterFx.decodeAll(<String, Object?>{
      'water': effect.toJson(),
    })!['water']!;
    expect(restored.effectiveAreas.single.mask, area.mask);
    expect(restored.effectiveAreas.single.shoreline, area.shoreline);
    expect(restored.effectiveAreas.single.exclusionMasks, area.exclusionMasks);
  });

  test('square V2.7 artwork preserves legacy coordinates without crop', () {
    final geometry = BaseCampMapGeometry.contain(const Size(390, 390));
    expect(baseCampMapArtworkSize, const Size(1254, 1254));
    expect(geometry.imageRect, const Rect.fromLTWH(0, 0, 390, 390));
    for (final source in <Offset>[
      Offset.zero,
      const Offset(640, 360),
      const Offset(1280, 720),
    ]) {
      final viewport = geometry.sourceToViewport(source);
      expect(geometry.viewportToSource(viewport).dx, closeTo(source.dx, .001));
      expect(geometry.viewportToSource(viewport).dy, closeTo(source.dy, .001));
    }
  });

  test('default water masks use the full square artwork coordinate space', () {
    for (final fx in BaseCampWaterFx.defaults().values) {
      expect(fx.mask, hasLength(greaterThanOrEqualTo(3)));
      expect(
        fx.mask.every(
          (point) => point.dx >= 0 && point.dx <= baseCampMapArtworkSize.width,
        ),
        isTrue,
      );
      expect(
        fx.mask.every(
          (point) => point.dy >= 0 && point.dy <= baseCampMapArtworkSize.height,
        ),
        isTrue,
      );
    }
  });

  test('v5 water coordinates migrate once into square artwork coordinates', () {
    final defaults = BaseCampMapConfiguration.defaults();
    const rock = BaseCampWaterFx(
      mask: <Offset>[Offset(0, 800), Offset(100, 850), Offset(0, 1000)],
      shoreline: <Offset>[Offset(0, 800), Offset(100, 850)],
    );
    const coast = BaseCampWaterFx(
      mask: <Offset>[Offset(0, 100), Offset(90, 160), Offset(0, 300)],
      shoreline: <Offset>[Offset(0, 100), Offset(90, 160)],
    );
    final source = <String, BaseCampWaterFx>{
      'rock-foam': rock,
      'coast-ripple': coast,
    };
    List<Object?> toLegacy(List<Offset> points) => points
        .map(
          (point) => <String, double>{
            'x': point.dx * 1280 / 1254,
            'y': point.dy * 720 / 1254,
          },
        )
        .toList();
    final legacyWater = <String, Object?>{
      for (final entry in source.entries)
        entry.key: <String, Object?>{
          ...entry.value.toJson(),
          'mask': toLegacy(entry.value.mask),
          'shoreline': toLegacy(entry.value.shoreline),
          'exclusionMasks': const <Object?>[],
        },
    };
    final legacy = <String, Object?>{
      ...defaults.toJson(),
      'schemaVersion': 5,
      'waterFx': legacyWater,
    }..remove('compatibilityWaterFxV7');

    final restored = BaseCampMapConfiguration.tryParse(legacy);

    expect(restored, isNotNull);
    expect(restored!.routes, defaults.routes);
    for (final id in source.keys) {
      final expected = source[id]!.mask;
      final actual = restored.compatibilityWaterFxV7[id]!.mask;
      expect(actual, hasLength(expected.length));
      for (var index = 0; index < expected.length; index++) {
        expect(actual[index].dx, closeTo(expected[index].dx, .01));
        expect(actual[index].dy, closeTo(expected[index].dy, .01));
      }
    }
    expect(
      restored.toJson()['schemaVersion'],
      BaseCampMapConfiguration.schemaVersion,
    );
  });

  test('water focus transforms centre both editable water masks', () {
    const viewport = Size(390, 420);
    for (final effect in BaseCampWaterFx.defaults().values) {
      final transform = baseCampWaterFocusTransform(
        effect: effect,
        viewport: viewport,
      );
      final artworkBounds = Rect.fromPoints(
        effect.mask.reduce(
          (a, b) =>
              Offset(a.dx < b.dx ? a.dx : b.dx, a.dy < b.dy ? a.dy : b.dy),
        ),
        effect.mask.reduce(
          (a, b) =>
              Offset(a.dx > b.dx ? a.dx : b.dx, a.dy > b.dy ? a.dy : b.dy),
        ),
      );
      final geometry = BaseCampMapGeometry.contain(baseCampMapArtworkSize);
      final bounds = Rect.fromPoints(
        geometry.artworkToViewport(artworkBounds.topLeft),
        geometry.artworkToViewport(artworkBounds.bottomRight),
      );
      final storage = transform.storage;
      final focusedCenter = Offset(
        bounds.center.dx * storage[0] + storage[12],
        bounds.center.dy * storage[5] + storage[13],
      );

      expect(focusedCenter.dx, closeTo(viewport.width / 2, .01));
      expect(focusedCenter.dy, closeTo(viewport.height / 2, .01));
    }
  });

  test('facility outlines are independent irregular perimeters', () {
    expect(baseCampFacilities, hasLength(5));
    for (final facility in baseCampFacilities) {
      final outline = facility.outline();
      expect(outline.length, greaterThan(4));
      expect(outline.every((point) => point.dx >= 0 && point.dx <= 1), isTrue);
      expect(outline.every((point) => point.dy >= 0 && point.dy <= 1), isTrue);
    }
  });

  test('approved v2 object defaults retain the frozen placements', () {
    final objects = BaseCampMapConfiguration.defaults().objects;
    expect(
      objects['status']!.position,
      const Offset(293.9966913479477, 397.1475629664179),
    );
    expect(objects['status']!.animationRate, .5);
    expect(
      objects['food']!.position,
      const Offset(673.9635319496268, 280.3980099502487),
    );
    expect(objects['food']!.assetId, 'command-center');
    expect(
      objects['command-center']!.position,
      const Offset(938.2420903296019, 640.1990049751244),
    );
    expect(objects['command-center']!.assetId, 'food');
    expect(
      objects['flag']!.position,
      const Offset(1195.0912430037313, 563.7810945273632),
    );
  });

  test(
    'v2 facility identity migration is idempotent and preserves art slots',
    () {
      final current = BaseCampMapConfiguration.defaults();
      final oldObjects = <String, Object?>{
        for (final entry in current.objects.entries)
          entry.key: entry.value.toJson(),
      };
      // Reconstruct the pre-correction identity payload: food held the lower
      // food art and command-center held the upper command-center art.
      oldObjects['food'] = <String, Object?>{
        ...current.objects['command-center']!.toJson(),
        'id': 'food',
      };
      oldObjects['command-center'] = <String, Object?>{
        ...current.objects['food']!.toJson(),
        'id': 'command-center',
      };
      oldObjects['status'] = <String, Object?>{
        ...current.objects['status']!.toJson(),
        'assetId': 'legacy-status-import',
      };
      final v2 = <String, Object?>{
        ...current.toJson(),
        'schemaVersion': 2,
        'objects': oldObjects,
      };
      final migrated = BaseCampMapConfiguration.tryParse(v2)!;
      expect(migrated.objects['food']!.assetId, 'command-center');
      expect(migrated.objects['command-center']!.assetId, 'food');
      expect(migrated.objects['status']!.assetId, 'status');
      expect(
        BaseCampMapConfiguration.tryParse(migrated.toJson())!.toJson(),
        migrated.toJson(),
      );
    },
  );

  test(
    'map editor configuration validates the shared routes, outlines and scale',
    () {
      final defaults = BaseCampMapConfiguration.defaults();
      final restored = BaseCampMapConfiguration.tryParse(defaults.toJson());
      expect(restored, isNotNull);
      expect(
        restored!.routes.keys,
        containsAll(<String>['route-a', 'route-b', 'route-c']),
      );
      expect(restored.facilityOutlines.keys, hasLength(5));
      expect(restored.soldierScale, 1);
      expect(restored.foodSmokeOrigin, const Offset(.29, .26));
      expect(
        BaseCampMapConfiguration.tryParse(<String, Object?>{
          ...defaults.toJson(),
          'soldierScale': double.nan,
        }),
        isNull,
      );
    },
  );

  test('v3 map configuration adds the FOOD-local smoke origin losslessly', () {
    final current = BaseCampMapConfiguration.defaults();
    final v3 = <String, Object?>{...current.toJson(), 'schemaVersion': 3}
      ..remove('foodSmokeOrigin');
    final migrated = BaseCampMapConfiguration.tryParse(v3);
    expect(migrated, isNotNull);
    expect(migrated!.routes, current.routes);
    expect(
      migrated.objects.map((id, object) => MapEntry(id, object.toJson())),
      current.objects.map((id, object) => MapEntry(id, object.toJson())),
    );
    expect(migrated.foodSmokeOrigin, const Offset(.29, .26));
  });

  test(
    'FOOD-local smoke point follows the same object transform as its art',
    () {
      final food = BaseCampMapConfiguration.defaults().objects['food']!;
      const local = Offset(.29, .26);
      final source = baseCampObjectLocalToSource(food, local);
      final restored = baseCampSourceToObjectLocal(food, source);
      expect(restored.dx, closeTo(local.dx, .0001));
      expect(restored.dy, closeTo(local.dy, .0001));
    },
  );

  test('map editor persists the common soldier multiplier', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = BaseCampMapConfigurationController(
      approvedWaterGeometryLoader: _loadApprovedWaterGeometry,
    );
    await controller.load();
    await controller.save(
      controller.value.copyWith(
        soldierScale: 2 / 3,
        foodSmokeOrigin: const Offset(.31, .22),
      ),
    );

    final restored = BaseCampMapConfigurationController(
      approvedWaterGeometryLoader: _loadApprovedWaterGeometry,
    );
    await restored.load();
    expect(restored.value.soldierScale, closeTo(2 / 3, .0001));
    expect(restored.value.foodSmokeOrigin, const Offset(.31, .22));
    expect(
      restored.value.routes['route-b'],
      controller.value.routes['route-b'],
    );
    expect(
      restored.value.routes['route-c'],
      controller.value.routes['route-c'],
    );
  });

  test('water draft round-trips separately from formal map data', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final defaults = BaseCampMapConfiguration.defaults();
    final fifth = const BaseCampWaterArea(
      mask: <Offset>[Offset(500, 500), Offset(600, 500), Offset(600, 600)],
      shoreline: <Offset>[Offset(500, 550), Offset(600, 550)],
    );
    final effect = defaults.waterFx['water']!;
    final edited = defaults.copyWith(
      waterFx: <String, BaseCampWaterFx>{
        'water': effect.copyWith(
          areas: <BaseCampWaterArea>[...effect.effectiveAreas, fifth],
        ),
      },
    );
    final store = BaseCampWaterDraftStore();

    await store.save(edited);
    final result = await store.load();
    final restored = result.draft!.applyTo(defaults);
    final preferences = await SharedPreferences.getInstance();

    expect(result.state, BaseCampWaterDraftState.ready);
    expect(restored.waterFx['water']!.effectiveAreas, hasLength(5));
    expect(
      preferences.getString(BaseCampMapConfigurationController.storageKey),
      isNull,
    );
    expect(
      preferences.getString(BaseCampWaterDraftStore.storageKey),
      isNotNull,
    );
  });

  test('corrupt and incompatible water drafts remain recoverable', () async {
    for (final payload in <String>[
      '{broken',
      '{"draftSchemaVersion":99,"mapSchemaVersion":8,"mapId":"base-camp-map-v2"}',
    ]) {
      SharedPreferences.setMockInitialValues(<String, Object>{
        BaseCampWaterDraftStore.storageKey: payload,
      });
      final result = await BaseCampWaterDraftStore().load();
      final preferences = await SharedPreferences.getInstance();

      expect(result.state, BaseCampWaterDraftState.corrupt);
      expect(
        preferences.getString(BaseCampWaterDraftStore.storageKey),
        payload,
      );
    }
  });

  test(
    'water draft write failure is surfaced without formal mutation',
    () async {
      final store = BaseCampWaterDraftStore(
        preferencesLoader: () async => throw StateError('storage denied'),
      );

      await expectLater(
        store.save(BaseCampMapConfiguration.defaults()),
        throwsStateError,
      );
    },
  );

  test('formal save publishes only after durable storage succeeds', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    var loads = 0;
    final controller = BaseCampMapConfigurationController(
      approvedWaterGeometryLoader: _loadApprovedWaterGeometry,
      preferencesLoader: () async {
        loads++;
        if (loads > 1) throw StateError('storage denied');
        return preferences;
      },
    );
    await controller.load();
    final original = controller.value;
    final edited = original.copyWith(soldierScale: .5);

    await expectLater(controller.save(edited), throwsStateError);

    expect(controller.value.encode(), original.encode());
  });

  test(
    'obsolete 2/1 multiplier migrates to 1/1 without losing map edits',
    () async {
      final edited = BaseCampMapConfiguration.defaults().copyWith(
        routes: <String, List<Offset>>{
          ...BaseCampMapConfiguration.defaults().routes,
          'route-b': const <Offset>[Offset(901, 300), Offset(1010, 360)],
        },
        soldierScale: 2,
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        BaseCampMapConfigurationController.storageKey: edited.encode(),
      });
      final controller = BaseCampMapConfigurationController(
        approvedWaterGeometryLoader: _loadApprovedWaterGeometry,
      );
      await controller.load();
      expect(controller.value.soldierScale, 1);
      expect(controller.value.routes['route-b'], edited.routes['route-b']);
      expect(
        (await SharedPreferences.getInstance()).getString(
          BaseCampMapConfigurationController.storageKey,
        ),
        contains('"soldierScale":1.0'),
      );
    },
  );

  test('shared source geometry round-trips for cover and editor fit', () {
    const source = Offset(808, 604);
    for (final geometry in [
      BaseCampMapGeometry.cover(const Size(390, 220)),
      BaseCampMapGeometry.contain(const Size(390, 600)),
    ]) {
      final roundTrip = geometry.viewportToSource(
        geometry.sourceToViewport(source),
      );
      expect(roundTrip.dx, closeTo(source.dx, .001));
      expect(roundTrip.dy, closeTo(source.dy, .001));
    }
  });

  testWidgets('long press on framing RESET opens the Base Camp map editor', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BaseCampMap(onFacilityPressed: _ignoreFacility)),
      ),
    );
    await tester.longPress(find.byKey(const ValueKey('base-camp-reset')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('BASE CAMP MAP EDITOR'), findsOneWidget);
    expect(find.text('1/1'), findsNothing);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(-520, 0),
    );
    await tester.pump();
    await tester.tap(find.text('SOLDIER SIZE'));
    await tester.pump();
    expect(find.text('1/1'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('2/1'), findsNothing);
    expect(find.byKey(const ValueKey('base-camp-editor-map')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('base-camp-editor-reset-view')),
      findsOneWidget,
    );
    await tester.tap(find.text('SMOKE ORIGIN'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('base-camp-editor-smoke-origin')),
      findsOneWidget,
    );
    expect(find.textContaining('FOOD chimney tip'), findsOneWidget);
  });

  test('walkers use continuous, periodic path sampling and endpoint stops', () {
    for (final route in baseCampWalkerRoutes) {
      final cycle = baseCampWalkerCycleDuration(route.id);
      final start = baseCampWalkerPose(route.id, Duration.zero);
      final end = baseCampWalkerPose(route.id, cycle);
      expect(end.sourcePosition.dx, closeTo(start.sourcePosition.dx, .001));
      expect(end.sourcePosition.dy, closeTo(start.sourcePosition.dy, .001));
    }

    // Route B enters its explicit 3.2 second end-stop after its forward leg.
    expect(
      baseCampWalkerPose('route-b', const Duration(seconds: 6)).isWalking,
      isFalse,
    );
    expect(
      baseCampWalkerPose('route-c', const Duration(seconds: 3)).isWalking,
      isTrue,
    );
    expect(
      baseCampWalkerPose('route-b', Duration.zero).usesDownRightAsset,
      isTrue,
    );
    expect(
      baseCampWalkerPose(
        'route-b',
        const Duration(seconds: 10),
      ).usesDownRightAsset,
      isFalse,
    );
  });

  test('walker assets are the supplied paired directional GIFs', () {
    expect(
      baseCampWalkerDownRightAsset,
      endsWith('base_camp_walker_down_right.gif'),
    );
    expect(baseCampWalkerUpLeftAsset, endsWith('base_camp_walker_up_left.gif'));
  });

  test(
    'approved walker frames are full RGBA assets with transparent backgrounds',
    () async {
      for (final frames in [
        baseCampWalkerDownRightFrames,
        baseCampWalkerUpLeftFrames,
      ]) {
        expect(frames, isNotEmpty);
        for (final asset in frames) {
          final data = await rootBundle.load(asset);
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(),
          );
          final frame = await codec.getNextFrame();
          final bytes = await frame.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          expect(frame.image.width, 360, reason: asset);
          expect(frame.image.height, 600, reason: asset);
          final pixels = bytes!.buffer.asUint8List();
          final transparent = <int>[];
          for (var index = 3; index < pixels.length; index += 4) {
            transparent.add(pixels[index]);
          }
          expect(transparent.any((alpha) => alpha == 0), isTrue, reason: asset);
          expect(
            transparent.any((alpha) => alpha == 255),
            isTrue,
            reason: asset,
          );
          frame.image.dispose();
          codec.dispose();
        }
      }
    },
  );

  test('approved STATUS GIF is a transparent six-frame animation', () async {
    final data = await rootBundle.load(baseCampObjectAssets['status']!);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    expect(codec.frameCount, 6);
    for (var index = 0; index < codec.frameCount; index++) {
      final frame = await codec.getNextFrame();
      final rgba = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final pixels = rgba!.buffer.asUint8List();
      expect(frame.image.width, 281);
      expect(frame.image.height, 133);
      expect(frame.duration, const Duration(milliseconds: 700));
      final alphas = <int>[
        for (var pixel = 3; pixel < pixels.length; pixel += 4) pixels[pixel],
      ];
      expect(alphas, contains(0));
      expect(alphas, contains(255));
      frame.image.dispose();
    }
    codec.dispose();
  });

  testWidgets('two GIF walkers remain present with reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: BaseCampMap(onFacilityPressed: _ignoreFacility),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('base-camp-walkers')), findsOneWidget);
    expect(find.byKey(const ValueKey('base-camp-food-smoke')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('base-camp-walker-route-b')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('base-camp-walker-route-c')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('base-camp-personnel')), findsNothing);
  });

  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    testWidgets('Base Camp map has no overflow at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BaseCampMap(onFacilityPressed: (_) {})),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });
  }
}

void _ignoreFacility(BaseCampFacility _) {}

Future<void> _tapOpaqueFacility(WidgetTester tester, String facilityId) async {
  final finder = find.byKey(ValueKey('base-camp-facility-$facilityId'));
  final rect = tester.getRect(finder);
  // Facility images intentionally have transparent margins.  Search a compact
  // interior grid rather than treating the image's rectangular layout box as
  // an interactive region.
  for (var iy = 1; iy < 20; iy++) {
    final y = iy / 20;
    for (var ix = 1; ix < 20; ix++) {
      final x = ix / 20;
      await tester.tapAt(
        Offset(rect.left + rect.width * x, rect.top + rect.height * y),
      );
      await tester.pump();
      final label = baseCampFacilities
          .firstWhere((facility) => facility.id == facilityId)
          .label;
      if (find.text(label).evaluate().isNotEmpty) {
        return;
      }
    }
  }
  fail('No opaque pixel was selectable for $facilityId in $rect');
}

Future<void> _pumpUntilFacilityLayer(WidgetTester tester) async {
  final finder = find.byKey(const ValueKey('base-camp-facility-object-layer'));
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    if (finder.evaluate().isNotEmpty) {
      await tester.pump();
      return;
    }
  }
  fail('Facility object layer was not revealed.');
}

Future<void> _pumpUntilWaterFx(WidgetTester tester) async {
  final finder = find.byKey(const ValueKey('base-camp-water-fx'));
  for (var attempt = 0; attempt < 300; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    if (finder.evaluate().isNotEmpty) {
      await tester.pump();
      return;
    }
  }
  fail('Water FX did not initialize after the facility layer.');
}

Future<String> _loadApprovedWaterGeometry() async =>
    File('assets/data/WATER_IMPORT_CORRECTED.json').readAsStringSync();
