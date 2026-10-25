import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/morning/widgets/body_card.dart';

void main() {
  Widget app(
    TextEditingController weight,
    TextEditingController bodyFat, {
    bool initiallyExpanded = false,
    double textScale = 1,
  }) => MaterialApp(
    theme: ThemeData.dark(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: BodyCard(
          weightController: weight,
          bodyFatController: bodyFat,
          weightUnmeasured: false,
          onWeightUnmeasured: () {},
          onWeightMeasured: () {},
          initiallyExpanded: initiallyExpanded,
        ),
      ),
    ),
  );

  testWidgets('weight completion action is below the 206dp tape artwork', (
    tester,
  ) async {
    final weight = TextEditingController();
    final bodyFat = TextEditingController();
    addTearDown(weight.dispose);
    addTearDown(bodyFat.dispose);
    await tester.pumpWidget(app(weight, bodyFat));
    final hud = tester.getRect(find.byKey(const ValueKey('status-weight-hud')));
    final done = tester.getRect(
      find.byKey(const ValueKey('status-weight-done')),
    );
    expect(done.top, greaterThanOrEqualTo(hud.top + 214));
    expect(
      tester.getSize(find.byKey(const ValueKey('status-weight-tape'))).height,
      206,
    );
    await tester.drag(
      find.byKey(const ValueKey('status-weight-hud')),
      const Offset(-88, 0),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(weight.text, '101.0');
    await tester.tap(find.byKey(const ValueKey('status-weight-done')));
    await tester.pump(const Duration(milliseconds: 90));
    // The reticle remains mounted for the one-shot lock capture before the
    // compact saved-value row replaces the HUD.
    expect(find.byKey(const ValueKey('status-weight-hud')), findsOneWidget);
    expect(find.byKey(const ValueKey('status-weight-tape')), findsOneWidget);
    expect(find.byKey(const ValueKey('status-weight-collapsed')), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.byKey(const ValueKey('status-weight-collapsed')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('status-weight-collapsed')));
    await tester.pump();
    expect(find.byKey(const ValueKey('status-weight-done')), findsOneWidget);
  });

  testWidgets('weight HUD exposes idle, drag energy, and lock capture frames', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final weight = TextEditingController(text: '93.6');
    final bodyFat = TextEditingController(text: '31.7');
    addTearDown(weight.dispose);
    addTearDown(bodyFat.dispose);
    await tester.pumpWidget(app(weight, bodyFat, initiallyExpanded: true));
    await expectLater(
      find.byKey(const ValueKey('status-weight-tape')),
      matchesGoldenFile('../goldens/status_weight_hud_v30_idle.png'),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('status-weight-hud'))),
    );
    await gesture.moveBy(const Offset(-8.8, 0));
    await tester.pump(const Duration(milliseconds: 140));
    expect(weight.text, '93.7');
    await expectLater(
      find.byKey(const ValueKey('status-weight-tape')),
      matchesGoldenFile('../goldens/status_weight_hud_v30_drag.png'),
    );
    await tester.pump(const Duration(milliseconds: 110));
    await expectLater(
      find.byKey(const ValueKey('status-weight-tape')),
      matchesGoldenFile('../goldens/status_weight_hud_v30_energy.png'),
    );
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 160));
    await expectLater(
      find.byKey(const ValueKey('status-weight-tape')),
      matchesGoldenFile('../goldens/status_weight_hud_v30_release.png'),
    );
    await tester.tap(find.byKey(const ValueKey('status-weight-done')));
    await tester.pump(const Duration(milliseconds: 90));
    await expectLater(
      find.byKey(const ValueKey('status-weight-tape')),
      matchesGoldenFile('../goldens/status_weight_hud_v30_lock90.png'),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await expectLater(
      find.byKey(const ValueKey('status-weight-tape')),
      matchesGoldenFile('../goldens/status_weight_hud_v30_lock140.png'),
    );
    await tester.pump(const Duration(milliseconds: 35));
    await expectLater(
      find.byKey(const ValueKey('status-weight-tape')),
      matchesGoldenFile('../goldens/status_weight_hud_v30_lock175.png'),
    );
  });

  testWidgets(
    'body fat ring renders the whole palette across active progress',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final weight = TextEditingController(text: '93.6');
      final bodyFat = TextEditingController(text: '0.0');
      addTearDown(weight.dispose);
      addTearDown(bodyFat.dispose);
      await tester.pumpWidget(app(weight, bodyFat, initiallyExpanded: true));
      final ring = find.byKey(const ValueKey('status-body-fat-ring'));
      await expectLater(
        ring,
        matchesGoldenFile('../goldens/status_body_fat_v30_0.png'),
      );
      bodyFat.text = '31.7';
      await tester.pump();
      await expectLater(
        ring,
        matchesGoldenFile('../goldens/status_body_fat_v30_317.png'),
      );
      bodyFat.text = '60.0';
      await tester.pump();
      await expectLater(
        ring,
        matchesGoldenFile('../goldens/status_body_fat_v30_60.png'),
      );
    },
  );

  testWidgets(
    'new seeded body draft is expanded until each value is confirmed',
    (tester) async {
      final weight = TextEditingController(text: '94.4');
      final bodyFat = TextEditingController(text: '21.5');
      addTearDown(weight.dispose);
      addTearDown(bodyFat.dispose);
      await tester.pumpWidget(app(weight, bodyFat, initiallyExpanded: true));

      expect(find.byKey(const ValueKey('status-weight-done')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('status-body-fat-done')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('status-body-fat-done')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('status-body-fat-collapsed')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('status-body-fat-collapsed')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('status-body-fat-done')),
        findsOneWidget,
      );
    },
  );

  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    testWidgets('body value controls fit at $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final weight = TextEditingController();
      final bodyFat = TextEditingController();
      addTearDown(weight.dispose);
      addTearDown(bodyFat.dispose);
      await tester.pumpWidget(app(weight, bodyFat));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('body controls remain unclipped at 320dp and 1.3 text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final weight = TextEditingController();
    final bodyFat = TextEditingController();
    addTearDown(weight.dispose);
    addTearDown(bodyFat.dispose);
    await tester.pumpWidget(app(weight, bodyFat, textScale: 1.3));
    expect(tester.takeException(), isNull);
  });
}
