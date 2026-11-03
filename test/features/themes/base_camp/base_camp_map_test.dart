import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_configuration.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_map.dart';
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
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
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
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

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
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

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
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
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

  test('v5 FX, labels, water and static soldiers round-trip losslessly', () {
    final defaults = BaseCampMapConfiguration.defaults().copyWith(
      staticSoldiers: const [
        BaseCampStaticSoldier(
          id: 'guard-1',
          position: Offset(421, 315),
          direction: 'left',
          scale: .8,
          breathingIntensity: .5,
          breathingPeriod: 4,
        ),
      ],
    );
    final restored = BaseCampMapConfiguration.tryParse(defaults.toJson());
    expect(restored, isNotNull);
    expect(restored!.smokeFx.toJson(), defaults.smokeFx.toJson());
    expect(
      restored.labels['food']!.toJson(),
      defaults.labels['food']!.toJson(),
    );
    expect(
      restored.waterFx['rock-foam']!.toJson(),
      defaults.waterFx['rock-foam']!.toJson(),
    );
    expect(
      restored.staticSoldiers.single.toJson(),
      defaults.staticSoldiers.single.toJson(),
    );
  });

  test('existing v5 label and water settings migrate new FX fields safely', () {
    final defaults = BaseCampMapConfiguration.defaults();
    final payload = Map<String, Object?>.from(defaults.toJson());
    final labels = <String, Object?>{
      for (final entry in (payload['labels'] as Map).entries)
        entry.key as String: Map<String, Object?>.from(entry.value as Map)
          ..remove('startX')
          ..remove('startY'),
    };
    final waterFx = <String, Object?>{
      for (final entry in (payload['waterFx'] as Map).entries)
        entry.key as String: Map<String, Object?>.from(entry.value as Map)
          ..remove('shimmerDensity')
          ..remove('shimmerBrightness')
          ..remove('shimmerSpeed')
          ..remove('flowDistortion')
          ..remove('foamIntensity'),
    };
    payload['labels'] = labels;
    payload['waterFx'] = waterFx;

    final restored = BaseCampMapConfiguration.tryParse(payload);

    expect(restored, isNotNull);
    expect(restored!.labels['food']!.connectorStart, const Offset(500, 155));
    expect(restored.waterFx['rock-foam']!.shimmerDensity, 1);
    expect(restored.waterFx['rock-foam']!.flowDistortion, 1);
    expect(restored.waterFx['coast-ripple']!.foamIntensity, 1);
  });

  test(
    'default water masks are constrained to the visible left water edge',
    () {
      for (final fx in BaseCampWaterFx.defaults().values) {
        expect(fx.mask, hasLength(greaterThanOrEqualTo(3)));
        expect(
          fx.mask.every((point) => point.dx >= 0 && point.dx <= 86),
          isTrue,
        );
        expect(
          fx.mask.every((point) => point.dy >= 0 && point.dy <= 720),
          isTrue,
        );
      }
    },
  );

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
    final controller = BaseCampMapConfigurationController();
    await controller.load();
    await controller.save(
      controller.value.copyWith(
        soldierScale: 2 / 3,
        foodSmokeOrigin: const Offset(.31, .22),
      ),
    );

    final restored = BaseCampMapConfigurationController();
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
      final controller = BaseCampMapConfigurationController();
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
