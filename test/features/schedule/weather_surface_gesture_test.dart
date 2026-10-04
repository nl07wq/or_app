import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/theme/app_colors.dart';
import 'package:or_app/core/widgets/holographic_ambient_background.dart';
import 'package:or_app/features/operation_date/services/japanese_holiday_reference_service.dart';
import 'package:or_app/features/reminders/models/reminder_definition.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/schedule/models/schedule_record.dart';
import 'package:or_app/features/schedule/pages/calendar_page.dart';
import 'package:or_app/features/schedule/weather_forecast_summary.dart';
import 'package:or_app/features/weather/weather_models.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  setUp(() {
    AppRepositoryRegistry.install(
      AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase()),
    );
  });

  tearDown(AppRepositoryRegistry.resetForTesting);

  test('month grid retains the Operation Date weekend and holiday colors', () {
    expect(
      calendarMonthGridWeekdayColor(0),
      AppColors.danger.withValues(alpha: calendarMonthGridWeekendColorOpacity),
    );
    expect(
      calendarMonthGridWeekdayColor(6),
      AppColors.primary.withValues(alpha: calendarMonthGridWeekendColorOpacity),
    );
    expect(calendarMonthGridWeekdayColor(1), isNull);

    expect(
      calendarMonthGridDateColor(
        date: DateTime(2026, 10, 3),
        holidayMatch: JapaneseHolidayMatch.notHoliday,
      ),
      AppColors.primary.withValues(alpha: calendarMonthGridWeekendColorOpacity),
    );
    expect(
      calendarMonthGridDateColor(
        date: DateTime(2026, 10, 4),
        holidayMatch: JapaneseHolidayMatch.notHoliday,
      ),
      AppColors.danger.withValues(alpha: calendarMonthGridWeekendColorOpacity),
    );
    expect(
      calendarMonthGridDateColor(
        date: DateTime(2026, 10, 12),
        holidayMatch: JapaneseHolidayMatch.holiday,
      ),
      AppColors.danger.withValues(alpha: calendarMonthGridWeekendColorOpacity),
    );
    expect(
      calendarMonthGridDateColor(
        date: DateTime(2026, 10, 13),
        holidayMatch: JapaneseHolidayMatch.notHoliday,
      ),
      isNull,
    );
  });

  test('month grid reserves fixed anchors independently of entry metadata', () {
    expect(calendarMonthGridDateTopAnchor, 4);
    expect(calendarMonthGridMetadataHeight, 16);
    expect(calendarMonthGridMetadataBottomInset, 5);
    expect(calendarMonthGridWeekendColorOpacity, .60);
    expect(calendarMonthGridWeekRowBandOpacity, .020);
    expect(calendarMonthGridSelectedFillOpacity, .18);
    expect(calendarMonthGridUsesSelectedOutline, isFalse);
    expect(calendarMonthGridUsesTodayOutline, isFalse);
    expect(calendarMonthGridMainAxisExtent(33.7), 50);
    expect(calendarMonthGridMainAxisExtent(64), 64);
    expect(calendarMonthGridUsesVerticalColumnBands, isFalse);
    expect(calendarMonthGridUsesHorizontalWeekSeparators, isFalse);
    expect(calendarMonthGridUsesOverallHudSurface, isTrue);
    expect(calendarMonthGridUsesLocalMonthControlFrame, isFalse);
    expect(calendarMonthGridTelemetryDividerOpacity, .24);
    expect(calendarTimelineUsesIndividualEntryCards, isFalse);
    expect(
      calendarMonthGridWeekRowBandColor(ThemeData.dark().colorScheme),
      ThemeData.dark().colorScheme.onSurface.withValues(alpha: .020),
    );
    expect(
      calendarMonthGridSelectedFillColor(ThemeData.dark().colorScheme),
      ThemeData.dark().colorScheme.primary.withValues(alpha: .18),
    );
    expect(
      calendarMonthGridTelemetryDividerColor(ThemeData.dark().colorScheme),
      ThemeData.dark().colorScheme.primary.withValues(alpha: .24),
    );
    for (var row = 0; row < 6; row++) {
      expect(calendarMonthGridWeekRowIsSubtle(row), row.isEven);
    }
  });

  testWidgets('month grid keeps dot-only Today and selected fill responsive', (
    tester,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selectedTomorrow = today.add(const Duration(days: 1));
    final todayKey = _dateText(today);
    final tomorrowKey = _dateText(selectedTomorrow);

    for (final width in <double>[320, 390, 900]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(
        MaterialApp(
          home: CalendarPage(key: ValueKey(width), initialDate: today),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('holographic-ambient-background')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('holographic-scanline-overlay')),
        findsNWidgets(2),
      );
      final todayCell = find.byKey(ValueKey('calendar-day-$todayKey'));
      expect(todayCell, findsOneWidget);
      expect(
        find.byKey(ValueKey('calendar-day-today-dot-$todayKey')),
        findsOneWidget,
      );
      final selectedDecoration =
          tester.widget<Container>(todayCell).decoration! as ShapeDecoration;
      expect(selectedDecoration.shape, isA<BeveledRectangleBorder>());

      await tester.tap(find.byKey(ValueKey('calendar-day-$tomorrowKey')));
      await tester.pumpAndSettle();
      final todayDecoration = tester.widget<Container>(todayCell).decoration;
      final tomorrowDecoration =
          tester
                  .widget<Container>(
                    find.byKey(ValueKey('calendar-day-$tomorrowKey')),
                  )
                  .decoration!
              as ShapeDecoration;
      expect(todayDecoration, isNull);
      expect(tomorrowDecoration.shape, isA<BeveledRectangleBorder>());
      expect(tester.takeException(), isNull);
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('ambient geometry stays visible and static with reduced motion', (
    tester,
  ) async {
    expect(holographicCircuitRouteCount, 8);
    expect(holographicCircuitMinimumRouteSegments, 8);
    expect(holographicCircuitMaximumRouteSegments, 14);
    expect(holographicCircuitSignalPixelsPerSecond, 190);
    expect(holographicCircuitIdleDuration, const Duration(seconds: 4));
    expect(holographicCircuitAfterglowDuration, const Duration(seconds: 5));
    expect(
      holographicCircuitTerminalNodeDuration,
      const Duration(milliseconds: 420),
    );
    expect(holographicAmbientUpdateCadence, const Duration(milliseconds: 50));
    expect(holographicCircuitRoutes, hasLength(holographicCircuitRouteCount));
    expect(
      holographicCircuitRoutes.every(
        (route) =>
            route.segmentCount >= holographicCircuitMinimumRouteSegments &&
            route.segmentCount <= holographicCircuitMaximumRouteSegments,
      ),
      isTrue,
    );
    expect(
      holographicCircuitRoutes.where((route) => route.terminalNode),
      hasLength(3),
    );
    expect(
      holographicCircuitRoutes.every(
        (route) => route.nodePointIndexes.every(
          (index) => index > 0 && index < route.points.length - 1,
        ),
      ),
      isTrue,
    );
    expect(
      holographicCircuitRoutes.every(
        (route) => route.nodePointIndexes.isNotEmpty,
      ),
      isTrue,
    );
    expect(
      holographicCircuitTrafficScenarios,
      hasLength(holographicCircuitRouteCount),
    );
    expect(
      holographicCircuitTrafficScenarios.every(
        (scenario) =>
            scenario.entries.length <=
            holographicCircuitMaximumConcurrentSignals,
      ),
      isTrue,
    );
    expect(
      holographicCircuitTrafficScenarios.where(
        (scenario) => scenario.entries.length == 2,
      ),
      hasLength(3),
    );
    expect(
      holographicCircuitTrafficScenarios
          .map((scenario) => scenario.entries.first.routeIndex)
          .toSet(),
      hasLength(holographicCircuitRouteCount),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: HolographicAmbientBackground()),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('holographic-ambient-background')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(HolographicAmbientBackground),
        matching: find.byType(IgnorePointer),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HolographicScanlineOverlay())),
    );
    expect(
      find.byKey(const ValueKey('holographic-scanline-overlay')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(HolographicScanlineOverlay),
        matching: find.byType(IgnorePointer),
      ),
      findsOneWidget,
    );
  });

  testWidgets('timeline keeps entries in its open HUD structure', (
    tester,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    await AppRepositoryRegistry.container.schedules.save(
      ScheduleRecord(
        id: 'open-timeline-entry',
        localDate: _dateText(today),
        type: ScheduleType.work,
        title: 'Open timeline',
        startTime: '11:00',
        endTime: '19:00',
        createdAt: DateTime.utc(2026, 10, 4),
        updatedAt: DateTime.utc(2026, 10, 4),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: CalendarPage(initialDate: today)),
    );
    await tester.pumpAndSettle();

    final content = find.byKey(
      const ValueKey('calendar-timeline-content-open-timeline-entry'),
    );
    expect(content, findsOneWidget);
    expect(tester.widget<Container>(content).decoration, isNull);
    expect(
      find.byKey(const ValueKey('calendar-timeline-floating-surface')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar retains its English HUD telemetry legend', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CalendarPage()));
    await tester.pumpAndSettle();

    expect(find.text('SCHEDULE │ REMINDER'), findsOneWidget);
    expect(find.text('スケジュール │ リマインダー'), findsNothing);
    expect(find.text('CALENDAR // DATE MATRIX'), findsNothing);
  });

  testWidgets(
    'Calendar shows Japanese operation labels and reminder identity',
    (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final key = _dateText(today);
      final timestamp = DateTime.utc(2026, 10, 4);
      await AppRepositoryRegistry.container.schedules.save(
        ScheduleRecord(
          id: 'other-entry',
          localDate: key,
          type: ScheduleType.other,
          title: 'Other entry',
          allDay: true,
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );
      for (final entry in [
        (id: 'work-entry', type: ScheduleType.work),
        (id: 'personal-entry', type: ScheduleType.personal),
        (id: 'appointment-entry', type: ScheduleType.appointment),
        (id: 'training-entry', type: ScheduleType.training),
      ]) {
        await AppRepositoryRegistry.container.schedules.save(
          ScheduleRecord(
            id: entry.id,
            localDate: key,
            type: entry.type,
            title: entry.id,
            allDay: true,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
      }
      await AppRepositoryRegistry.container.reminders.saveDefinition(
        ReminderDefinition(
          id: 'reminder-entry',
          title: 'Reminder entry',
          startDate: key,
          allDay: true,
          recurrence: ReminderRecurrence.none,
          active: true,
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: CalendarPage(initialDate: today)),
      );
      await tester.pumpAndSettle();

      expect(find.text('今日の予定'), findsOneWidget);
      expect(find.text('終日'), findsNWidgets(6));
      expect(find.text('勤務'), findsOneWidget);
      expect(find.text('プライベート'), findsOneWidget);
      expect(find.text('アポイント'), findsOneWidget);
      expect(find.text('トレーニング'), findsOneWidget);
      expect(find.text('リマインダー'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
      expect(find.byIcon(Icons.diamond_outlined), findsNothing);
      expect(find.text('その他'), findsOneWidget);
      expect(find.text('ALL DAY'), findsNothing);
      expect(find.text('OTHER'), findsNothing);
      expect(find.text('予定を追加'), findsOneWidget);
    },
  );

  test('temperature range rail reserves numeric telemetry clearance', () {
    expect(weatherTemperatureRailWidth(296), 88);
    expect(weatherTemperatureRailWidth(366), 158);
    expect(weatherTemperatureRailWidth(620), 250);
    expect(weatherTemperatureRailWidth(320), 112);
  });

  test('forecast row opens daily detail only on a deliberate second tap', () {
    expect(weatherForecastRowOpensDetail(selected: false), isFalse);
    expect(weatherForecastRowOpensDetail(selected: true), isTrue);
  });

  test('weekly forecast separates date and weather identities', () {
    expect(weatherForecastUsesSplitLeftBlocks, isTrue);
    expect(weatherForecastLowHighPairAlignment, MainAxisAlignment.center);
    expect(weatherForecastDateBlockAlignment, CrossAxisAlignment.center);
    expect(weatherForecastDateTextAlignment, TextAlign.center);
    expect(weatherForecastDateVerticalOffset, -14);
    expect(weatherForecastDateInternalGap, 2);
    expect(weatherForecastDateFontSize, 14);
    expect(weatherForecastWeatherBlockAlignment, CrossAxisAlignment.center);
    expect(weatherForecastWeatherTextAlignment, TextAlign.center);
  });

  test('weekly forecast gives yesterday its own date identity', () {
    expect(
      weatherForecastDateLabel(
        DateTime(2026, 10, 3),
        today: false,
        yesterday: true,
      ),
      '昨日',
    );
  });

  test(
    'retains recent-past selection while weekly values stay today plus six',
    () {
      final snapshot = _recentPastSnapshot();

      for (final offset in [-1, -7, -31]) {
        final date = DateTime(2026, 10, 4).add(Duration(days: offset));
        final dateText = _dateText(date);
        final selected = weatherDailyForDate(snapshot, dateText);
        expect(selected, isNotNull, reason: 'daily $offset');
        expect(weatherHourlyForDay(snapshot, selected!), isNotEmpty);
      }
      expect(weatherDailyForDate(snapshot, '2026-09-02'), isNull);

      final forecast = weatherSevenDayForecastValues(
        snapshot.daily,
        today: DateTime(2026, 10, 4),
      );
      expect(forecast, hasLength(7));
      expect(forecast.first.date, '2026-10-04');
      expect(forecast.last.date, '2026-10-10');
    },
  );

  test(
    'weekly compact telemetry formats only the formal daily maximum wind',
    () {
      expect(weatherDailyMaxWindLabel(14), '14km/h');
      expect(weatherDailyMaxWindLabel(null), '--');
    },
  );

  test('daily-detail temperature rail keeps LOW and HIGH as its base', () {
    final normal = weatherTemperatureDetailScale(
      low: 17,
      high: 23,
      apparent: 20,
    )!;
    expect(normal.minimum, 17);
    expect(normal.maximum, 23);
    expect(normal.lowFraction, 0);
    expect(normal.highFraction, 1);
    expect(normal.apparentFraction, closeTo(.5, .001));

    final atHigh = weatherTemperatureDetailScale(
      low: 17,
      high: 23,
      apparent: 23,
    )!;
    expect(atHigh.lowFraction, 0);
    expect(atHigh.highFraction, 1);
    expect(atHigh.apparentFraction, 1);

    final belowRange = weatherTemperatureDetailScale(
      low: 17,
      high: 23,
      apparent: 14,
    )!;
    expect(belowRange.minimum, 14);
    expect(belowRange.maximum, 23);
    expect(belowRange.apparentFraction, 0);
    expect(belowRange.lowFraction, closeTo(1 / 3, .001));
    expect(belowRange.highFraction, 1);

    final aboveRange = weatherTemperatureDetailScale(
      low: 17,
      high: 23,
      apparent: 26,
    )!;
    expect(aboveRange.minimum, 17);
    expect(aboveRange.maximum, 26);
    expect(aboveRange.lowFraction, 0);
    expect(aboveRange.highFraction, closeTo(2 / 3, .001));
    expect(aboveRange.apparentFraction, 1);
  });

  test('precipitation probability meter preserves exact fill ratios', () {
    expect(weatherProbabilityMeterFillFraction(0), 0);
    expect(weatherProbabilityMeterFillFraction(.06), .06);
    expect(weatherProbabilityMeterFillFraction(.29), .29);
    expect(weatherProbabilityMeterFillFraction(.73), .73);
    expect(weatherProbabilityMeterFillFraction(1), 1);
  });

  test('humidity meter preserves exact fill ratios', () {
    expect(weatherHumidityMeterFillFraction(0), 0);
    expect(weatherHumidityMeterFillFraction(.56), .56);
    expect(weatherHumidityMeterFillFraction(.73), .73);
    expect(weatherHumidityMeterFillFraction(1), 1);
  });

  test('detail meters render an explicit left-origin fill width', () {
    expect(weatherDetailMeterFillWidth(trackWidth: 200, fraction: 0), 0);
    expect(weatherDetailMeterFillWidth(trackWidth: 200, fraction: .18), 36);
    expect(weatherDetailMeterFillWidth(trackWidth: 200, fraction: .52), 104);
    expect(weatherDetailMeterFillWidth(trackWidth: 200, fraction: 1), 200);
  });

  test('meter fractions remain safely bounded', () {
    expect(weatherProbabilityMeterFillFraction(-1), 0);
    expect(weatherProbabilityMeterFillFraction(2), 1);
    expect(weatherProbabilityMeterFillFraction(.06), .06);
    expect(weatherProbabilityMeterFillFraction(.14), .14);
  });

  test(
    'daily precipitation telemetry derives variable WMO intensity stages',
    () {
      void expectDescriptor(
        int code,
        String type,
        String intensity,
        int activeSegments,
        int totalSegments,
      ) {
        final descriptor = weatherPrecipitationDescriptorForCode(code);
        expect(descriptor.type, type, reason: 'weather code $code');
        expect(descriptor.intensity, intensity, reason: 'weather code $code');
        expect(
          descriptor.activeSegments,
          activeSegments,
          reason: 'weather code $code active segments',
        );
        expect(
          descriptor.totalSegments,
          totalSegments,
          reason: 'weather code $code total segments',
        );
      }

      // WMO families with three formal intensity stages.
      expectDescriptor(51, '霧雨', '弱', 1, 3);
      expectDescriptor(53, '霧雨', '中', 2, 3);
      expectDescriptor(55, '霧雨', '強', 3, 3);
      expectDescriptor(61, '雨', '弱', 1, 3);
      expectDescriptor(63, '雨', '中', 2, 3);
      expectDescriptor(65, '雨', '強', 3, 3);
      expectDescriptor(80, 'にわか雨', '弱', 1, 3);
      expectDescriptor(81, 'にわか雨', '中', 2, 3);
      expectDescriptor(82, 'にわか雨', '強', 3, 3);

      // WMO freezing-drizzle is a two-stage family: strong is 2/2, never 2/3.
      expectDescriptor(56, '凍る霧雨', '弱', 1, 2);
      expectDescriptor(57, '凍る霧雨', '強', 2, 2);
    },
  );

  test(
    'daily precipitation descriptor safely handles dry, null, and unknown codes',
    () {
      final dry = weatherPrecipitationDescriptorForCode(0);
      expect(dry.type, '-');
      expect(dry.intensity, '-');
      expect(dry.hasType, isFalse);
      expect(dry.hasComparableIntensity, isFalse);

      final missing = weatherPrecipitationDescriptorForCode(null);
      expect(missing.type, '--');
      expect(missing.intensity, '--');

      // Snow grains and thunderstorm/hail variants are not a formal
      // weak-to-strong series, so their variant is retained without segments.
      for (final code in [77, 95, 96, 99]) {
        expect(
          weatherPrecipitationDescriptorForCode(code).hasComparableIntensity,
          isFalse,
          reason: 'weather code $code',
        );
      }
    },
  );

  test('precipitation symbols retain the production mapping', () {
    expect(weatherPrecipitationIntensitySegments('弱'), 1);
    expect(weatherPrecipitationIntensitySegments('中'), 2);
    expect(weatherPrecipitationIntensitySegments('強'), 3);
    expect(weatherPrecipitationIntensitySegments('--'), 0);
    expect(weatherPrecipitationIntensitySegments(null), 0);

    expect(weatherPrecipitationSymbolForType('雨'), Icons.umbrella_outlined);
    expect(weatherPrecipitationSymbolForType('にわか雨'), Icons.umbrella_outlined);
    expect(weatherPrecipitationSymbolForType('雪'), Icons.ac_unit);
    expect(
      weatherPrecipitationSymbolForType('雷雨'),
      Icons.thunderstorm_outlined,
    );
    expect(weatherPrecipitationSymbolForType('-'), isNull);
    expect(weatherPrecipitationSymbolForType(null), isNull);
  });

  test(
    'precipitation telemetry keeps four columns at 390 and collapses at 320',
    () {
      expect(weatherPrecipitationUsesCompactGrid(256), isTrue);
      expect(weatherPrecipitationUsesCompactGrid(326), isFalse);
      expect(weatherPrecipitationUsesCompactGrid(800), isFalse);
    },
  );

  test('weekly peak cue only reuses the existing forecast summary output', () {
    const summary = WeatherForecastSummary(
      primary: '午後から雨の予報です。',
      supporting: ['降水 1.7mm · 最大降水確率 96%（夕方）'],
      strongestWindDaypart: null,
    );
    const noPrecipitationCue = WeatherForecastSummary(
      primary: '曇り中心の予報です。',
      supporting: ['午後は風が強まる予報です。'],
      strongestWindDaypart: null,
    );

    expect(weatherForecastPeakPrecipitationTiming(summary), '夕方');
    expect(weatherForecastPeakPrecipitationTiming(noPrecipitationCue), isNull);
  });

  test('solar progress is a daytime time marker only', () {
    expect(
      weatherSolarProgress(
        '2026-10-02T06:00',
        '2026-10-02T18:00',
        now: DateTime(2026, 10, 2, 12),
      ),
      closeTo(.5, .001),
    );
    expect(
      weatherSolarProgress(
        '2026-10-02T06:00',
        '2026-10-02T18:00',
        now: DateTime(2026, 10, 2, 4),
      ),
      isNull,
    );
  });

  test('solar trajectory is an actual-time daylight progression curve', () {
    const size = Size(300, 58);
    const sunriseFraction = .25;
    const sunsetFraction = .75;
    final sunrise = weatherSolarDaylightPoint(
      size,
      sunriseFraction,
      sunsetFraction,
      0,
    );
    final midpoint = weatherSolarDaylightPoint(
      size,
      sunriseFraction,
      sunsetFraction,
      .5,
    );
    final sunset = weatherSolarDaylightPoint(
      size,
      sunriseFraction,
      sunsetFraction,
      1,
    );

    expect(weatherSolarDayFraction('2026-10-02T06:00'), .25);
    expect(sunrise.dy, closeTo(sunset.dy, .001));
    expect(sunrise.dy, closeTo(31, .001));
    expect(midpoint.dx, closeTo((sunrise.dx + sunset.dx) / 2, .001));
    expect(midpoint.dy, closeTo(1, .001));
  });

  test('header location keeps the city/area name primary', () {
    expect(weatherHeaderLocationText('市原市 / 千葉県'), '市原市');
    expect(weatherHeaderLocationText('千葉市, 千葉県'), '千葉市');
    expect(weatherHeaderLocationText(null), '場所未設定');
  });

  Future<void> pumpSurface(
    WidgetTester tester, {
    required ValueChanged<int> onSwipe,
    bool enabled = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 160,
            height: 72,
            child: WeatherSurfaceGesture(
              enabled: enabled,
              onSwipeLocation: onSwipe,
              child: const ColoredBox(
                key: ValueKey('weather-surface-gesture-child'),
                color: Colors.transparent,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('inside-start horizontal location swipe owns its full drag', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 390.0, 900.0]) {
      final directions = <int>[];
      await tester.binding.setSurfaceSize(Size(width, 400));
      await pumpSurface(tester, onSwipe: directions.add);

      await tester.timedDrag(
        find.byKey(const ValueKey('weather-surface-gesture-child')),
        const Offset(-240, 0),
        const Duration(milliseconds: 180),
      );

      expect(directions, [1], reason: 'width $width');
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets(
    'small horizontal drags and vertical scroll do not switch location',
    (tester) async {
      final directions = <int>[];
      await pumpSurface(tester, onSwipe: directions.add);
      final surface = find.byKey(
        const ValueKey('weather-surface-gesture-child'),
      );

      await tester.timedDrag(
        surface,
        const Offset(-12, 0),
        const Duration(milliseconds: 400),
      );
      await tester.drag(surface, const Offset(0, -160));

      expect(directions, isEmpty);
    },
  );

  testWidgets('a single saved location does not claim a horizontal gesture', (
    tester,
  ) async {
    final directions = <int>[];
    await pumpSurface(tester, enabled: false, onSwipe: directions.add);

    await tester.drag(
      find.byKey(const ValueKey('weather-surface-gesture-child')),
      const Offset(180, 0),
    );

    expect(directions, isEmpty);
  });
}

WeatherSnapshot _recentPastSnapshot() {
  const location = WeatherLocation(
    displayName: 'Tokyo',
    latitude: 35.68,
    longitude: 139.76,
    timezone: 'Asia/Tokyo',
  );
  final dates = List.generate(
    38,
    (index) => DateTime(2026, 9, 3).add(Duration(days: index)),
  );
  return WeatherSnapshot(
    location: location,
    fetchedAt: DateTime.utc(2026, 10, 4),
    daily: dates
        .map(
          (date) => WeatherDaily(
            date: _dateText(date),
            code: 0,
            high: 23,
            low: 17,
            precipitationProbability: 18,
            precipitation: 0,
            sunrise: '${_dateText(date)}T05:30',
            sunset: '${_dateText(date)}T17:00',
          ),
        )
        .toList(growable: false),
    hourly: dates
        .map(
          (date) => WeatherHourly(
            time: '${_dateText(date)}T12:00',
            temperature: 20,
            apparentTemperature: 20,
            humidity: 60,
            precipitationProbability: 18,
            precipitation: 0,
            code: 0,
            cloudCover: 20,
            windSpeed: 8,
            windGust: 12,
          ),
        )
        .toList(growable: false),
  );
}

String _dateText(DateTime value) => value.toIso8601String().split('T').first;
