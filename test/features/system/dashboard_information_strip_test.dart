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
      final viewport = find.byKey(
        const ValueKey('dashboard-information-ticker-viewport'),
      );
      expect(
        tester.getTopLeft(notice).dy,
        greaterThan(tester.getBottomLeft(heading).dy),
      );
      expect(tester.widget<Text>(notice).overflow, TextOverflow.ellipsis);
      expect(
        tester.getBottomLeft(notice).dy,
        lessThanOrEqualTo(tester.getBottomLeft(viewport).dy - 2),
      );
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
    final text = find.byKey(
      const ValueKey('dashboard-information-marquee-text'),
    );
    final viewport = find.byKey(
      const ValueKey('dashboard-information-ticker-viewport'),
    );
    final position = find.byKey(
      const ValueKey('dashboard-information-marquee-positioned'),
    );
    final initial = tester.getRect(position).left;
    expect(initial, moreOrLessEquals(tester.getRect(viewport).right));

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final moving = tester.getRect(position).left;

    expect(moving, lessThan(initial));

    final viewportRect = tester.getRect(viewport);
    var fullyExited = false;
    for (var tick = 0; tick < 70; tick++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (tester.getRect(text).right <= viewportRect.left) {
        fullyExited = true;
        break;
      }
    }
    expect(fullyExited, isTrue);
    expect(tester.getRect(text).right, lessThanOrEqualTo(viewportRect.left));

    await tester.pump(const Duration(milliseconds: 1200));
    expect(tester.getRect(text).right, lessThanOrEqualTo(viewportRect.left));

    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(text).left, greaterThanOrEqualTo(viewportRect.right));
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
