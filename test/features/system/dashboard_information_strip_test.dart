import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:or_app/core/theme/app_spacing.dart';
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
    final timing = _timingFor(tester, text: text, viewport: viewport);
    expect(
      timing.travelDuration,
      greaterThan(const Duration(milliseconds: 5200)),
    );
    expect(
      timing.effectivePixelsPerSecond,
      moreOrLessEquals(
        InformationMarqueeTiming.fixedScrollSpeedPxPerSecond,
        epsilon: .001,
      ),
    );
    final initial = tester.getRect(text).left;
    expect(initial, moreOrLessEquals(tester.getRect(viewport).right));

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final moving = tester.getRect(text).left;

    expect(moving, lessThan(initial));

    final viewportRect = tester.getRect(viewport);
    await tester.pump(
      timing.travelDuration - const Duration(milliseconds: 100),
    );
    expect(
      tester.getRect(text).right,
      lessThanOrEqualTo(viewportRect.left - 4),
    );

    // Complete the travel frame before advancing the terminal pause timer.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(
      tester.getRect(text).right,
      lessThanOrEqualTo(viewportRect.left - 4),
    );

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(tester.getRect(text).left, greaterThanOrEqualTo(viewportRect.right));
  });

  testWidgets('long marquee text uses the exact rendered typography width', (
    tester,
  ) async {
    const title =
        'TEST INFORMATION — DAILY BRIEF V2 REVIEW READY / アップデートのお知らせ 1234567890';
    await tester.pumpWidget(_app(disableAnimations: false, title: title));
    await tester.pump();

    final text = find.byKey(
      const ValueKey('dashboard-information-marquee-text'),
    );
    final textWidget = tester.widget<Text>(text);
    final context = tester.element(text);
    final style = DefaultTextStyle.of(context).style.merge(textWidget.style);
    final painter = TextPainter(
      text: TextSpan(text: title, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
      textWidthBasis: TextWidthBasis.longestLine,
    )..layout();

    expect(tester.getSize(text).width, moreOrLessEquals(painter.width));
    final runtime = InformationMarqueeRuntimeDiagnostics.snapshot.value;
    expect(runtime, isNotNull);
    expect(runtime!.renderedTextWidth, isNotNull);
    expect(
      runtime.measuredTextWidth,
      moreOrLessEquals(runtime.renderedTextWidth!),
    );
  });

  testWidgets('renders the configured linear speed, not only its duration', (
    tester,
  ) async {
    const title =
        'TEST INFORMATION — DAILY BRIEF V2 REVIEW READY / アップデートのお知らせ 1234567890';
    await tester.pumpWidget(_app(disableAnimations: false, title: title));
    final text = find.byKey(
      const ValueKey('dashboard-information-marquee-text'),
    );

    await tester.pump(InformationMarqueeConfiguration.initialPause);
    await tester.pump();
    final before = tester.getRect(text).left;
    const sample = Duration(milliseconds: 400);
    await tester.pump(sample);
    final after = tester.getRect(text).left;
    final actualPixelsPerSecond =
        (before - after) /
        (sample.inMicroseconds / Duration.microsecondsPerSecond);

    expect(
      actualPixelsPerSecond,
      moreOrLessEquals(
        InformationMarqueeConfiguration.scrollSpeedPxPerSecond,
        epsilon: .5,
      ),
    );
  });

  test('production marquee configuration is the sole timing source', () {
    expect(InformationMarqueeConfiguration.scrollSpeedPxPerSecond, 135);
    expect(InformationMarqueeConfiguration.exitSafetyMargin, 12);
    const geometry = InformationMarqueeGeometry(
      viewportWidth: 390,
      textLayoutWidth: 500,
      exitSafetyMargin: InformationMarqueeConfiguration.exitSafetyMargin,
    );
    const timing = InformationMarqueeTiming(
      geometry: geometry,
      scrollSpeedPxPerSecond:
          InformationMarqueeConfiguration.scrollSpeedPxPerSecond,
    );
    expect(
      timing.effectivePixelsPerSecond,
      moreOrLessEquals(135, epsilon: .01),
    );
  });

  test('local marquee geometry moves monotonically left', () {
    const marginOne = InformationMarqueeGeometry(
      viewportWidth: 320,
      textLayoutWidth: 480,
      exitSafetyMargin: 1,
    );
    const marginSix = InformationMarqueeGeometry(
      viewportWidth: 320,
      textLayoutWidth: 480,
      exitSafetyMargin: 6,
    );
    const marginTwelve = InformationMarqueeGeometry(
      viewportWidth: 320,
      textLayoutWidth: 480,
      exitSafetyMargin: 12,
    );
    final positions = [
      marginSix.leftAt(0),
      marginSix.leftAt(.25),
      marginSix.leftAt(.5),
      marginSix.leftAt(.75),
      marginSix.leftAt(1),
    ];

    for (var index = 1; index < positions.length; index++) {
      expect(positions[index], lessThan(positions[index - 1]));
    }
    expect(marginSix.startLeft, 320);
    expect(marginSix.endLeft, -486);
    expect(marginSix.endLeft, lessThan(marginOne.endLeft));
    expect(marginTwelve.endLeft, -492);
    expect(marginTwelve.endLeft, lessThan(marginSix.endLeft));
  });

  testWidgets('uses one constant speed for short, medium, and long notices', (
    tester,
  ) async {
    const titles = [
      'TEST',
      'TEST INFORMATION',
      'TEST INFORMATION — DAILY BRIEF V2 REVIEW READY / アップデートのお知らせ',
    ];
    final timings = <InformationMarqueeTiming>[];

    for (final title in titles) {
      await tester.pumpWidget(
        _app(disableAnimations: false, width: 390, title: title),
      );
      timings.add(
        _timingFor(
          tester,
          text: find.byKey(
            const ValueKey('dashboard-information-marquee-text'),
          ),
          viewport: find.byKey(
            const ValueKey('dashboard-information-ticker-viewport'),
          ),
        ),
      );
    }

    for (final timing in timings) {
      expect(
        timing.effectivePixelsPerSecond,
        moreOrLessEquals(
          InformationMarqueeTiming.fixedScrollSpeedPxPerSecond,
          epsilon: .001,
        ),
      );
    }
    expect(timings[0].travelDuration, lessThan(timings[1].travelDuration));
    expect(timings[1].travelDuration, lessThan(timings[2].travelDuration));
  });

  testWidgets('keeps constant speed when the ticker viewport changes', (
    tester,
  ) async {
    const title =
        'TEST INFORMATION — DAILY BRIEF V2 REVIEW READY / アップデートのお知らせ';
    final timings = <InformationMarqueeTiming>[];

    for (final width in [320.0, 390.0, 900.0]) {
      await tester.pumpWidget(
        _app(disableAnimations: false, width: width, title: title),
      );
      timings.add(
        _timingFor(
          tester,
          text: find.byKey(
            const ValueKey('dashboard-information-marquee-text'),
          ),
          viewport: find.byKey(
            const ValueKey('dashboard-information-ticker-viewport'),
          ),
        ),
      );
    }

    for (final timing in timings) {
      expect(
        timing.effectivePixelsPerSecond,
        moreOrLessEquals(
          InformationMarqueeTiming.fixedScrollSpeedPxPerSecond,
          epsilon: .001,
        ),
      );
    }
    expect(timings[0].travelDuration, lessThan(timings[1].travelDuration));
    expect(timings[1].travelDuration, lessThan(timings[2].travelDuration));
  });

  testWidgets('long Japanese notice paints full local exit through end pause', (
    tester,
  ) async {
    const title =
        'TEST INFORMATION — DAILY BRIEF V2 REVIEW READY / アップデートのお知らせ';
    await tester.pumpWidget(_app(disableAnimations: false, title: title));
    final text = find.byKey(
      const ValueKey('dashboard-information-marquee-text'),
    );
    final viewport = find.byKey(
      const ValueKey('dashboard-information-ticker-viewport'),
    );
    final timing = _timingFor(tester, text: text, viewport: viewport);

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
    await tester.pump(timing.travelDuration);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    final viewportRect = tester.getRect(viewport);
    final textRect = tester.getRect(text);
    final geometry = InformationMarqueeGeometry(
      viewportWidth: viewportRect.width,
      textLayoutWidth: textRect.width,
      exitSafetyMargin: 12,
    );
    expect(
      textRect.left - viewportRect.left,
      moreOrLessEquals(geometry.endLeft),
    );
    expect(textRect.right, lessThanOrEqualTo(viewportRect.left - 10));

    await tester.pump(const Duration(milliseconds: 1200));
    expect(
      tester.getRect(text).right,
      lessThanOrEqualTo(viewportRect.left - 10),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
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

  testWidgets(
    'keeps the 12px exit safety margin at supported dashboard widths',
    (tester) async {
      const title =
          'TEST INFORMATION — DAILY BRIEF V2 REVIEW READY / アップデートのお知らせ';
      for (final width in [320.0, 390.0, 900.0]) {
        await tester.pumpWidget(
          _app(disableAnimations: false, width: width, title: title),
        );
        final text = find.byKey(
          const ValueKey('dashboard-information-marquee-text'),
        );
        final viewport = find.byKey(
          const ValueKey('dashboard-information-ticker-viewport'),
        );
        final timing = _timingFor(tester, text: text, viewport: viewport);
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pump();
        await tester.pump(timing.travelDuration);
        expect(
          tester.getRect(text).right,
          lessThanOrEqualTo(tester.getRect(viewport).left - 10),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}

InformationMarqueeTiming _timingFor(
  WidgetTester tester, {
  required Finder text,
  required Finder viewport,
}) => InformationMarqueeTiming(
  geometry: InformationMarqueeGeometry(
    viewportWidth: tester.getSize(viewport).width,
    textLayoutWidth: tester.getSize(text).width,
    exitSafetyMargin: 12,
  ),
  scrollSpeedPxPerSecond: InformationMarqueeTiming.fixedScrollSpeedPxPerSecond,
);

Widget _app({
  required bool disableAnimations,
  double width = 390,
  String title = 'RECOVERY V2 BETA — REVIEW READY',
}) => MaterialApp(
  home: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      height: 844,
      child: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 844),
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(
          body: Padding(
            padding: AppSpacing.cardPadding,
            child: DashboardInformationStrip(
              key: ValueKey('dashboard-information-$width'),
              notices: [
                InformationNotice(
                  id: 'recovery-v2-review-ready:v2-beta-1',
                  priority: InformationNoticePriority.review,
                  category: 'RECOVERY V2 SHADOW',
                  title: title,
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
      ),
    ),
  ),
);

void _noop() {}
