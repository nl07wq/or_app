import '../../body_history/models/body_history_models.dart';
import '../models/daily_assessment.dart';

abstract final class DailyWeightReferenceResolver {
  static DailyWeightReference resolve({
    required String operationDate,
    required double? measuredTodayKg,
    required Iterable<BodyHistoryDataPoint> history,
    double? previousFormalWeightKg,
  }) {
    if (measuredTodayKg != null &&
        measuredTodayKg.isFinite &&
        measuredTodayKg > 0) {
      return DailyWeightReference(
        valueKg: measuredTodayKg,
        source: DailyWeightReferenceSource.measuredToday,
        sampleCount: 1,
        windowDays: 1,
        previousFormalWeightKg: previousFormalWeightKg,
      );
    }
    final target = DateTime.parse(operationDate);
    DailyWeightReference? meanFor(int days, DailyWeightReferenceSource source) {
      final start = DateTime(target.year, target.month, target.day - days + 1);
      final values = [
        for (final point in history)
          if (DateTime.tryParse(point.operationDate) case final DateTime date)
            if (!date.isBefore(start) && !date.isAfter(target))
              if (point.weightKg case final double value)
                if (value.isFinite && value > 0) value,
      ];
      if (values.length < 3) return null;
      return DailyWeightReference(
        valueKg:
            values.fold<double>(0, (sum, value) => sum + value) / values.length,
        source: source,
        sampleCount: values.length,
        windowDays: days,
      );
    }

    return meanFor(7, DailyWeightReferenceSource.sevenDayMean) ??
        meanFor(14, DailyWeightReferenceSource.fourteenDayMean) ??
        const DailyWeightReference.notAvailable();
  }
}
