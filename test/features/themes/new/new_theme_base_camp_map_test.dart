import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/features/themes/new/widgets/base_camp_map.dart';

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
      AppPresentationTheme.newTheme,
    );
  });

  testWidgets('all five normalised Base Camp facilities navigate by callback', (
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

    expect(baseCampFacilities, hasLength(5));
    for (final facility in baseCampFacilities) {
      await tester.tap(
        find.byKey(ValueKey('new-theme-base-camp-facility-${facility.id}')),
      );
      await tester.pump();
    }

    expect(
      selected,
      baseCampFacilities.map((facility) => facility.id).toList(),
    );
  });

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
      find.byKey(const ValueKey('new-theme-base-camp-map')),
      const Offset(40, 0),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('new-theme-base-camp-reset')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('new-theme-base-camp-facility-command-center')),
    );
    await tester.pump();

    expect(selected, 'command-center');
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

    final status = find.byKey(
      const ValueKey('new-theme-base-camp-facility-status'),
    );
    final gesture = await tester.startGesture(tester.getCenter(status));
    await gesture.moveBy(const Offset(56, 8));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 180));

    expect(selected, isNull);
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
