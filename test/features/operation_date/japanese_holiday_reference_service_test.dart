import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:or_app/core/widgets/operation_flip_tile.dart';
import 'package:or_app/core/theme/app_colors.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/services/japanese_holiday_reference_service.dart';
import 'package:or_app/features/operation_date/widgets/operation_date_flip_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'loads the distributed snapshot and stores the reference cache',
    () async {
      final service = JapaneseHolidayReferenceService(
        assetLoader: () async => _asset(),
        clock: () => DateTime.utc(2026, 8, 16, 12),
      );

      final status = await service.load();

      expect(status.isAvailable, isTrue);
      expect(status.updateSucceeded, isTrue);
      expect(status.localUpdatedAt, DateTime.utc(2026, 8, 16, 12));
      expect(
        status.snapshot!.classify('2026-08-11'),
        JapaneseHolidayMatch.holiday,
      );
      expect(
        status.snapshot!.classify('2026-08-12'),
        JapaneseHolidayMatch.notHoliday,
      );
      expect(
        status.snapshot!.classify('2028-01-01'),
        JapaneseHolidayMatch.unavailable,
      );
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(JapaneseHolidayReferenceService.cacheKey),
        isNotNull,
      );
    },
  );

  test('uses a valid cache without loading the distributed asset', () async {
    final initial = JapaneseHolidayReferenceService(
      assetLoader: () async => _asset(),
    );
    await initial.load();
    var assetLoads = 0;
    final cached = JapaneseHolidayReferenceService(
      assetLoader: () async {
        assetLoads++;
        throw StateError('not expected');
      },
    );

    final status = await cached.load();

    expect(status.isAvailable, isTrue);
    expect(assetLoads, 0);
  });

  test('failed update retains the last valid cache', () async {
    final initial = JapaneseHolidayReferenceService(
      assetLoader: () async => _asset(),
    );
    final before = await initial.load();
    final failing = JapaneseHolidayReferenceService(
      assetLoader: () async => throw StateError('offline'),
    );

    final after = await failing.update();

    expect(after.updateSucceeded, isFalse);
    expect(after.isAvailable, isTrue);
    expect(after.snapshot!.holidays, before.snapshot!.holidays);
  });

  test('failed first load leaves holiday classification unavailable', () async {
    final service = JapaneseHolidayReferenceService(
      assetLoader: () async => throw StateError('offline'),
    );

    final status = await service.load();

    expect(status.updateSucceeded, isFalse);
    expect(status.isAvailable, isFalse);
  });

  test('weekday color prioritizes holiday and keeps weekend fallback', () {
    expect(
      operationDateWeekdayColor(
        date: DateTime.utc(2026, 8, 11),
        holidayMatch: JapaneseHolidayMatch.holiday,
      ),
      AppColors.danger,
    );
    expect(
      operationDateWeekdayColor(
        date: DateTime.utc(2026, 8, 15),
        holidayMatch: JapaneseHolidayMatch.unavailable,
      ),
      AppColors.primary,
    );
    expect(
      operationDateWeekdayColor(
        date: DateTime.utc(2026, 8, 16),
        holidayMatch: JapaneseHolidayMatch.unavailable,
      ),
      AppColors.danger,
    );
    expect(
      operationDateWeekdayColor(
        date: DateTime.utc(2026, 8, 17),
        holidayMatch: JapaneseHolidayMatch.notHoliday,
      ),
      isNull,
    );
  });

  testWidgets('shared calendar colors only the holiday weekday tile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = JapaneseHolidayReferenceService(
      assetLoader: () async => _asset(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OperationDateFlipCalendar(
            operationDateFuture: Future.value(
              OperationLocalDate.parse('2026-08-11'),
            ),
            transitionToken: 0,
            holidayService: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final month = tester.widget<OperationMechanicalFlipTile>(
      find.byKey(const ValueKey('operation-date-tile-0')),
    );
    final day = tester.widget<OperationMechanicalFlipTile>(
      find.byKey(const ValueKey('operation-date-tile-1')),
    );
    final weekday = tester.widget<OperationMechanicalFlipTile>(
      find.byKey(const ValueKey('operation-date-tile-2')),
    );
    expect(month.textStyle, isNull);
    expect(day.textStyle, isNull);
    expect(weekday.textStyle?.color, AppColors.danger);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('operation-date-flip-row')))
          .width,
      168,
    );
    expect(tester.takeException(), isNull);
  });
}

String _asset() => jsonEncode({
  'schemaVersion': 1,
  'source': 'cabinet_office_japan',
  'sourceUrl': 'https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv',
  'dataUpdatedAt': '2026-08-16T00:00:00Z',
  'coverageFrom': '2026-01-01',
  'coverageTo': '2027-12-31',
  'holidays': ['2026-08-11'],
});
