import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/activity/models/activity_draft.dart';
import 'package:or_app/features/activity/widgets/digestive_event_card.dart';
import 'package:or_app/features/themes/base_camp/base_camp_presentation.dart';
import 'package:or_app/features/themes/base_camp/base_camp_retro_terminal.dart';

void main() {
  ActivityDraftDigestiveEvent event({int? relief}) =>
      ActivityDraftDigestiveEvent(
        id: 'digestive-relief',
        sequence: 1,
        amount: 1,
        relief: relief,
        recordedAt: DateTime.utc(2026, 10, 21),
      );

  Future<void> pumpCard(
    WidgetTester tester, {
    required double width,
    double textScale = 1,
    int? relief,
    bool baseCamp = false,
    bool enabled = true,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var current = event(relief: relief);
    final card = Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: StatefulBuilder(
          builder: (context, setState) => DigestiveEventCard(
            event: current,
            enabled: enabled,
            onChanged: (next) => setState(() => current = next),
            onDelete: () {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: baseCamp
              ? BaseCampScreenEntry(
                  screen: BaseCampScreen.activity,
                  child: BaseCampRetroTerminalScreen(
                    screenKey: 'digestive-test',
                    child: card,
                  ),
                )
              : card,
        ),
      ),
    );
    await tester.pump();
  }

  for (final width in const [320.0, 375.0, 390.0, 430.0]) {
    testWidgets('Relief controls remain one row at $width', (tester) async {
      await pumpCard(tester, width: width, textScale: 1.3, relief: 1);
      final buttons = [
        find.byKey(const ValueKey('digestive-digestive-relief-relief-0')),
        find.byKey(const ValueKey('digestive-digestive-relief-relief-1')),
        find.byKey(const ValueKey('digestive-digestive-relief-relief-2')),
      ];
      final rects = buttons.map(tester.getRect).toList();
      expect(rects.map((rect) => rect.top).toSet().length, 1);
      expect(rects.every((rect) => rect.height == 46), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Relief keeps values zero, one, and two selectable', (
    tester,
  ) async {
    await pumpCard(tester, width: 390);
    for (final value in [0, 1, 2]) {
      final control = find.byKey(
        ValueKey('digestive-digestive-relief-relief-$value'),
      );
      await tester.tap(control);
      await tester.pump();
      expect(
        tester.getSemantics(control).label,
        contains(['残便感', '普通', 'スッキリ'][value]),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('BASE CAMP relief key depresses 2dp without changing type size', (
    tester,
  ) async {
    await pumpCard(tester, width: 390, relief: 1, baseCamp: true);
    final control = find.byKey(
      const ValueKey('delete-digestive-digestive-relief'),
    );
    final face = find.descendant(
      of: control,
      matching: find.byKey(const ValueKey('base-camp-physical-key-face')),
    );
    final reliefControl = find.byKey(
      const ValueKey('digestive-digestive-relief-relief-0'),
    );
    final label = find.descendant(
      of: reliefControl,
      matching: find.text('残便感'),
    );

    double translationY() =>
        tester.widget<AnimatedContainer>(face).transform!.getTranslation().y;
    double fontSize() =>
        DefaultTextStyle.of(tester.element(label)).style.fontSize!;

    expect(translationY(), 0);
    expect(fontSize(), 10);
    final gesture = await tester.startGesture(tester.getCenter(control));
    await tester.pump(const Duration(milliseconds: 150));
    expect(translationY(), 2);
    expect(fontSize(), 10);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(translationY(), 0);
    expect(fontSize(), 10);
  });

  testWidgets('BASE CAMP digestive key face is opaque in every state', (
    tester,
  ) async {
    Future<void> expectOpaque({
      required bool enabled,
      required int? relief,
    }) async {
      await pumpCard(
        tester,
        width: 390,
        relief: relief,
        baseCamp: true,
        enabled: enabled,
      );
      final control = find.byKey(
        const ValueKey('digestive-digestive-relief-relief-1'),
      );
      final face = tester.widget<AnimatedContainer>(
        find.descendant(
          of: control,
          matching: find.byKey(const ValueKey('base-camp-physical-key-face')),
        ),
      );
      final gradient = (face.decoration! as BoxDecoration).gradient!;
      expect(
        (gradient as LinearGradient).colors.every((color) => color.a == 1),
        isTrue,
      );
    }

    await expectOpaque(enabled: true, relief: null);
    await expectOpaque(enabled: true, relief: 1);
    await expectOpaque(enabled: false, relief: 1);
  });
}
