import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/widgets/ambient_page_scaffold.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test(
    'STATUS route family uses the production ambient behind transparent headers',
    () {
      final ambient = source(
        'lib/features/morning/widgets/status_radial_spectrum_ambient.dart',
      );
      expect(ambient, contains('class StatusAmbientBackground'));

      for (final path in const [
        'lib/features/morning/morning_page.dart',
        'lib/features/morning/morning_history_page.dart',
        'lib/features/morning/morning_fact_page.dart',
      ]) {
        final page = source(path);
        expect(page, contains('AmbientPageScaffold'));
        expect(page, contains('StatusAmbientBackground'));
        expect(page, contains('forceMaterialTransparency: true'));
        expect(page, contains('elevation: 0'));
      }
    },
  );

  test(
    'ACTIVITY route family uses its own production ambient and glass surfaces',
    () {
      final ambient = source(
        'lib/features/activity/widgets/activity_ambient_kinetic_field.dart',
      );
      expect(ambient, contains('class ActivityAmbientBackground'));

      for (final path in const [
        'lib/features/activity/activity_page.dart',
        'lib/features/activity/activity_history_page.dart',
        'lib/features/activity/activity_entry_page.dart',
      ]) {
        final page = source(path);
        expect(page, contains('AmbientPageScaffold'));
        expect(page, contains('ActivityAmbientBackground'));
        expect(page, contains('forceMaterialTransparency: true'));
        expect(page, contains('elevation: 0'));
      }

      expect(
        source('lib/features/activity/widgets/bowel_card.dart'),
        contains('DashboardGlassCard'),
      );
      expect(
        source('lib/features/activity/widgets/digestive_event_card.dart'),
        contains('DashboardGlassCard'),
      );
      final entry = source('lib/features/activity/activity_entry_page.dart');
      expect(entry, contains('DashboardGlassCard.decoration'));
      expect(entry, contains('_activityGlassInputDecoration'));
      expect(entry, contains('backgroundColor: Colors.transparent'));
      expect(entry, contains('glass: true'));
    },
  );

  test('shared calendar retains CIRCUIT ambient for every caller context', () {
    final calendar = source('lib/features/schedule/pages/calendar_page.dart');
    final status = source('lib/features/morning/morning_page.dart');
    expect(calendar, contains('enum CalendarAmbientContext { status }'));
    expect(calendar, contains('HolographicAmbientBackground'));
    expect(calendar, isNot(contains('StatusAmbientBackground')));
    expect(
      RegExp('HolographicAmbientBackground').allMatches(calendar).length,
      greaterThanOrEqualTo(2),
    );
    expect(
      calendar,
      contains('widget.ambientContext == CalendarAmbientContext.status'),
    );
    expect(status, contains('ambientContext: CalendarAmbientContext.status'));
  });

  test(
    'ambient scaffold paints its one production field across the whole route',
    () {
      final scaffold = source('lib/core/widgets/ambient_page_scaffold.dart');
      expect(scaffold, contains('backgroundColor: Colors.transparent'));
      expect(
        scaffold,
        contains('Widget build(BuildContext context) => Stack('),
      );
      expect(
        scaffold,
        contains('Positioned.fill(child: ExcludeSemantics(child: ambient))'),
      );
      expect(scaffold, contains('extendBodyBehindAppBar: true'));
      expect(scaffold, isNot(contains('body: Stack(')));
    },
  );

  test(
    'STATUS and ACTIVITY detail routes put their header inset inside the scroll viewport',
    () {
      final statusEntry = source('lib/features/morning/morning_fact_page.dart');
      final statusRecord = source(
        'lib/features/morning/morning_history_page.dart',
      );
      final activityEntry = source(
        'lib/features/activity/activity_entry_page.dart',
      );
      final activityRecord = source(
        'lib/features/activity/activity_history_page.dart',
      );

      expect(statusEntry, contains(': SingleChildScrollView('));
      expect(statusRecord, contains('body: FutureBuilder<List<MorningData>>('));
      expect(
        statusRecord,
        matches(RegExp(r'ListView\.separated\(\s+padding:')),
      );
      expect(activityEntry, contains('return SingleChildScrollView('));
      expect(
        activityRecord,
        matches(RegExp(r'ListView\.separated\(\s+padding:')),
      );
    },
  );

  testWidgets(
    'scroll content paints behind a transparent fixed header without a band',
    (tester) async {
      tester.view.physicalSize = const Size(390, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = ScrollController();
      final boundaryKey = GlobalKey();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundaryKey,
            child: MediaQuery(
              data: const MediaQueryData(padding: EdgeInsets.only(top: 24)),
              child: AmbientPageScaffold(
                ambient: const ColoredBox(color: Color(0xff121820)),
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  title: const Text('FIXED HEADER'),
                  centerTitle: true,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  forceMaterialTransparency: true,
                ),
                body: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 88, 16, 16),
                  child: Container(
                    key: const ValueKey('scrolling-card'),
                    height: 420,
                    color: const Color(0xff236a8c),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final headerBefore = tester.getCenter(find.text('FIXED HEADER'));
      controller.jumpTo(72);
      await tester.pump();
      expect(tester.getCenter(find.text('FIXED HEADER')), headerBefore);

      expect(
        tester.getTopLeft(find.byKey(const ValueKey('scrolling-card'))).dy,
        lessThan(kToolbarHeight),
      );
      await expectLater(
        find.byKey(boundaryKey),
        matchesGoldenFile('goldens/status_activity_scroll_through_header.png'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'iOS standalone shell leaves the status-bar safe area available to Flutter',
    () {
      final webShell = source('web/index.html');
      expect(webShell, contains('viewport-fit=cover'));
      expect(
        webShell,
        contains(
          'apple-mobile-web-app-status-bar-style" content="black-translucent"',
        ),
      );
      expect(
        webShell,
        isNot(
          contains('apple-mobile-web-app-status-bar-style" content="black"'),
        ),
      );
    },
  );

  test(
    'glass input treatment is opt-in and does not affect unrelated inputs',
    () {
      final input = source('lib/core/widgets/operation_text_field.dart');
      expect(input, contains('final bool glass'));
      expect(input, contains('filled: glass'));
      expect(input, contains('this.glass = false'));
    },
  );
}
