import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/body_history/models/body_history_models.dart';
import 'package:or_app/features/command_center/models/daily_assessment.dart';
import 'package:or_app/features/command_center/services/daily_weight_reference_resolver.dart';

void main() {
  test('measured today always wins over historical means', () {
    final result = DailyWeightReferenceResolver.resolve(
      operationDate: '2026-08-10',
      measuredTodayKg: 91.2,
      history: _points([90, 90, 90, 90]),
    );
    expect(result.valueKg, 91.2);
    expect(result.source, DailyWeightReferenceSource.measuredToday);
  });

  test('uses seven then fourteen day fallback only when today is missing', () {
    final seven = DailyWeightReferenceResolver.resolve(
      operationDate: '2026-08-10',
      measuredTodayKg: null,
      history: _points([90, 93, 96]),
    );
    expect(seven.valueKg, 93);
    expect(seven.source, DailyWeightReferenceSource.sevenDayMean);

    final fourteen = DailyWeightReferenceResolver.resolve(
      operationDate: '2026-08-10',
      measuredTodayKg: null,
      history: [
        _point('2026-07-28', 84),
        _point('2026-08-03', 87),
        _point('2026-08-09', 90),
      ],
    );
    expect(fourteen.valueKg, 87);
    expect(fourteen.source, DailyWeightReferenceSource.fourteenDayMean);
  });

  test('does not use values older than fourteen calendar days', () {
    final result = DailyWeightReferenceResolver.resolve(
      operationDate: '2026-08-10',
      measuredTodayKg: null,
      history: [_point('2026-07-27', 80), _point('2026-08-09', 90)],
    );
    expect(result.valueKg, isNull);
    expect(result.source, DailyWeightReferenceSource.notAvailable);
  });
}

List<BodyHistoryDataPoint> _points(List<double> values) => [
  for (var index = 0; index < values.length; index++)
    _point('2026-08-${(8 - index).toString().padLeft(2, '0')}', values[index]),
];

BodyHistoryDataPoint _point(String date, double weight) => BodyHistoryDataPoint(
  operationDate: date,
  weightKg: weight,
  bodyFatPercent: null,
  source: BodyHistorySource.status,
);
