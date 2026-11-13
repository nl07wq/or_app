import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/operation_status.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/features/dashboard/widgets/operation_ambient_animation.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/themes/base_camp/base_camp_dashboard_page.dart';
import 'package:or_app/features/themes/base_camp/base_camp_presentation.dart';
import 'package:or_app/features/themes/base_camp/base_camp_retro_theme.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../../operation_date/operation_date_test_fixture.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    baseCampRifleGlobalAlignment.resetForTesting();
    final database = FakeIndexedDbDatabase();
    seedOperationState(database, '2026-11-01');
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
  });

  tearDown(AppRepositoryRegistry.resetForTesting);

  testWidgets('BASE CAMP owns a compact terminal and retains the square map', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('base-camp-tactical-terminal')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('base-camp-soldier-lower')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('base-camp-soldier-upper')),
      findsOneWidget,
    );
    expect(find.text('OPERATION PROGRESS'), findsOneWidget);
    expect(find.byType(OperationAmbientAnimation), findsOneWidget);
    final waveform = tester.widget<OperationAmbientAnimation>(
      find.byType(OperationAmbientAnimation),
    );
    expect(waveform.showStatusLabel, isFalse);
    expect(
      find.byKey(const ValueKey('base-camp-industrial-lcd')),
      findsOneWidget,
    );
    final grain = find.byKey(const ValueKey('base-camp-lcd-grain'));
    expect(grain, findsOneWidget);
    expect(
      find.ancestor(
        of: grain,
        matching: find.byKey(const ValueKey('base-camp-industrial-lcd')),
      ),
      findsOneWidget,
    );
    final grainPaint = tester.widget<CustomPaint>(grain);
    expect(grainPaint.painter, isA<BaseCampLcdGrainPainter>());
    expect(BaseCampLcdGrainPainter.pitch, 4);
    expect(BaseCampLcdGrainPainter.opacity, .08);
    for (final surface in const ['clock', 'ecg', 'soldier']) {
      final overlay = find.byKey(ValueKey('base-camp-$surface-lcd-grain'));
      expect(overlay, findsOneWidget);
      final paint = tester.widget<CustomPaint>(overlay);
      final painter = paint.painter! as BaseCampLcdGrainPainter;
      expect(painter.alpha, surface == 'soldier' ? .05 : .08);
      final pointerGuard = find
          .ancestor(of: overlay, matching: find.byType(IgnorePointer))
          .first;
      expect(tester.widget<IgnorePointer>(pointerGuard).ignoring, isTrue);
      expect(
        painter.shouldRepaint(
          BaseCampLcdGrainPainter(
            negative: painter.negative,
            alpha: painter.alpha,
          ),
        ),
        isFalse,
      );
    }
    expect(
      tester.getSize(find.byKey(const ValueKey('base-camp-clock-lcd-grain'))),
      tester.getSize(find.byKey(const ValueKey('base-camp-dot-matrix-clock'))),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('base-camp-ecg-lcd-grain'))),
      tester.getSize(
        find.byKey(const ValueKey('base-camp-ecg-display-window')),
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('base-camp-soldier-lcd-grain'))),
      tester.getSize(
        find.byKey(const ValueKey('base-camp-soldier-display-window')),
      ),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('base-camp-map')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter is BaseCampLcdGrainPainter,
        ),
      ),
      findsNothing,
    );
    expect(find.text('COMMAND TERMINAL'), findsOneWidget);
    expect(find.textContaining('BASE CAMP //'), findsNothing);
    expect(find.byKey(const ValueKey('base-camp-map')), findsOneWidget);
    final mapSize = tester.getSize(find.byKey(const ValueKey('base-camp-map')));
    expect(
      mapSize.width / mapSize.height,
      closeTo(
        baseCampMapArtworkSize.width / baseCampMapArtworkSize.height,
        .02,
      ),
    );
    final viewport = tester.getSize(
      find.byKey(const ValueKey('base-camp-home-map-viewport')),
    );
    expect(viewport.height, closeTo(mapSize.height, .1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('soldier panel long press opens the independent live preview', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.longPress(
      find.byKey(const ValueKey('base-camp-soldier-panel')),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('SOLDIER LIVE MOTION PREVIEW'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('soldier-live-trigger-regrip')),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 1100));
    final dashboardPanel = find.byKey(
      const ValueKey('base-camp-soldier-panel'),
    );
    expect(
      find.descendant(
        of: dashboardPanel,
        matching: find.byKey(const ValueKey('base-camp-rifle-regrip-frame-0')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: dashboardPanel,
        matching: find.byKey(const ValueKey('base-camp-soldier-lower')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('soldier panel tap plays one exclusive manual regrip', (
    tester,
  ) async {
    await baseCampRifleGlobalAlignment.save(
      const BaseCampRifleGlobalAlignment(
        x: 7,
        y: -4,
        scale: 1.1,
        verticalScaleX: 1.2,
        horizontalScaleY: .8,
      ),
    );
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 300));

    final panel = find.byKey(const ValueKey('base-camp-soldier-panel'));
    await tester.tap(panel);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1001));
    expect(
      find.byKey(const ValueKey('base-camp-rifle-regrip-frame-0')),
      findsOneWidget,
    );
    final rendered = tester.widget<BaseCampRifleRegripFrame>(
      find.byKey(const ValueKey('base-camp-rifle-regrip-frame-0')),
    );
    expect(rendered.globalX, 7);
    expect(rendered.globalY, -4);
    expect(rendered.globalScale, 1.1);
    expect(rendered.verticalScaleX, 1.2);
    expect(rendered.horizontalScaleY, .8);

    // A second tap during the event must not restart or queue another event.
    await tester.tap(panel);
    await tester.pump(const Duration(milliseconds: 2849));
    expect(
      find.byKey(const ValueKey('base-camp-rifle-regrip-frame-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('base-camp-soldier-lower')),
      findsOneWidget,
    );
  });

  testWidgets(
    'dashboard map uses the approved available width at mobile heights',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final size in const [
        Size(390, 844),
        Size(390, 750),
        Size(375, 667),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          const MaterialApp(home: BaseCampDashboardPage()),
        );
        await tester.pump(const Duration(milliseconds: 300));

        final terminal = tester.getRect(
          find.byKey(const ValueKey('base-camp-tactical-terminal')),
        );
        final mapRegion = tester.getRect(
          find.byKey(const ValueKey('base-camp-home-map-region')),
        );
        final mapViewport = tester.getRect(
          find.byKey(const ValueKey('base-camp-home-map-viewport')),
        );
        expect(terminal.height, closeTo(317.8, .2));
        expect(mapRegion.top - terminal.bottom, closeTo(6, .1));
        expect(mapRegion.width, closeTo(size.width - 24, .1));
        expect(mapRegion.width, closeTo(mapRegion.height, .1));
        expect(mapViewport.width, closeTo(mapViewport.height, .1));
        // The chassis contributes 7px padding plus its 1.4px border per side.
        expect(mapViewport.width, closeTo(mapRegion.width - 16.8, .2));
        expect(
          find.byKey(const ValueKey('base-camp-dashboard-scroll')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  for (final width in <double>[320, 375, 390, 430]) {
    testWidgets('terminal fasteners keep safe vertical clearance at $width', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(Size(width, 844));
      await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
      await tester.pump(const Duration(milliseconds: 300));

      final terminal = tester.getRect(
        find.byKey(const ValueKey('base-camp-tactical-terminal')),
      );
      final heading = tester.getRect(
        find.byKey(const ValueKey('base-camp-terminal-heading')),
      );
      final indicator = tester.getRect(
        find.byKey(const ValueKey('base-camp-page-indicator-0')),
      );

      expect(heading.top, greaterThanOrEqualTo(terminal.top + 15));
      expect(terminal.bottom - indicator.bottom, closeTo(9.4, .2));
      expect(terminal.height, closeTo(317.8, .2));
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in <double>[320, 375, 390]) {
    testWidgets('terminal restores the original three-column order at $width', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(Size(width, 844));
      await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
      await tester.pump(const Duration(milliseconds: 300));
      final pages = find.byKey(const ValueKey('base-camp-terminal-pages'));

      List<Rect> panelRects(String pageName) {
        final page = find.byKey(ValueKey('base-camp-terminal-page-$pageName'));
        return find
            .descendant(
              of: page,
              matching: find.byKey(
                const ValueKey('base-camp-instrument-panel'),
              ),
            )
            .evaluate()
            .map(
              (element) => tester.getRect(
                find.byElementPredicate((candidate) => candidate == element),
              ),
            )
            .toList(growable: false);
      }

      List<String> panelLabels(String pageName) {
        final page = find.byKey(ValueKey('base-camp-terminal-page-$pageName'));
        return find
            .descendant(
              of: page,
              matching: find.byKey(
                const ValueKey('base-camp-instrument-panel'),
              ),
            )
            .evaluate()
            .map((element) {
              final panel = find.byElementPredicate(
                (candidate) => candidate == element,
              );
              return tester
                  .widgetList<Text>(
                    find.descendant(of: panel, matching: find.byType(Text)),
                  )
                  .first
                  .data!;
            })
            .toList(growable: false);
      }

      void expectTwoRows(List<Rect> rects) {
        expect(rects.length, greaterThanOrEqualTo(5));
        expect(rects[0].top, closeTo(rects[1].top, .01));
        expect(rects[1].top, closeTo(rects[2].top, .01));
        expect(rects[3].top, greaterThan(rects[0].bottom));
        expect(rects[3].left, closeTo(rects[0].left, .01));
        expect(rects[4].left, closeTo(rects[1].left, .01));
        for (final rect in rects) {
          expect(rect.height, closeTo(53, .01));
        }
      }

      expect(panelLabels('progress'), [
        'STATUS',
        'FOOD',
        'TRAINING',
        'ACTIVITY',
        'BRIEF',
        'DEBRIEF',
      ]);
      expectTwoRows(panelRects('progress'));

      await tester.drag(pages, const Offset(-280, 0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(panelLabels('morning'), [
        'WEIGHT',
        'SLEEP',
        'BASE BURN',
        'EXERCISE',
        'TOTAL BURN',
      ]);
      expectTwoRows(panelRects('morning'));

      await tester.drag(pages, const Offset(-280, 0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(panelLabels('sustainment'), [
        'CALORIES',
        'PROTEIN',
        'WATER',
        'TRAINING',
        'ACTIVITY',
      ]);
      final sustainment = panelRects('sustainment');
      expect(sustainment.length, 5);
      expect(sustainment[0].top, closeTo(sustainment[1].top, .01));
      expect(sustainment[2].top, greaterThan(sustainment[0].bottom));
      expect(sustainment[2].left, closeTo(sustainment[0].left, .01));
      expect(sustainment[3].left, closeTo(sustainment[2].right + 6, .01));
      expect(sustainment[4].left, closeTo(sustainment[3].right + 6, .01));
      expect(sustainment[0].right + 6, closeTo(sustainment[1].left, .01));
      expect(sustainment[0].width, closeTo(sustainment[1].width * 2, .02));
      expect(sustainment[2].width, closeTo(sustainment[3].width, .02));
      expect(sustainment[3].width, closeTo(sustainment[4].width, .02));
      expect(sustainment[1].right, closeTo(sustainment[4].right, .01));
      for (final rect in sustainment) {
        expect(rect.height, closeTo(53, .01));
      }
      expect(
        find.byKey(const ValueKey('base-camp-sustainment-empty-cell')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('all terminal pages retain one compact chassis height', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 750));
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 300));

    final terminalFinder = find.byKey(
      const ValueKey('base-camp-tactical-terminal'),
    );
    final pagesFinder = find.byKey(const ValueKey('base-camp-terminal-pages'));
    final initialHeight = tester.getSize(terminalFinder).height;
    const pageKeys = <String>[
      'base-camp-terminal-page-progress',
      'base-camp-terminal-page-morning',
      'base-camp-terminal-page-sustainment',
      'base-camp-terminal-page-command',
    ];

    for (var page = 0; page < pageKeys.length; page++) {
      expect(find.byKey(ValueKey(pageKeys[page])), findsOneWidget);
      expect(tester.getSize(terminalFinder).height, initialHeight);
      expect(
        tester
            .getSize(find.byKey(ValueKey('base-camp-page-indicator-$page')))
            .width,
        20,
        reason: 'page $page must own the active indicator',
      );
      if (page < pageKeys.length - 1) {
        await tester.fling(pagesFinder, const Offset(-320, 0), 1000);
        await tester.pump(const Duration(milliseconds: 600));
      }
    }

    final terminal = tester.getRect(terminalFinder);
    final indicator = tester.getRect(
      find.byKey(const ValueKey('base-camp-page-indicator-3')),
    );
    expect(terminal.bottom - indicator.bottom, closeTo(9.4, .2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('terminal pages swipe and open an expanded detail sheet', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.drag(
      find.byKey(const ValueKey('base-camp-terminal-pages')),
      const Offset(-320, 0),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final page = find.byKey(const ValueKey('base-camp-terminal-page-morning'));
    expect(page, findsOneWidget);
    await tester.ensureVisible(page);
    await tester.pump();
    await tester.tap(page);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('OPEN STATUS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress preserves the original three-column grid on iPhone', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 300));

    final grid = tester.widget<GridView>(
      find.descendant(
        of: find.byKey(const ValueKey('base-camp-progress-grid')),
        matching: find.byType(GridView),
      ),
    );
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);
    expect(delegate.crossAxisSpacing, 6);
    expect(delegate.mainAxisSpacing, 6);
  });

  testWidgets('status compartment contains the clock, monitor and lamps', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('base-camp-dot-matrix-clock')),
      findsOneWidget,
    );
    expect(find.text('FINE'), findsOneWidget);
    expect(find.text('CAUTION'), findsOneWidget);
    expect(find.text('DANGER'), findsOneWidget);
  });

  test('dot matrix clock dims every changed character at second rollovers', () {
    const prefix = '11/09 (MON) ';
    expect(
      dotMatrixClockChangedIndexes('${prefix}12:34:08', '${prefix}12:34:09'),
      {prefix.length + 7},
    );
    expect(
      dotMatrixClockChangedIndexes('${prefix}12:34:09', '${prefix}12:34:10'),
      {prefix.length + 6, prefix.length + 7},
    );
    expect(
      dotMatrixClockChangedIndexes('${prefix}12:34:59', '${prefix}12:35:00'),
      {prefix.length + 4, prefix.length + 6, prefix.length + 7},
    );
    expect(
      dotMatrixClockChangedIndexes('${prefix}23:59:59', '${prefix}00:00:00'),
      {
        prefix.length,
        prefix.length + 1,
        prefix.length + 3,
        prefix.length + 4,
        prefix.length + 6,
        prefix.length + 7,
      },
    );
  });

  test('clock formats every weekday with its required three-letter value', () {
    expect(baseCampClockText(DateTime(2026, 11, 9)), contains('(MON)'));
    expect(baseCampClockText(DateTime(2026, 11, 10)), contains('(TUE)'));
    expect(baseCampClockText(DateTime(2026, 11, 11)), contains('(WED)'));
    expect(baseCampClockText(DateTime(2026, 11, 12)), contains('(THU)'));
    expect(baseCampClockText(DateTime(2026, 11, 13)), contains('(FRI)'));
    expect(baseCampClockText(DateTime(2026, 11, 14)), contains('(SAT)'));
    expect(baseCampClockText(DateTime(2026, 11, 15)), contains('(SUN)'));
  });

  testWidgets('progress uses instrument cells instead of progress bars', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pixel readouts preserve required values and Japanese glyphs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const values = <String>[
      'COMPLETE',
      'NOT RECORDED',
      '2098 kcal',
      'NOT CALCULATED',
      '水分 2500 ml',
      '作戦予定を確認',
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: BaseCampScreenEntry(
          screen: BaseCampScreen.dashboard,
          child: Scaffold(
            body: Column(
              children: [
                for (final value in values)
                  SizedBox(
                    width: 140,
                    height: 42,
                    child: BaseCampResponsiveReadout(value: value),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    for (final value in values) {
      final text = tester.widget<Text>(find.text(value));
      expect(text.overflow, TextOverflow.visible);
      expect(text.style?.fontFamily, baseCampPixelFontFamily);
      expect(
        text.style?.fontFamilyFallback,
        contains(baseCampJapaneseFontFallback),
      );
      expect(text.style?.fontSize, greaterThanOrEqualTo(8));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('all four terminal panels keep required text at 320px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: BaseCampScreenEntry(
          screen: BaseCampScreen.dashboard,
          child: BaseCampDashboardPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final pages = find.byKey(const ValueKey('base-camp-terminal-pages'));

    expect(find.text('NO DATA'), findsWidgets);
    expect(find.text('NOT RECORDED'), findsNothing);
    for (final text in tester.widgetList<Text>(
      find.byKey(const ValueKey('base-camp-progress-status-text')),
    )) {
      expect(text.overflow, TextOverflow.visible);
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
    }

    await tester.drag(pages, const Offset(-280, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('NOT CALCULATED'), findsWidgets);

    await tester.drag(pages, const Offset(-280, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('NOT RECORDED'), findsWidgets);

    await tester.drag(pages, const Offset(-280, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('COMMANDER INTENT UNAVAILABLE'), findsOneWidget);
    expect(find.text('NO SCHEDULED ITEMS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long Japanese schedule titles wrap without truncation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const title = '重要な作戦予定を確認して記録する';
    await tester.pumpWidget(
      const MaterialApp(
        home: BaseCampScreenEntry(
          screen: BaseCampScreen.dashboard,
          child: Scaffold(
            body: SizedBox(
              width: 280,
              child: BaseCampTacticalScheduleRow(
                number: 1,
                time: '09:30',
                title: title,
                active: true,
              ),
            ),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text(title));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.visible);
    expect(tester.getSize(find.byType(BaseCampTacticalScheduleRow)).height, 24);
    expect(tester.takeException(), isNull);
  });

  test('FOOD readout preserves formal partial and completion semantics', () {
    expect(baseCampFoodProgressText(0), 'NOT RECORDED');
    expect(baseCampFoodProgressText(1), '1 / 3');
    expect(baseCampFoodProgressText(2), '2 / 3');
    expect(baseCampFoodProgressText(3), 'COMPLETE');
  });

  test('progress presentation renames only the missing formal state', () {
    expect(baseCampProgressDisplayValue('COMPLETE'), 'COMPLETE');
    expect(baseCampProgressDisplayValue('NOT RECORDED'), 'NO DATA');
    expect(baseCampProgressDisplayValue('INCOMPLETE'), 'INCOMPLETE');
    expect(baseCampProgressDisplayValue('1 / 3'), '1 / 3');
  });

  for (final width in <double>[320, 375, 390]) {
    testWidgets(
      'progress lamp precedes every fitted status at ${width.toInt()}px',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          const MaterialApp(home: BaseCampDashboardPage()),
        );
        await tester.pump(const Duration(milliseconds: 120));
        final progressPage = find.byKey(
          const ValueKey('base-camp-terminal-page-progress'),
        );
        final panel = find
            .descendant(
              of: progressPage,
              matching: find.byKey(
                const ValueKey('base-camp-instrument-panel'),
              ),
            )
            .first;
        final lineWidth = tester.getSize(panel).width - 8;
        Rect? stableLampRect;
        final fontSizes = <String, double>{};

        for (final formalValue in const [
          'COMPLETE',
          'NOT RECORDED',
          'INCOMPLETE',
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              home: BaseCampScreenEntry(
                screen: BaseCampScreen.dashboard,
                child: Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: lineWidth,
                      child: BaseCampProgressStatusLine(
                        formalValue: formalValue,
                        active: formalValue == 'COMPLETE',
                        partial: formalValue == 'INCOMPLETE',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          final lamp = find.byKey(
            const ValueKey('base-camp-progress-status-lamp'),
          );
          final readout = find.byKey(
            const ValueKey('base-camp-progress-status-readout'),
          );
          final text = find.byKey(
            const ValueKey('base-camp-progress-status-text'),
          );
          final lampRect = tester.getRect(lamp);
          final readoutRect = tester.getRect(readout);
          final textRect = tester.getRect(text);
          final textWidget = tester.widget<Text>(text);
          final displayed = baseCampProgressDisplayValue(formalValue);

          stableLampRect ??= lampRect;
          expect(lampRect, stableLampRect, reason: displayed);
          expect(lampRect.size, const Size(12, 12), reason: displayed);
          expect(readoutRect.left - lampRect.right, closeTo(5, .01));
          expect(lampRect.right, lessThan(textRect.left));
          expect(textRect.right, lessThanOrEqualTo(readoutRect.right));
          expect(textWidget.data, displayed);
          expect(textWidget.maxLines, 1);
          expect(textWidget.softWrap, isFalse);
          expect(textWidget.overflow, TextOverflow.visible);
          fontSizes[displayed] = textWidget.style!.fontSize!;
          expect(tester.takeException(), isNull, reason: displayed);
        }

        expect(fontSizes['COMPLETE'], 6.5);
        expect(fontSizes['NO DATA'], fontSizes['COMPLETE']);
        expect(fontSizes['INCOMPLETE'], greaterThanOrEqualTo(5));
        expect(fontSizes['INCOMPLETE'], lessThanOrEqualTo(6.5));
        expect(fontSizes['INCOMPLETE'], width == 320 ? 5.5 : 6.5);
      },
    );
  }

  testWidgets('two-track calories value and kcal stay on one line', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 120));
    final pages = find.byKey(const ValueKey('base-camp-terminal-pages'));
    for (var page = 0; page < 2; page++) {
      await tester.drag(pages, const Offset(-280, 0));
      await tester.pump(const Duration(milliseconds: 300));
    }
    final sustainment = find.byKey(
      const ValueKey('base-camp-terminal-page-sustainment'),
    );
    final caloriesPanel = find
        .descendant(
          of: sustainment,
          matching: find.byKey(const ValueKey('base-camp-instrument-panel')),
        )
        .first;
    final readoutWidth = tester.getSize(caloriesPanel).width - 8;

    await tester.pumpWidget(
      MaterialApp(
        home: BaseCampScreenEntry(
          screen: BaseCampScreen.dashboard,
          child: Scaffold(
            body: SizedBox(
              width: readoutWidth,
              child: const BaseCampResponsiveReadout(
                value: '2098 / 2500 kcal',
                singleLine: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final value = tester.widget<Text>(find.text('2098 / 2500 kcal'));
    expect(value.maxLines, 1);
    expect(value.softWrap, isFalse);
    expect(value.overflow, TextOverflow.visible);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'instrument panels retain fixed original geometry on mobile widths',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final width in [320.0, 375.0, 390.0, 430.0]) {
        await tester.binding.setSurfaceSize(Size(width, 844));
        await tester.pumpWidget(
          const MaterialApp(home: BaseCampDashboardPage()),
        );
        await tester.pump(const Duration(milliseconds: 120));
        final progress = find.byKey(
          const ValueKey('base-camp-terminal-page-progress'),
        );
        final panels = find.descendant(
          of: progress,
          matching: find.byKey(const ValueKey('base-camp-instrument-panel')),
        );
        final readouts = find.descendant(
          of: progress,
          matching: find.byKey(
            const ValueKey('base-camp-progress-status-readout'),
          ),
        );
        expect(panels, findsNWidgets(6));
        expect(readouts, findsNWidgets(6));
        final panelRects = panels
            .evaluate()
            .map(
              (panel) => tester.getRect(
                find.byElementPredicate((element) => element == panel),
              ),
            )
            .toList(growable: false);
        final heights = panelRects.map((rect) => rect.height).toList();
        expect(
          heights.reduce(math.max) - heights.reduce(math.min),
          lessThan(.01),
        );
        expect(panelRects.first.height, closeTo(53, .01));
        for (final readout in readouts.evaluate()) {
          final readoutRect = tester.getRect(
            find.byElementPredicate((element) => element == readout),
          );
          expect(
            panels
                .evaluate()
                .map((panel) {
                  return tester.getRect(
                    find.byElementPredicate((element) => element == panel),
                  );
                })
                .any(
                  (panelRect) =>
                      panelRect.contains(readoutRect.topLeft) &&
                      panelRect.contains(readoutRect.bottomRight),
                ),
            isTrue,
          );
          expect(readoutRect.height, closeTo(25, .01));
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  test(
    'breathing offset is periodic, vertical-only and stays within range',
    () {
      expect(baseCampBreathingOffset(0), 0);
      expect(baseCampBreathingOffset(600), closeTo(-.5, .0001));
      expect(baseCampBreathingOffset(1200), closeTo(-1, .0001));
      expect(baseCampBreathingOffset(1800), closeTo(-.5, .0001));
      expect(baseCampBreathingOffset(2400), closeTo(0, .0001));
    },
  );

  test(
    'tactical grid shares wall origins with the bounded perspective floor',
    () {
      const panel = Size(128, 100);
      expect(baseCampSoldierGroundY(panel), 78);
      expect(baseCampSoldierWallLinePositions(panel.width), [0, 32, 64, 96]);
      expect(baseCampSoldierWallLinePositions(78), [0, 32, 64]);
      expect(baseCampSoldierFloorLinePositions(panel), [83.5, 90.1, 96.7]);
      for (final expectation in <(double, double)>[
        (-51.2, 0),
        (6.4, 32),
        (64, 64),
        (121.6, 96),
      ]) {
        final endpoint = baseCampSoldierPerspectiveEndpoint(
          panel,
          expectation.$2,
        );
        expect(endpoint.dx, closeTo(expectation.$1, .001));
        expect(endpoint.dy, 100);
      }
    },
  );

  test(
    'rifle frame transform has one stable standing size and foot anchor',
    () {
      final layout = baseCampRifleRegripLayout(const Size(122, 90));
      expect(layout.normalFootY, closeTo(layout.specialFootY, .001));
      expect(
        layout.normalFootY - layout.normalHeadY,
        closeTo(layout.specialFootY - layout.specialHeadY, .15),
      );
      expect(layout.specialHeadY, greaterThanOrEqualTo(0));
      expect(layout.specialFootY, lessThanOrEqualTo(90));
    },
  );

  test('rifle regrip timeline uses every approved frame once in order', () {
    expect(baseCampRifleRegripPreIdleMs, 1000);
    expect(baseCampRifleRegripAnimationMs, 1850);
    expect(baseCampRifleRegripPostIdleMs, 1000);
    expect(baseCampRifleRegripEventMs, 3850);
    expect(baseCampRifleRegripFrameDurations, [400, 350, 200, 350, 150, 400]);

    expect(baseCampRifleRegripPhase(0), BaseCampRifleRegripPhase.preIdle);
    expect(baseCampRifleRegripPhase(999), BaseCampRifleRegripPhase.preIdle);
    expect(
      baseCampRifleRegripPhase(1000),
      BaseCampRifleRegripPhase.rifleRegrip,
    );
    expect(baseCampRifleRegripFrameIndex(1000), 0);
    expect(baseCampRifleRegripFrameIndex(1400), 1);
    expect(baseCampRifleRegripFrameIndex(1750), 2);
    expect(baseCampRifleRegripFrameIndex(1950), 3);
    expect(baseCampRifleRegripFrameIndex(2300), 4);
    expect(baseCampRifleRegripFrameIndex(2450), 5);
    expect(baseCampRifleRegripPhase(2850), BaseCampRifleRegripPhase.postIdle);
    expect(baseCampRifleRegripPhase(3849), BaseCampRifleRegripPhase.postIdle);
    expect(baseCampRifleRegripPhase(3850), BaseCampRifleRegripPhase.breathing);
  });

  test('rifle regrip random interval is always between 60 and 120 seconds', () {
    expect(baseCampRifleRegripIntervalMs((_) => 0), 60000);
    expect(baseCampRifleRegripIntervalMs((_) => 1), 60001);
    expect(baseCampRifleRegripIntervalMs((_) => 60000), 120000);
  });

  test(
    'all corrected rifle frames are transparent, normalized RGBA assets',
    () async {
      expect(baseCampRifleRegripAssets, hasLength(6));
      final normalMaterial = await _opaqueRgbaMean(
        baseCampBreathingSoldierUpperAsset,
      );
      for (final asset in baseCampRifleRegripAssets) {
        final data = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 512);
        expect(frame.image.height, 512);
        final rgba = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(rgba, isNotNull);
        var top = frame.image.height;
        var bottom = -1;
        final material = await _opaqueRgbaMean(asset);
        for (var y = 0; y < frame.image.height; y++) {
          for (var x = 0; x < frame.image.width; x++) {
            final offset = (y * frame.image.width + x) * 4;
            final alpha = rgba!.getUint8(offset + 3);
            if (alpha == 0) continue;
            top = math.min(top, y);
            bottom = math.max(bottom, y);
          }
        }
        expect(top, 32);
        expect(bottom, 511);
        expect(bottom - top + 1, 480);
        // PNG channel rounding and Flutter's decoder differ by at most 1.5
        // channel values (under 0.6% of the full range).
        expect(material.red, closeTo(normalMaterial.red, 1.5));
        expect(material.green, closeTo(normalMaterial.green, 1.5));
        expect(material.blue, closeTo(normalMaterial.blue, 1.5));
        frame.image.dispose();
        codec.dispose();
      }
    },
  );

  testWidgets('STATUS DATA and SUSTAINMENT retain five nested instruments', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 120));
    final pages = find.byKey(const ValueKey('base-camp-terminal-pages'));
    await tester.drag(pages, const Offset(-320, 0));
    await tester.pump(const Duration(milliseconds: 300));
    for (final pageName in ['morning', 'sustainment']) {
      final page = find.byKey(ValueKey('base-camp-terminal-page-$pageName'));
      final panels = find.descendant(
        of: page,
        matching: find.byKey(const ValueKey('base-camp-instrument-panel')),
      );
      final readouts = find.descendant(
        of: page,
        matching: find.byKey(const ValueKey('base-camp-lcd-readout')),
      );
      expect(panels, findsNWidgets(5));
      expect(readouts, findsNWidgets(5));
      for (final panel in panels.evaluate()) {
        expect(
          tester
              .getRect(find.byElementPredicate((element) => element == panel))
              .bottom,
          // The content viewport ends before the page's 10dp lower padding;
          // keep the complete panel at least 2dp above that boundary.
          lessThanOrEqualTo(tester.getRect(page).bottom - 5.5),
        );
      }
      if (pageName == 'morning') {
        await tester.drag(pages, const Offset(-320, 0));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('instrument geometry remains bounded at accessibility scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: const MaterialApp(home: BaseCampDashboardPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.byKey(const ValueKey('base-camp-instrument-panel')),
      findsNWidgets(6),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('terminal polarity updates the LCD immediately', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(
      find.byKey(const ValueKey('base-camp-lcd-polarity-switch')),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('LCD polarity controls command text and page indicators only', (
    tester,
  ) async {
    DeviceSettingsController.instance.update(
      DeviceSettingsController.instance.value.copyWith(
        baseCampLcdNegative: false,
      ),
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 160));
    final pages = find.byKey(const ValueKey('base-camp-terminal-pages'));
    final indicators = List<Finder>.generate(
      4,
      (index) => find.byKey(ValueKey('base-camp-page-indicator-$index')),
    );
    expect(tester.getSize(indicators[0]), const Size(20, 5));
    expect(tester.getSize(indicators[1]), const Size(8, 5));
    for (var index = 0; index < 3; index++) {
      await tester.drag(pages, const Offset(-320, 0));
      await tester.pump(const Duration(milliseconds: 300));
    }

    final command = tester.widget<Text>(
      find.byKey(const ValueKey('base-camp-command-intent')),
    );
    expect(command.style?.color, const Color(0xff273326));
    final selectedBefore = indicators.indexWhere(
      (indicator) =>
          (tester.widget<AnimatedContainer>(indicator).decoration!
                  as BoxDecoration)
              .color ==
          const Color(0xffc7d6a0),
    );
    expect(selectedBefore, greaterThan(0));
    final active = indicators[selectedBefore];
    final inactive = indicators.firstWhere((indicator) => indicator != active);
    expect(tester.getSize(inactive), const Size(8, 5));

    await tester.tap(
      find.byKey(const ValueKey('base-camp-lcd-polarity-switch')),
    );
    await tester.pump();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('base-camp-command-intent')))
          .style
          ?.color,
      const Color(0xffaeb894),
    );
    expect(
      indicators.indexWhere(
        (indicator) =>
            (tester.widget<AnimatedContainer>(indicator).decoration!
                    as BoxDecoration)
                .color ==
            const Color(0xffc7d6a0),
      ),
      selectedBefore,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ambient waveform preserves the STANDARD label by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OperationAmbientAnimation(status: OperationStatus.green),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('operation-ambient-status-label')),
      findsOneWidget,
    );
  });
}

Future<({double red, double green, double blue})> _opaqueRgbaMean(
  String asset,
) async {
  final data = await rootBundle.load(asset);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  final rgba = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  var red = 0;
  var green = 0;
  var blue = 0;
  var count = 0;
  for (var offset = 0; offset < rgba!.lengthInBytes; offset += 4) {
    if (rgba.getUint8(offset + 3) < 16) continue;
    red += rgba.getUint8(offset);
    green += rgba.getUint8(offset + 1);
    blue += rgba.getUint8(offset + 2);
    count++;
  }
  frame.image.dispose();
  codec.dispose();
  return (red: red / count, green: green / count, blue: blue / count);
}
