import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/models/information_notice.dart';
import 'package:or_app/features/system/widgets/dashboard_information_strip.dart';

void main() {
  testWidgets(
    'uses a one-line compact strip and static fallback for reduced motion',
    (tester) async {
      await tester.pumpWidget(_app(disableAnimations: true));

      expect(
        find.byKey(const ValueKey('dashboard-information-strip')),
        findsOneWidget,
      );
      expect(find.text('INFORMATION'), findsOneWidget);
      expect(find.text('RECOVERY V2 BETA — REVIEW READY'), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('dashboard-information-strip')))
            .height,
        lessThan(70),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('marquee begins at the left and advances toward the right', (
    tester,
  ) async {
    await tester.pumpWidget(_app(disableAnimations: false));
    final text = find.text('RECOVERY V2 BETA — REVIEW READY');
    final initial = tester.getTopLeft(text).dx;

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 100));
    final moving = tester.getTopLeft(text).dx;

    expect(moving, greaterThan(initial));
  });

  testWidgets('remains a single compact line at supported dashboard widths', (
    tester,
  ) async {
    for (final width in [320.0, 390.0, 900.0]) {
      await tester.pumpWidget(_app(disableAnimations: true, width: width));
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('dashboard-information-strip')))
            .height,
        lessThan(70),
      );
    }
  });
}

Widget _app({required bool disableAnimations, double width = 390}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(width, 844),
      disableAnimations: disableAnimations,
    ),
    child: Scaffold(
      body: DashboardInformationStrip(
        notices: [
          InformationNotice(
            id: 'recovery-v2-review-ready:v2-beta-1',
            priority: InformationNoticePriority.review,
            category: 'RECOVERY V2 SHADOW',
            title: 'RECOVERY V2 BETA — REVIEW READY',
            message: 'review',
            parameterVersion: 'v2-beta-1',
            createdAt: DateTime(2026, 9, 20),
            state: InformationNoticeState.unread,
          ),
        ],
        onTap: _noop,
      ),
    ),
  ),
);

void _noop() {}
