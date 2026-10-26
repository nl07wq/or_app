import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/widgets/food_saved_floating_hud.dart';

void main() {
  Future<void> pumpHud(WidgetTester tester, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xff10253c)),
            child: Center(
              child: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => FoodSavedFloatingHud.show(context),
                  child: const Text('SAVE'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('SAVE'));
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<void> pumpHudGolden(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 160);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xff10253c)),
            child: Center(
              child: SizedBox(
                width: 294,
                child: FoodSavedFloatingHud.surfaceForTesting(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'renders the FOOD success HUD as a compact floating glass surface',
    (tester) async {
      await pumpHud(tester);

      expect(find.text('MEAL SAVED'), findsOneWidget);
      expect(find.text('CONFIRMED'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.behavior, SnackBarBehavior.floating);
      expect(snackBar.backgroundColor, Colors.transparent);
      expect(snackBar.duration, const Duration(seconds: 2));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('food-saved-floating-hud')))
            .height,
        closeTo(46, 1),
      );

      final surface = tester.getRect(
        find.byKey(const ValueKey('food-saved-floating-hud')),
      );
      final icon = tester.getRect(find.byIcon(Icons.check_circle_rounded));
      final mealSaved = tester.getRect(find.text('MEAL SAVED'));
      final confirmed = tester.getRect(find.text('CONFIRMED'));
      final innerLine = tester.getRect(
        find.byKey(const ValueKey('food-saved-floating-hud-inner-line')),
      );
      expect(icon.center.dy, closeTo(surface.center.dy, 1));
      expect(mealSaved.center.dy, closeTo(surface.center.dy, 1));
      expect(confirmed.center.dy, closeTo(surface.center.dy, 1));
      expect(mealSaved.left, greaterThan(icon.right));
      expect(confirmed.left - mealSaved.right, closeTo(10, 1));
      expect((icon.left + confirmed.right) / 2, closeTo(surface.center.dx, 1));
      expect(innerLine.height, closeTo(1, .01));
      expect(innerLine.left, closeTo(icon.left, 1));
      expect(innerLine.right, closeTo(confirmed.right, 1));
      expect(innerLine.top, greaterThan(mealSaved.bottom));
      expect(innerLine.bottom, lessThan(surface.bottom - 6));

      final glass = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('food-saved-floating-hud-glass')),
      );
      final gradient = glass.decoration as BoxDecoration;
      expect(gradient.gradient, isA<LinearGradient>());
      expect((gradient.gradient!.colors.first.a * 255).round(), lessThan(0xd6));
      expect((gradient.gradient!.colors.last.a * 255).round(), lessThan(0xbf));
    },
  );

  testWidgets('renders the centered FOOD HUD content golden', (tester) async {
    await pumpHudGolden(tester);

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/food_saved_floating_hud.png'),
    );
  });

  testWidgets(
    'renders a failed HUD with its detail below the group underline',
    (tester) async {
      tester.view.physicalSize = const Size(390, 200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 294,
                child: FoodSavedFloatingHud.surfaceForTesting(
                  label: 'ACTIVITY',
                  failed: true,
                  detail: '正式歩数は0以上で入力してください',
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('ACTIVITY SAVE FAILED'), findsOneWidget);
      expect(find.text('REJECTED'), findsOneWidget);
      expect(find.text('正式歩数は0以上で入力してください'), findsOneWidget);
      final line = tester.getRect(
        find.byKey(const ValueKey('food-saved-floating-hud-inner-line')),
      );
      final detail = tester.getRect(find.text('正式歩数は0以上で入力してください'));
      expect(detail.top, greaterThan(line.bottom));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'replaces a prior FOOD success HUD instead of accumulating notices',
    (tester) async {
      await pumpHud(tester);
      await tester.tap(find.text('SAVE'));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('MEAL SAVED'), findsOneWidget);
    },
  );

  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    testWidgets('fits the FOOD success HUD at ${width.toInt()} px', (
      tester,
    ) async {
      await pumpHud(tester, width: width);
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('food-saved-floating-hud')))
            .width,
        lessThan(width),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
