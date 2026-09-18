import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/theme/app_text_styles.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/widgets/operation_date_nixie_display.dart';

void main() {
  test('NIXIE textual labels increase by one pixel without changing cells', () {
    expect(NixiePresentationTypography.previousTextualFontSize, 15);
    expect(NixiePresentationTypography.textualFontSize, 16);
    expect(
      NixiePresentationTypography.textualFontSize,
      NixiePresentationTypography.previousTextualFontSize + 1,
    );
    expect(NixiePresentationTypography.textualFontWeight, FontWeight.normal);
    expect(NixiePresentationTypography.textualLetterSpacing, 0);
    expect(OperationDateNixieDisplay.dateTileWidth, 42);
    expect(OperationDateNixieDisplay.tileHeight, 36);
    expect(OperationDateNixieDisplay.tileGap, 6);
  });

  test('rear cathodes are limited, dark wire electrodes without glow', () {
    expect(NixieRearCathodePresentation.digits, ['8', '9']);
    expect(NixieRearCathodePresentation.monthWeekdayPattern, ['0', '8', '0']);
    expect(NixieRearCathodePresentation.dayPattern, ['0', '8']);
    expect(NixieRearCathodePresentation.opacity, .32);
    expect(
      NixieRearCathodePresentation.matchingActiveOpacity,
      lessThan(NixieRearCathodePresentation.opacity),
    );
    expect(NixieRearCathodePresentation.strokeWidth, greaterThan(0));
    expect(NixieRearCathodePresentation.strokeWidth, .7);
    expect(NixieRearCathodePresentation.eightOffset, const Offset(-.5, .5));
    expect(NixieRearCathodePresentation.nineOffset, const Offset(.75, -.6));
    expect(NixieRearCathodePresentation.opacityFor('8', '8'), .19);
    expect(NixieRearCathodePresentation.opacityFor('1', '8'), .32);
  });

  testWidgets('rear cathodes remain subordinate for every active digit', (
    tester,
  ) async {
    for (var digit = 0; digit < 10; digit++) {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: NixieTubeCell(value: '0', width: 42, height: 36),
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NixieTubeCell(
                value: '$digit',
                width: 42,
                height: 36,
                animate: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final rearEight = find.byKey(const ValueKey('nixie-rear-cathode-8'));
      final rearNine = find.byKey(const ValueKey('nixie-rear-cathode-9'));
      expect(rearEight, findsOneWidget);
      expect(rearNine, findsOneWidget);
      expect(find.byKey(ValueKey('nixie-active-$digit')), findsOneWidget);

      final rearStyle = tester.widget<Text>(rearEight).style!;
      expect(rearStyle.foreground, isNotNull);
      expect(rearStyle.shadows, isNull);
      expect(
        tester
            .getRect(rearEight)
            .overlaps(
              tester.getRect(find.byKey(ValueKey('nixie-active-$digit'))),
            ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('date fields distribute static rear electrodes by character', (
    tester,
  ) async {
    await _pumpNixie(
      tester,
      width: 390,
      date: OperationLocalDate.parse('2026-09-18'),
    );

    _expectDateRearPattern(tester, 'month', ['0', '8', '0']);
    _expectDateRearPattern(tester, 'day', ['0', '8']);
    _expectDateRearPattern(tester, 'weekday', ['0', '8', '0']);
    expect(find.byKey(const ValueKey('nixie-label-SEP')), findsOneWidget);
    expect(find.byKey(const ValueKey('nixie-active-18')), findsOneWidget);
    expect(find.byKey(const ValueKey('nixie-label-FRI')), findsOneWidget);
  });

  testWidgets(
    'all NIXIE month labels fit their unchanged cells at all widths',
    (tester) async {
      for (final width in [320.0, 390.0, 900.0]) {
        for (var month = 1; month <= 12; month++) {
          final date = OperationLocalDate.parse(
            '2026-${month.toString().padLeft(2, '0')}-01',
          );
          await _pumpNixie(tester, width: width, date: date);
          _expectLabelFits(tester, _monthLabels[month - 1], fieldIndex: 0);
          _expectDateRearPattern(tester, 'month', ['0', '8', '0']);
        }
      }
    },
  );

  testWidgets(
    'all NIXIE weekday labels fit their unchanged cells at all widths',
    (tester) async {
      final monday = OperationLocalDate.parse('2026-01-05');
      for (final width in [320.0, 390.0, 900.0]) {
        for (var day = 0; day < _weekdayLabels.length; day++) {
          await _pumpNixie(tester, width: width, date: monday.addDays(day));
          _expectLabelFits(tester, _weekdayLabels[day], fieldIndex: 2);
          _expectDateRearPattern(tester, 'weekday', ['0', '8', '0']);
        }
      }
    },
  );

  testWidgets('representative day values retain two rear cathode positions', (
    tester,
  ) async {
    for (final day in ['01', '08', '10', '18', '28', '31']) {
      await _pumpNixie(
        tester,
        width: 390,
        date: OperationLocalDate.parse('2026-01-$day'),
      );
      _expectDateRearPattern(tester, 'day', ['0', '8']);
      expect(find.byKey(ValueKey('nixie-active-$day')), findsOneWidget);
    }
  });
}

const _monthLabels = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];

const _weekdayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

Future<void> _pumpNixie(
  WidgetTester tester, {
  required double width,
  required OperationLocalDate date,
}) async {
  tester.view.physicalSize = Size(width, 300);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: OperationDateNixieDisplay(
            operationDateFuture: Future.value(date),
            transitionToken: 0,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void _expectLabelFits(
  WidgetTester tester,
  String label, {
  required int fieldIndex,
}) {
  final labelFinder = find.byKey(ValueKey('nixie-label-$label'));
  final fieldFinder = find.byKey(
    ValueKey('operation-date-nixie-field-$fieldIndex'),
  );
  expect(labelFinder, findsOneWidget);
  expect(fieldFinder, findsOneWidget);

  final text = tester.widget<Text>(labelFinder);
  final style = text.style!;
  expect(style.fontFamily, AppTextStyles.bootTechnicalFontFamily);
  expect(style.fontSize, NixiePresentationTypography.textualFontSize);
  expect(style.fontWeight, NixiePresentationTypography.textualFontWeight);
  expect(style.letterSpacing, NixiePresentationTypography.textualLetterSpacing);
  expect(style.shadows, NixiePresentationColors.textualShadows);

  final labelRect = tester.getRect(labelFinder);
  final fieldRect = tester.getRect(fieldFinder);
  expect(labelRect.left, greaterThan(fieldRect.left));
  expect(labelRect.right, lessThan(fieldRect.right));
  expect(labelRect.top, greaterThan(fieldRect.top));
  expect(labelRect.bottom, lessThan(fieldRect.bottom));
}

void _expectDateRearPattern(
  WidgetTester tester,
  String field,
  List<String> pattern,
) {
  for (var index = 0; index < pattern.length; index++) {
    final cathode = find.byKey(
      ValueKey('nixie-date-rear-$field-$index-${pattern[index]}'),
    );
    expect(cathode, findsOneWidget);
    final style = tester.widget<Text>(cathode).style!;
    expect(style.foreground, isNotNull);
    expect(style.shadows, isNull);
  }
}
