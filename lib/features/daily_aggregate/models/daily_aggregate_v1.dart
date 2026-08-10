import '../../../core/models/morning_data.dart';

enum DailyAggregateSourceType { records, legacyDns }

class DailyAggregateDigestiveEventV1 {
  final int amount;
  final int? shape;
  final int? relief;

  const DailyAggregateDigestiveEventV1({
    required this.amount,
    required this.shape,
    required this.relief,
  });

  Map<String, Object?> toJson() => {
    'amount': amount,
    'shape': shape,
    'relief': relief,
  };

  factory DailyAggregateDigestiveEventV1.fromJson(Map<String, Object?> json) {
    const fields = {'amount', 'shape', 'relief'};
    if (json.keys.toSet().difference(fields).isNotEmpty ||
        fields.difference(json.keys.toSet()).isNotEmpty) {
      throw const FormatException('Invalid digestive event fields.');
    }
    final amount = json['amount'];
    final shape = json['shape'];
    final relief = json['relief'];
    if (amount is! int || amount < 0 || amount > 3) {
      throw const FormatException('Invalid digestive event amount.');
    }
    if (shape != null && (shape is! int || shape < 1 || shape > 3)) {
      throw const FormatException('Invalid digestive event shape.');
    }
    if (relief != null && (relief is! int || relief < 0 || relief > 2)) {
      throw const FormatException('Invalid digestive event relief.');
    }
    if (amount == 0 && (shape != null || relief != null)) {
      throw const FormatException(
        'Digestive event shape and relief must be null when amount is zero.',
      );
    }
    return DailyAggregateDigestiveEventV1(
      amount: amount,
      shape: shape as int?,
      relief: relief as int?,
    );
  }
}

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
  final double? estimatedExpenditureKcal;
  final double? estimatedCalorieBalanceKcal;
  final double? proteinG;
  final double? fatG;
  final double? carbsG;
  final double? hydrationMl;
  final int? officialSteps;
  final int? measuredSteps;
  final bool? trainingPerformed;
  final int? digestiveCount;
  final List<DailyAggregateDigestiveEventV1> digestiveEvents;
  final String? operationStatus;
  final List<String> conditionFactSummary;
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
    this.estimatedExpenditureKcal,
    this.estimatedCalorieBalanceKcal,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.hydrationMl,
    required this.officialSteps,
    required this.measuredSteps,
    required this.trainingPerformed,
    required this.digestiveCount,
    this.digestiveEvents = const [],
    this.operationStatus,
    this.conditionFactSummary = const [],
    required this.sourceType,
  });

  Map<String, Object?> toJson() {
    final value = <String, Object?>{
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
    if (estimatedExpenditureKcal != null) {
      value['estimatedExpenditureKcal'] = estimatedExpenditureKcal;
    }
    if (estimatedCalorieBalanceKcal != null) {
      value['estimatedCalorieBalanceKcal'] = estimatedCalorieBalanceKcal;
    }
    if (digestiveEvents.isNotEmpty) {
      value['digestiveEvents'] = [
        for (final event in digestiveEvents) event.toJson(),
      ];
    }
    if (operationStatus != null) value['operationStatus'] = operationStatus;
    if (conditionFactSummary.isNotEmpty) {
      value['conditionFactSummary'] = conditionFactSummary;
    }
    return value;
  }

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
        estimatedExpenditureKcal: _double(json, 'estimatedExpenditureKcal'),
        estimatedCalorieBalanceKcal: _double(
          json,
          'estimatedCalorieBalanceKcal',
        ),
        proteinG: _double(json, 'proteinG'),
        fatG: _double(json, 'fatG'),
        carbsG: _double(json, 'carbsG'),
        hydrationMl: _double(json, 'hydrationMl'),
        officialSteps: _int(json, 'officialSteps'),
        measuredSteps: _int(json, 'measuredSteps'),
        trainingPerformed: _nullableBool(json, 'trainingPerformed'),
        digestiveCount: _int(json, 'digestiveCount'),
        digestiveEvents: _digestiveEvents(json),
        operationStatus: _operationStatus(json),
        conditionFactSummary: _stringList(json, 'conditionFactSummary'),
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

  static int? _int(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value != null && value is! int) {
      throw FormatException('Invalid $key.');
    }
    return value as int?;
  }

  static bool? _nullableBool(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value != null && value is! bool) {
      throw FormatException('Invalid $key.');
    }
    return value as bool?;
  }

  static List<DailyAggregateDigestiveEventV1> _digestiveEvents(
    Map<String, Object?> json,
  ) {
    final value = json['digestiveEvents'];
    if (value == null) return const [];
    if (value is! List) throw const FormatException('Invalid digestiveEvents.');
    return List.unmodifiable(
      value.map((item) {
        if (item is! Map) {
          throw const FormatException('Invalid digestiveEvents item.');
        }
        return DailyAggregateDigestiveEventV1.fromJson(
          Map<String, Object?>.from(item),
        );
      }),
    );
  }

  static String? _operationStatus(Map<String, Object?> json) {
    final value = _nullableString(json, 'operationStatus');
    if (value != null && !const {'GREEN', 'YELLOW', 'RED'}.contains(value)) {
      throw const FormatException('Invalid operationStatus.');
    }
    return value;
  }

  static List<String> _stringList(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return const [];
    if (value is! List ||
        value.any((item) => item is! String || item.trim().isEmpty)) {
      throw FormatException('Invalid $key.');
    }
    return List.unmodifiable(value.cast<String>());
  }
}
