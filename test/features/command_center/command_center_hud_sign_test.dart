import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/command_center/widgets/command_center_hud_sign.dart';

void main() {
  Future<void> pumpHud(
    WidgetTester tester, {
    required double width,
    required bool canPop,
    VoidCallback? onBack,
    bool disableAnimations = false,
  }) async {
    tester.view.physicalSize = Size(width, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: CommandCenterHudSign.height + 8,
              titleSpacing: 8,
              title: CommandCenterHudSign(canPop: canPop, onBack: onBack),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders a compact HUD at supported widths without overflow', (
    tester,
  ) async {
    for (final width in [320.0, 390.0, 900.0]) {
      await pumpHud(tester, width: width, canPop: true);

      expect(find.byKey(CommandCenterHudSign.signKey), findsOneWidget);
      expect(find.text('COMMANDER CENTER'), findsOneWidget);
      expect(find.byKey(CommandCenterHudSign.backKey), findsOneWidget);
      expect(
        tester.getSize(find.byKey(CommandCenterHudSign.backKey)),
        const Size(48, 48),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('does not render a nonfunctional Back control at the root', (
    tester,
  ) async {
    await pumpHud(tester, width: 390, canPop: false);

    expect(find.byKey(CommandCenterHudSign.backKey), findsNothing);
  });

  testWidgets(
    'uses the supplied real back action and is static for reduced motion',
    (tester) async {
      var backCount = 0;
      await pumpHud(
        tester,
        width: 390,
        canPop: true,
        onBack: () => backCount++,
        disableAnimations: true,
      );

      await tester.tap(find.byKey(CommandCenterHudSign.backKey));
      expect(backCount, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
