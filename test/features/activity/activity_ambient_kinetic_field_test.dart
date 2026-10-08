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

  test('uses a bounded six-group luminous filament swarm', () {
    expect(ActivityAmbientKineticField.luminousFilamentCount, 168);
    expect(ActivityAmbientKineticField.luminousFilamentCount, greaterThan(84));
    expect(ActivityAmbientKineticField.luminousFilamentGroupCount, 6);
    expect(ActivityAmbientKineticField.luminousFilamentSegments, 3);
    expect(
      ActivityAmbientKineticField.luminousFilamentDrawOperationsPerFrame,
      504,
    );
  });

  test('uses radius-aware viewport bounds for the complete scope', () {
    const painterSize = Size(390, 788);
    final samples = [
      for (var index = 0; index <= 200; index++)
        ActivityAmbientKineticField.scopeGeometryFor(
          painterSize: painterSize,
          phase: index / 200,
        ),
    ];
    final lowest = samples.reduce(
      (current, candidate) =>
          candidate.center.dy > current.center.dy ? candidate : current,
    );

    expect(lowest.center.dy, greaterThan(painterSize.height * .75));
    expect(lowest.scopeBounds.top, greaterThanOrEqualTo(0));
    expect(lowest.scopeBounds.bottom, lessThanOrEqualTo(painterSize.height));
    expect(lowest.visibleScopeBounds.bottom, lowest.scopeBounds.bottom);
  });

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

  testWidgets('renders a luminous curved-filament swarm at the initial phase', (
    tester,
  ) async {
    await pumpField(tester, enabled: true);
    await expectLater(
      find.byKey(ActivityAmbientKineticField.fieldKey),
      matchesGoldenFile(
        'goldens/activity_kinetic_measurement_filament_swarm.png',
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

  testWidgets('travels with the filament swarm into the lower viewport', (
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
    'ActivityPage paints the scope below RECORD in its actual Scaffold body',
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
      expect(
        field.top + activeGeometry.center.dy,
        greaterThan(tester.getRect(find.text('RECORD').last).bottom),
      );
      expect(
        field.top + activeGeometry.visibleScopeBounds.bottom,
        closeTo(field.bottom - ActivityAmbientKineticField.scopeBottomInset, 1),
      );
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
