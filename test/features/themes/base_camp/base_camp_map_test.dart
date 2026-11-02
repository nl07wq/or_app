import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_configuration.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
      for (var index = 0; index < baseCampFacilities.length; index++) {
        final facility = baseCampFacilities[index];
        await tester.tap(
          find.byKey(ValueKey('base-camp-facility-${facility.id}')),
        );
        await tester.pump();
        expect(selected, hasLength(index));
        expect(
          find.byKey(const ValueKey('base-camp-selection-frame')),
          findsOneWidget,
        );
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

    await tester.drag(
      find.byKey(const ValueKey('base-camp-map')),
      const Offset(40, 0),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('base-camp-reset')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('base-camp-facility-command-center')),
    );
    await tester.pump();
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

    await tester.tap(find.byKey(const ValueKey('base-camp-facility-status')));
    await tester.pump();
    expect(find.text('STATUS'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('base-camp-facility-food')));
    await tester.pump();
    expect(find.text('FOOD'), findsOneWidget);
    expect(selected, isEmpty);
    await tester.tap(find.byKey(const ValueKey('base-camp-confirm-no')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('base-camp-selection-frame')),
      findsNothing,
    );
    expect(selected, isEmpty);
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
      closeTo(.840, .001),
    );
    for (final route in baseCampWalkerRoutes) {
      expect(
        route.pausePatternSeconds,
        everyElement(inInclusiveRange(2.0, 4.0)),
      );
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
      expect(
        BaseCampMapConfiguration.tryParse(<String, Object?>{
          ...defaults.toJson(),
          'soldierScale': double.nan,
        }),
        isNull,
      );
    },
  );

  test('map editor persists the common soldier multiplier', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = BaseCampMapConfigurationController();
    await controller.load();
    await controller.save(controller.value.copyWith(soldierScale: 2 / 3));

    final restored = BaseCampMapConfigurationController();
    await restored.load();
    expect(restored.value.soldierScale, closeTo(2 / 3, .0001));
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
