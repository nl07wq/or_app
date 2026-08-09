import '../../../core/models/morning_data.dart';

enum DailyAggregateSourceType { records, legacyDns }

class DailyAggregateV1 {
  final String operationDate;
  final double? weightKg;
  final double? bodyFatPercent;
  final int? sleepDurationMinutes;
  final int? sleepScore;
  final SleepType? sleepType;
  final int? plantarFasciitisLevel;
  final String? workStartTime;
  final String? workEndTime;
  final int? workBreakMinutes;
  final int? actualWorkMinutes;
  final double? intakeCaloriesKcal;
  final double? proteinG;
  final double? fatG;
  final double? carbsG;
  final double hydrationMl;
  final int? officialSteps;
  final int? measuredSteps;
  final bool trainingPerformed;
  final int? digestiveCount;
  final DailyAggregateSourceType sourceType;

  const DailyAggregateV1({
    required this.operationDate,
    required this.weightKg,
    required this.bodyFatPercent,
    required this.sleepDurationMinutes,
    required this.sleepScore,
    required this.sleepType,
    required this.plantarFasciitisLevel,
    required this.workStartTime,
    required this.workEndTime,
    required this.workBreakMinutes,
    required this.actualWorkMinutes,
    required this.intakeCaloriesKcal,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.hydrationMl,
    required this.officialSteps,
    required this.measuredSteps,
    required this.trainingPerformed,
    required this.digestiveCount,
    required this.sourceType,
  });

  Map<String, Object?> toJson() => {
    'operationDate': operationDate,
    'weightKg': weightKg,
    'bodyFatPercent': bodyFatPercent,
    'sleepDurationMinutes': sleepDurationMinutes,
    'sleepScore': sleepScore,
    'sleepType': sleepType?.name,
    'plantarFasciitisLevel': plantarFasciitisLevel,
    'workStartTime': workStartTime,
    'workEndTime': workEndTime,
    'workBreakMinutes': workBreakMinutes,
    'actualWorkMinutes': actualWorkMinutes,
    'intakeCaloriesKcal': intakeCaloriesKcal,
    'proteinG': proteinG,
    'fatG': fatG,
    'carbsG': carbsG,
    'hydrationMl': hydrationMl,
    'officialSteps': officialSteps,
    'measuredSteps': measuredSteps,
    'trainingPerformed': trainingPerformed,
    'digestiveCount': digestiveCount,
    'sourceType': sourceType.name,
  };

  factory DailyAggregateV1.fromJson(Map<String, Object?> json) {
    final sleepType = _enumName(json, 'sleepType');
    try {
      return DailyAggregateV1(
        operationDate: _string(json, 'operationDate'),
        weightKg: _double(json, 'weightKg'),
        bodyFatPercent: _double(json, 'bodyFatPercent'),
        sleepDurationMinutes: _int(json, 'sleepDurationMinutes'),
        sleepScore: _int(json, 'sleepScore'),
        sleepType: sleepType == null
            ? null
            : SleepType.values.byName(sleepType),
        plantarFasciitisLevel: _int(json, 'plantarFasciitisLevel'),
        workStartTime: _nullableString(json, 'workStartTime'),
        workEndTime: _nullableString(json, 'workEndTime'),
        workBreakMinutes: _int(json, 'workBreakMinutes'),
        actualWorkMinutes: _int(json, 'actualWorkMinutes'),
        intakeCaloriesKcal: _double(json, 'intakeCaloriesKcal'),
        proteinG: _double(json, 'proteinG'),
        fatG: _double(json, 'fatG'),
        carbsG: _double(json, 'carbsG'),
        hydrationMl: _requiredDouble(json, 'hydrationMl'),
        officialSteps: _int(json, 'officialSteps'),
        measuredSteps: _int(json, 'measuredSteps'),
        trainingPerformed: _bool(json, 'trainingPerformed'),
        digestiveCount: _int(json, 'digestiveCount'),
        sourceType: DailyAggregateSourceType.values.byName(
          _string(json, 'sourceType'),
        ),
      );
    } on ArgumentError catch (error) {
      throw FormatException('Invalid DailyAggregateV1: $error');
    }
  }

  static String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String) throw FormatException('Invalid $key.');
    return value;
  }

  static String? _nullableString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value != null && value is! String) {
      throw FormatException('Invalid $key.');
    }
    return value as String?;
  }

  static String? _enumName(Map<String, Object?> json, String key) =>
      _nullableString(json, key);

  static double? _double(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value != null && value is! num) {
      throw FormatException('Invalid $key.');
    }
    return (value as num?)?.toDouble();
  }

  static double _requiredDouble(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! num) throw FormatException('Invalid $key.');
    return value.toDouble();
  }

  static int? _int(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value != null && value is! int) {
      throw FormatException('Invalid $key.');
    }
    return value as int?;
  }

  static bool _bool(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! bool) throw FormatException('Invalid $key.');
    return value;
  }
}
