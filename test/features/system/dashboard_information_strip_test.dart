import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:or_app/features/system/models/information_notice.dart';
import 'package:or_app/features/system/widgets/dashboard_information_strip.dart';

void main() {
  testWidgets(
    'uses a fixed heading row and static second row for reduced motion',
    (tester) async {
      await tester.pumpWidget(_app(disableAnimations: true));

      expect(
        find.byKey(const ValueKey('dashboard-information-strip')),
        findsOneWidget,
      );
      expect(find.text('INFORMATION'), findsOneWidget);
      expect(find.text('RECOVERY V2 BETA — REVIEW READY'), findsOneWidget);
      expect(find.byIcon(Symbols.breaking_news), findsOneWidget);
      final heading = find.text('INFORMATION');
      final notice = find.text('RECOVERY V2 BETA — REVIEW READY');
      expect(
        tester.getTopLeft(notice).dy,
        greaterThan(tester.getBottomLeft(heading).dy),
      );
      expect(tester.widget<Text>(notice).overflow, TextOverflow.ellipsis);
      expect(
        find.byKey(const ValueKey('dashboard-information-marquee-transform')),
        findsNothing,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('dashboard-information-strip')))
            .height,
        lessThan(90),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('marquee fully passes from the ticker right edge to its left', (
    tester,
  ) async {
    await tester.pumpWidget(_app(disableAnimations: false));
    final text = find.text('RECOVERY V2 BETA — REVIEW READY');
    final viewport = find.byKey(
      const ValueKey('dashboard-information-ticker-viewport'),
    );
    final transform = find.byKey(
      const ValueKey('dashboard-information-marquee-transform'),
    );
    final initial = tester
        .widget<Transform>(transform)
        .transform
        .getTranslation()
        .x;
    expect(initial, moreOrLessEquals(tester.getSize(viewport).width));

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final moving = tester
        .widget<Transform>(transform)
        .transform
        .getTranslation()
        .x;

    expect(moving, lessThan(initial));

    await tester.pump(const Duration(milliseconds: 5100));
    await tester.pump();
    final end = tester
        .widget<Transform>(transform)
        .transform
        .getTranslation()
        .x;
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'RECOVERY V2 BETA — REVIEW READY',
        style: tester.widget<Text>(text).style,
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    expect(end, moreOrLessEquals(-textPainter.width));
  });

  testWidgets('keeps a compact two-row strip at supported dashboard widths', (
    tester,
  ) async {
    for (final width in [320.0, 390.0, 900.0]) {
      await tester.pumpWidget(_app(disableAnimations: true, width: width));
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('dashboard-information-strip')))
            .height,
        lessThan(90),
      );
    }
  });
}

Widget _app({required bool disableAnimations, double width = 390}) =>
    MaterialApp(
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
