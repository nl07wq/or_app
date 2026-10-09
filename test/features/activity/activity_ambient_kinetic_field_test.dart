import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/features/activity/activity_page.dart';
import 'package:or_app/features/activity/widgets/activity_ambient_kinetic_field.dart';

void main() {
  test('coordinates detect track measure and accumulation causally', () {
    final detect = ActivityAmbientKineticField.sampleFor(
      region: 0,
      elapsedSeconds: 0,
    );
    final track = ActivityAmbientKineticField.sampleFor(
      region: 0,
      elapsedSeconds: 4,
    );
    final measure = ActivityAmbientKineticField.sampleFor(
      region: 0,
      elapsedSeconds: 10.8,
    );
    final accumulate = ActivityAmbientKineticField.sampleFor(
      region: 0,
      elapsedSeconds: 12.7,
    );

    expect(detect.phase, ActivityKineticPhase.detect);
    expect(track.phase, ActivityKineticPhase.track);
    expect(track.pathProgress, inInclusiveRange(0, 1));
    expect(measure.phase, ActivityKineticPhase.measure);
    expect(measure.signalProgress, greaterThan(0));
    expect(accumulate.phase, ActivityKineticPhase.accumulate);
    expect(accumulate.signalProgress, 1);
    expect(accumulate.accumulationProgress, greaterThan(0));
  });

  test('regions remain asynchronous and avoid a global reset', () {
    final phases = <ActivityKineticPhase>{
      for (
        var region = 0;
        region < ActivityAmbientKineticField.trackingRegionCount;
        region++
      )
        ActivityAmbientKineticField.sampleFor(
          region: region,
          elapsedSeconds: 4,
        ).phase,
    };
    expect(phases.length, greaterThan(2));
  });

  test('uses a dense, layered coordinated luminous filament swarm', () {
    expect(ActivityAmbientKineticField.luminousFilamentCount, 768);
    expect(ActivityAmbientKineticField.luminousFilamentGroupCount, 8);
    expect(ActivityAmbientKineticField.polygonFamilyCount, 8);
    expect(ActivityAmbientKineticField.polygonVariantsPerFamily, 4);
    expect(ActivityAmbientKineticField.strandsPerPolygonVariant, 24);
    expect(ActivityAmbientKineticField.luminousFilamentLayers, 3);
    expect(
      ActivityAmbientKineticField.luminousFilamentDrawOperationsPerFrame,
      2304,
    );
  });

  test('puts visible thickness in the core and keeps the halo restrained', () {
    expect(ActivityAmbientKineticField.filamentCoreBaseWidth, greaterThan(.56));
    expect(
      ActivityAmbientKineticField.filamentCoreBaseWidth +
          ActivityAmbientKineticField.filamentCoreDepthWidth,
      greaterThan(1.04),
    );
    expect(ActivityAmbientKineticField.filamentHaloBaseWidth, lessThan(3.9));
    expect(ActivityAmbientKineticField.filamentHaloBlurSigma, lessThan(2.2));
  });

  test(
    'redistributes a populated swarm instead of retaining an annular band',
    () {
      final early = ActivityAmbientKineticField.swarmMetricsFor(0);
      final later = ActivityAmbientKineticField.swarmMetricsFor(8.7);

      // The center is occupied and the radius has a real spread, so this is not
      // a hollow ring. Time-varying pair distances prove that agents exchange
      // local relationships instead of rotating as a fixed arrangement.
      expect(early.centerPopulation, greaterThan(.20));
      expect(later.centerPopulation, greaterThan(.20));
      expect(early.radialSpread, greaterThan(.08));
      expect(later.radialSpread, greaterThan(.08));
      expect(
        (later.neighborSignature - early.neighborSignature).abs(),
        greaterThan(.001),
      );
      expect((later.meanRadius - early.meanRadius).abs(), greaterThan(.0004));
    },
  );

  test(
    'advances swarm time continuously across outer-scope cycle boundaries',
    () {
      final before = ActivityAmbientKineticField.swarmSecondsFor(
        cycle: 0,
        phase: .999,
      );
      final after = ActivityAmbientKineticField.swarmSecondsFor(
        cycle: 1,
        phase: 0,
      );
      expect(after, greaterThan(before));
      expect(after - before, lessThan(.02));
    },
  );

  test(
    'keeps the phase-one scope and swarm center stationary in its viewport',
    () {
      const painterSize = Size(390, 788);
      final samples = [
        for (var index = 0; index <= 200; index++)
          ActivityAmbientKineticField.scopeGeometryFor(
            painterSize: painterSize,
            phase: index / 200,
          ),
      ];
      for (final geometry in samples) {
        expect(geometry.center.dx, closeTo(painterSize.width / 2, .001));
        expect(geometry.center.dy, closeTo(painterSize.height / 2, .001));
        expect(geometry.scopeBounds.top, greaterThanOrEqualTo(0));
        expect(
          geometry.scopeBounds.bottom,
          lessThanOrEqualTo(painterSize.height),
        );
        expect(geometry.visibleScopeBounds, geometry.scopeBounds);
      }
    },
  );

  Future<void> pumpField(
    WidgetTester tester, {
    required bool enabled,
    bool reducedMotion = false,
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: ActivityAmbientKineticField(enabled: enabled),
                ),
                const Center(child: Text('ACTIVITY CONTENT')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders behind Activity content without intercepting input', (
    tester,
  ) async {
    await pumpField(tester, enabled: true);
    expect(find.byKey(ActivityAmbientKineticField.fieldKey), findsOneWidget);
    final ancestors = tester.widgetList<IgnorePointer>(
      find.ancestor(
        of: find.byKey(ActivityAmbientKineticField.fieldKey),
        matching: find.byType(IgnorePointer),
      ),
    );
    expect(ancestors.any((widget) => widget.ignoring), isTrue);
    expect(find.text('ACTIVITY CONTENT'), findsOneWidget);
  });

  testWidgets('suppresses the field immediately when disabled', (tester) async {
    await pumpField(tester, enabled: false);
    expect(find.byKey(ActivityAmbientKineticField.fieldKey), findsNothing);
  });

  testWidgets('renders a valid static measurement field for reduced motion', (
    tester,
  ) async {
    await pumpField(tester, enabled: true, reducedMotion: true);
    await expectLater(
      find.byKey(ActivityAmbientKineticField.fieldKey),
      matchesGoldenFile('goldens/activity_kinetic_measurement_static.png'),
    );
  });

  testWidgets('renders a dense layered filament swarm at the initial phase', (
    tester,
  ) async {
    await pumpField(tester, enabled: true);
    await expectLater(
      find.byKey(ActivityAmbientKineticField.fieldKey),
      matchesGoldenFile(
        'goldens/activity_kinetic_measurement_vortex_prototype.png',
      ),
    );
  });

  testWidgets('renders tracking state with target-derived trajectory history', (
    tester,
  ) async {
    await pumpField(tester, enabled: true);
    await tester.pump(const Duration(seconds: 4));
    await expectLater(
      find.byKey(ActivityAmbientKineticField.fieldKey),
      matchesGoldenFile('goldens/activity_kinetic_measurement_tracking.png'),
    );
  });

  testWidgets('renders measurement signal and accumulated activity ticks', (
    tester,
  ) async {
    await pumpField(tester, enabled: true);
    await tester.pump(const Duration(milliseconds: 12000));
    await expectLater(
      find.byKey(ActivityAmbientKineticField.fieldKey),
      matchesGoldenFile('goldens/activity_kinetic_measurement_accumulated.png'),
    );
  });

  testWidgets('keeps the scope stationary while living filaments evolve', (
    tester,
  ) async {
    await pumpField(tester, enabled: true);
    await tester.pump(const Duration(seconds: 1));
    await expectLater(
      find.byKey(ActivityAmbientKineticField.fieldKey),
      matchesGoldenFile(
        'goldens/activity_kinetic_measurement_lower_viewport.png',
      ),
    );
  });

  testWidgets(
    'ActivityPage gives the stationary phase-one scope its full Scaffold body',
    (tester) async {
      final originalSettings = DeviceSettingsController.instance.value;
      DeviceSettingsController.instance.resetForTesting(
        const DeviceSettings(ambientKineticFieldEnabled: true),
      );
      addTearDown(
        () =>
            DeviceSettingsController.instance.resetForTesting(originalSettings),
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ActivityAmbientKineticField.debugLastPaintGeometry = null;
      addTearDown(
        () => ActivityAmbientKineticField.debugLastPaintGeometry = null,
      );

      await tester.pumpWidget(const MaterialApp(home: ActivityPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));

      final field = tester.getRect(
        find.byKey(ActivityAmbientKineticField.fieldKey),
      );
      final geometry = ActivityAmbientKineticField.debugLastPaintGeometry;
      expect(geometry, isNotNull);
      final activeGeometry = geometry!;
      expect(activeGeometry.painterSize.width, closeTo(field.width, .1));
      expect(activeGeometry.painterSize.height, closeTo(field.height, .1));
      expect(field.height, greaterThan(700));
      expect(activeGeometry.scopeBounds.top, greaterThanOrEqualTo(0));
      expect(
        activeGeometry.scopeBounds.bottom,
        lessThanOrEqualTo(activeGeometry.painterSize.height),
      );
      expect(
        activeGeometry.visibleScopeBounds.top,
        activeGeometry.scopeBounds.top,
      );
      expect(
        activeGeometry.visibleScopeBounds.bottom,
        activeGeometry.scopeBounds.bottom,
      );
      expect(activeGeometry.center, Offset(field.width / 2, field.height / 2));
      expect(field.top + activeGeometry.center.dy, greaterThan(0));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/activity_scope_below_record.png'),
      );
    },
  );

  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('keeps a bounded field at $width px', (tester) async {
      await pumpField(tester, enabled: true, width: width);
      expect(
        tester.getRect(find.byKey(ActivityAmbientKineticField.fieldKey)).width,
        closeTo(width, 1),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
