import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/command_center/widgets/command_center_hud_sign.dart';

void main() {
  double glyphOpacity(WidgetTester tester, int index) => tester
      .widget<Opacity>(
        find.byKey(ValueKey('command-center-hud-glyph-opacity-$index')),
      )
      .opacity;

  double glyphScale(WidgetTester tester, int index) => tester
      .widget<Transform>(
        find.byKey(CommandCenterHudSign.glyphTransformKey(index)),
      )
      .transform
      .getMaxScaleOnAxis();

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
              toolbarHeight: CommandCenterHudSign.height + 4,
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
      await tester.pump(CommandCenterHudSign.bootDuration);

      expect(find.byKey(CommandCenterHudSign.signKey), findsOneWidget);
      expect(find.byKey(CommandCenterHudSign.opticalLayerKey), findsOneWidget);
      expect(find.byKey(CommandCenterHudSign.titleKey), findsOneWidget);
      expect(find.text('COMMANDER CENTER'), findsNothing);
      for (var index = 0; index < 15; index++) {
        expect(
          find.byKey(CommandCenterHudSign.glyphKey(index)),
          findsOneWidget,
        );
      }
      expect(find.text('OPERATION CONTROL'), findsNothing);
      expect(find.byKey(CommandCenterHudSign.backKey), findsOneWidget);
      expect(
        tester.getSize(find.byKey(CommandCenterHudSign.backKey)),
        const Size(48, 48),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('keeps the single dominant title vertically centered', (
    tester,
  ) async {
    await pumpHud(tester, width: 390, canPop: true);
    await tester.pumpAndSettle();

    final firstGlyph = tester.widget<Text>(
      find.descendant(
        of: find.byKey(CommandCenterHudSign.glyphKey(0)),
        matching: find.byType(Text),
      ),
    );
    expect(firstGlyph.style?.fontSize, 26);
    expect(firstGlyph.style?.fontFamily, 'ShareTechMono');
    expect(
      firstGlyph.style?.color?.toARGB32(),
      const Color(0xFF75D7FF).toARGB32(),
    );
    expect(
      tester.getCenter(find.byKey(CommandCenterHudSign.titleKey)).dy,
      closeTo(tester.getCenter(find.byKey(CommandCenterHudSign.signKey)).dy, 2),
    );
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
      expect(find.byKey(CommandCenterHudSign.titleKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('completes one optical boot sequence without a perpetual loop', (
    tester,
  ) async {
    await pumpHud(tester, width: 390, canPop: true);

    expect(
      CommandCenterHudSign.bootDuration,
      const Duration(milliseconds: 2050),
    );
    await tester.pump(const Duration(milliseconds: 420));
    expect(tester.takeException(), isNull);
    await tester.pump(CommandCenterHudSign.bootDuration);
    expect(find.byKey(CommandCenterHudSign.titleKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disengages once before invoking the supplied Navigator action', (
    tester,
  ) async {
    var backCount = 0;
    await pumpHud(tester, width: 390, canPop: true, onBack: () => backCount++);
    await tester.tap(find.byKey(CommandCenterHudSign.backKey));
    await tester.tap(find.byKey(CommandCenterHudSign.backKey));
    expect(backCount, 0);
    await tester.pump(
      CommandCenterHudSign.exitDuration + const Duration(milliseconds: 1),
    );
    await tester.pump();
    expect(backCount, 1);
  });

  testWidgets('renders only acquired glyphs as readable title units', (
    tester,
  ) async {
    await pumpHud(tester, width: 390, canPop: true);

    await tester.pump(const Duration(milliseconds: 1390));
    expect(glyphOpacity(tester, 0), greaterThan(.9));
    expect(glyphOpacity(tester, 1), lessThan(.75));
    expect(glyphOpacity(tester, 2), lessThan(.1));

    await tester.pump(const Duration(milliseconds: 260));
    for (var index = 0; index < 7; index++) {
      expect(glyphOpacity(tester, index), greaterThan(.9));
    }
    expect(glyphOpacity(tester, 7), lessThan(.75));
    expect(glyphOpacity(tester, 8), lessThan(.1));

    await tester.pump(const Duration(milliseconds: 135));
    for (var index = 0; index < 10; index++) {
      expect(glyphOpacity(tester, index), greaterThan(.9));
    }
    expect(glyphOpacity(tester, 10), lessThan(.75));

    await tester.pumpAndSettle();
    for (var index = 0; index < 15; index++) {
      expect(glyphOpacity(tester, index), closeTo(1, .001));
    }
  });

  testWidgets('gives only the active glyph a rendered blue lock peak', (
    tester,
  ) async {
    await pumpHud(tester, width: 390, canPop: true);

    await tester.pump(const Duration(milliseconds: 1330));
    final activeGlyph = tester.widget<Text>(
      find.descendant(
        of: find.byKey(CommandCenterHudSign.glyphKey(0)),
        matching: find.byType(Text),
      ),
    );
    expect(glyphOpacity(tester, 0), greaterThan(.4));
    expect(glyphScale(tester, 0), greaterThan(1.04));
    expect(glyphScale(tester, 1), closeTo(1, .001));
    expect(activeGlyph.style?.color, isNot(const Color(0xFF75D7FF)));
    expect(activeGlyph.style?.shadows, isNotEmpty);

    await tester.pumpAndSettle();
    expect(glyphScale(tester, 0), closeTo(1, .001));
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(CommandCenterHudSign.glyphKey(0)),
              matching: find.byType(Text),
            ),
          )
          .style
          ?.color
          ?.toARGB32(),
      const Color(0xFF75D7FF).toARGB32(),
    );
  });

  testWidgets('unlocks independent glyphs in deterministic reverse order', (
    tester,
  ) async {
    var backCount = 0;
    await pumpHud(tester, width: 390, canPop: true, onBack: () => backCount++);
    await tester.pump(CommandCenterHudSign.bootDuration);

    await tester.tap(find.byKey(CommandCenterHudSign.backKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(glyphOpacity(tester, 14), lessThan(.1));
    expect(glyphOpacity(tester, 0), greaterThan(.9));
    expect(backCount, 0);

    await tester.pump(
      CommandCenterHudSign.exitDuration - const Duration(milliseconds: 450),
    );
    await tester.pump();
    expect(backCount, 1);
  });
}
