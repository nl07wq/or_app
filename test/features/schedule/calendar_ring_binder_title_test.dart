import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/theme/app_theme.dart';
import 'package:or_app/core/widgets/holographic_ambient_background.dart';
import 'package:or_app/features/schedule/pages/calendar_page.dart';

void main() {
  Future<void> pumpHeader(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: StandardTheme.theme,
        home: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(),
            title: const CalendarRingBinderTitle(),
            centerTitle: true,
            actions: const [
              IconButton(
                tooltip: 'REMINDERS',
                icon: Icon(Icons.notifications_outlined),
                onPressed: null,
              ),
            ],
          ),
          body: const Stack(
            fit: StackFit.expand,
            children: [HolographicAmbientBackground(), SizedBox.expand()],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('ring binder title keeps its five rings and centered label', (
    tester,
  ) async {
    await pumpHeader(tester, 390);

    expect(find.byType(CalendarRingBinderTitle), findsOneWidget);
    expect(find.bySemanticsLabel('CALENDAR'), findsOneWidget);
    expect(find.text('CALENDAR'), findsOneWidget);
    expect(
      tester.getSize(find.byType(CalendarRingBinderTitle)),
      CalendarRingBinderTitle.preferredSize,
    );
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/calendar_ring_binder_title_app_bar.png'),
    );
  });

  testWidgets('ring binder title stays within the compact iPhone AppBar slot', (
    tester,
  ) async {
    for (final width in const [320.0, 375.0, 390.0, 430.0]) {
      await pumpHeader(tester, width);
      final title = tester.getRect(find.byType(CalendarRingBinderTitle));
      final back = tester.getRect(find.byType(BackButton));
      final bell = tester.getRect(find.byTooltip('REMINDERS'));
      expect(title.left, greaterThanOrEqualTo(back.right));
      expect(title.right, lessThanOrEqualTo(bell.left));
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
  });
}
