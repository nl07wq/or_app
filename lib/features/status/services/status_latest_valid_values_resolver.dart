import '../../../core/models/morning_data.dart';

class LatestStatusFieldValue<T> {
  const LatestStatusFieldValue({required this.value, required this.localDate});

  final T value;
  final String localDate;
}

class StatusLatestValidValues {
  const StatusLatestValidValues({
    required this.weight,
    required this.bodyFat,
    required this.sleepHours,
    required this.sleepScore,
  });

  final LatestStatusFieldValue<double>? weight;
  final LatestStatusFieldValue<double>? bodyFat;
  final LatestStatusFieldValue<double>? sleepHours;
  final LatestStatusFieldValue<int>? sleepScore;
}

abstract final class StatusLatestValidValuesResolver {
  static StatusLatestValidValues resolve(
    Iterable<MorningData> records, {
    String? beforeOrOnLocalDate,
  }) {
    final ordered = records.where((record) {
      final localDate = _localDate(record);
      return localDate != null &&
          (beforeOrOnLocalDate == null ||
              localDate.compareTo(beforeOrOnLocalDate) <= 0);
    }).toList()..sort((a, b) => b.date.compareTo(a.date));

    LatestStatusFieldValue<double>? weight;
    LatestStatusFieldValue<double>? bodyFat;
    LatestStatusFieldValue<double>? sleepHours;
    LatestStatusFieldValue<int>? sleepScore;
    for (final record in ordered) {
      final localDate = _localDate(record)!;
      final recordWeight = record.weight;
      if (weight == null &&
          recordWeight != null &&
          recordWeight.isFinite &&
          recordWeight > 0) {
        weight = LatestStatusFieldValue(
          value: recordWeight,
          localDate: localDate,
        );
      }
      final recordBodyFat = record.bodyFat;
      if (bodyFat == null &&
          recordBodyFat != null &&
          recordBodyFat.isFinite &&
          recordBodyFat >= 0) {
        bodyFat = LatestStatusFieldValue(
          value: recordBodyFat,
          localDate: localDate,
        );
      }
      final recordSleepHours = record.sleepHours;
      if (sleepHours == null &&
          recordSleepHours != null &&
          recordSleepHours.isFinite &&
          recordSleepHours >= 0 &&
          recordSleepHours < 24) {
        sleepHours = LatestStatusFieldValue(
          value: recordSleepHours,
          localDate: localDate,
        );
      }
      final recordSleepScore = record.sleepScore;
      if (sleepScore == null &&
          recordSleepScore != null &&
          recordSleepScore >= 0 &&
          recordSleepScore <= 100) {
        sleepScore = LatestStatusFieldValue(
          value: recordSleepScore,
          localDate: localDate,
        );
      }
      if (weight != null &&
          bodyFat != null &&
          sleepHours != null &&
          sleepScore != null) {
        break;
      }
    }
    return StatusLatestValidValues(
      weight: weight,
      bodyFat: bodyFat,
      sleepHours: sleepHours,
      sleepScore: sleepScore,
    );
  }

  static String? _localDate(MorningData record) {
    if (record.date.length < 10 || DateTime.tryParse(record.date) == null) {
      return null;
    }
    return record.date.substring(0, 10);
  }
}
