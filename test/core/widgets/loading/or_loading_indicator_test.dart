import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/widgets/loading/or_loading_indicator.dart';
import 'package:or_app/core/widgets/loading/or_loading_surface.dart';
import 'package:or_app/core/widgets/loading/or_loading_theme.dart';
import 'package:or_app/core/widgets/loading/or_loading_tokens.dart';

Widget _host(
  Widget child, {
  OrLoadingTokens? tokens,
  bool reduceMotion = false,
}) => MaterialApp(
  home: OrLoadingTheme(
    data: OrLoadingThemeData(tokens: tokens ?? const OrLoadingTokens()),
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: child),
    ),
  ),
);

void main() {
  testWidgets(
    'full, section and inline indicators expose stable loading semantics',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: [
              OrLoadingIndicator(
                size: OrLoadingSize.full,
                semanticsLabel: 'full',
              ),
              OrLoadingIndicator(
                size: OrLoadingSize.section,
                semanticsLabel: 'section',
              ),
              OrLoadingIndicator(
                size: OrLoadingSize.inline,
                semanticsLabel: 'inline',
              ),
            ],
          ),
        ),
      );
      expect(find.bySemanticsLabel('full'), findsOneWidget);
      expect(find.bySemanticsLabel('section'), findsOneWidget);
      expect(find.bySemanticsLabel('inline'), findsOneWidget);
    },
  );

  testWidgets(
    'active animation advances without implying completion and reduced motion remains stable',
    (tester) async {
      await tester.pumpWidget(
        _host(const OrLoadingIndicator(semanticsLabel: 'active')),
      );
      final indicator = find.byKey(const ValueKey('or-loading-bars-full'));
      final initial = tester.widget<CustomPaint>(indicator).painter;
      await tester.pump(const Duration(milliseconds: 400));
      final moved = tester.widget<CustomPaint>(indicator).painter;
      expect(moved, isNot(same(initial)));
      await tester.pumpWidget(
        _host(
          const OrLoadingIndicator(semanticsLabel: 'static'),
          reduceMotion: true,
        ),
      );
      final staticIndicator = find.byKey(
        const ValueKey('or-loading-bars-full'),
      );
      final staticInitial = tester.widget<CustomPaint>(staticIndicator).painter;
      await tester.pump(const Duration(milliseconds: 800));
      expect(
        tester.widget<CustomPaint>(staticIndicator).painter,
        same(staticInitial),
      );
    },
  );

  testWidgets('theme token overrides apply to every indicator size', (
    tester,
  ) async {
    const tokens = OrLoadingTokens(
      barCount: 7,
      barWidth: 7,
      barGap: 1,
      activeBright: Color(0xFFFFFFFF),
    );
    await tester.pumpWidget(
      _host(
        const Column(
          children: [
            OrLoadingIndicator(size: OrLoadingSize.full),
            OrLoadingIndicator(size: OrLoadingSize.section),
            OrLoadingIndicator(size: OrLoadingSize.inline),
          ],
        ),
        tokens: tokens,
      ),
    );
    expect(find.byKey(const ValueKey('or-loading-bars-full')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('or-loading-bars-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('or-loading-bars-inline')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('or-loading-bars-full'))).width,
      closeTo(55, .01),
    );
  });

  testWidgets('failed surface exposes retry without running an animation', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      _host(
        OrLoadingSurface(
          scope: OrLoadingScope.section,
          title: 'FAILED',
          state: OrLoadingPhase.failed,
          onRetry: () => retried = true,
        ),
      ),
    );
    await tester.tap(find.text('RETRY'));
    expect(retried, isTrue);
  });

  testWidgets('surfaces remain constrained on phone widths and larger text', (
    tester,
  ) async {
    for (final width in [320.0, 375.0, 390.0, 430.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 844),
              textScaler: const TextScaler.linear(1.3),
            ),
            child: const Scaffold(
              body: OrLoadingSurface(scope: OrLoadingScope.fullscreen),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });
}
