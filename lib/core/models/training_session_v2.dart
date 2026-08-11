import 'cardio_entry_v2.dart';
import 'training_exercise_v2.dart';

enum TrainingSessionGrade {
  sPlus('S+'),
  s('S'),
  sMinus('S-'),
  aPlus('A+'),
  a('A'),
  aMinus('A-'),
  bPlus('B+'),
  b('B'),
  bMinus('B-');

  final String displayLabel;

  const TrainingSessionGrade(this.displayLabel);

  String get stableId => name;

  static TrainingSessionGrade fromStableId(String stableId) {
    try {
      return values.byName(stableId);
    } on ArgumentError {
      throw FormatException('Unknown TRAINING sessionGrade: $stableId.');
    }
  }
}

class TrainingSessionV2 {
  static const strengthCalculationMethodId = 'strengthSessionMetsAcsmV1';
  static const strengthCalculationVersionValue = 1;
  static const strengthMets = 3.5;

  final String date;
  final String? startTime;
  final String? endTime;
  final String? sessionName;
  final TrainingSessionGrade? sessionGrade;
  final String? memo;
  final bool? dynamicStretchCompleted;
  final bool? cooldownStretchCompleted;
  final String? overallEvaluation;
  final double? estimatedStrengthCaloriesKcal;
  final double? strengthWeightSnapshotKg;
  final String? strengthCalculationMethod;
  final int? strengthCalculationVersion;
  final List<TrainingExerciseV2> exercises;
  final List<CardioEntryV2> cardioEntries;

  TrainingSessionV2({
    required String date,
    String? startTime,
    String? endTime,
    String? sessionName,
    this.sessionGrade,
    String? memo,
    this.dynamicStretchCompleted,
    this.cooldownStretchCompleted,
    String? overallEvaluation,
    this.estimatedStrengthCaloriesKcal,
    this.strengthWeightSnapshotKg,
    String? strengthCalculationMethod,
    this.strengthCalculationVersion,
    List<TrainingExerciseV2> exercises = const [],
    List<CardioEntryV2> cardioEntries = const [],
  }) : date = date.trim(),
       startTime = _normalizeOptional(startTime),
       endTime = _normalizeOptional(endTime),
       sessionName = _normalizeOptional(sessionName),
       memo = _normalizeOptional(memo),
       overallEvaluation = _normalizeOptional(overallEvaluation),
       strengthCalculationMethod = _normalizeOptional(
         strengthCalculationMethod,
       ),
       exercises = List.unmodifiable(exercises),
       cardioEntries = List.unmodifiable(cardioEntries) {
    _validate(allowLegacyUnknown: false);
  }

  TrainingSessionV2.forMigration({
    required String date,
    String? startTime,
    String? endTime,
    String? sessionName,
    this.sessionGrade,
    String? memo,
    this.dynamicStretchCompleted,
    this.cooldownStretchCompleted,
    String? overallEvaluation,
    this.estimatedStrengthCaloriesKcal,
    this.strengthWeightSnapshotKg,
    String? strengthCalculationMethod,
    this.strengthCalculationVersion,
    List<TrainingExerciseV2> exercises = const [],
    List<CardioEntryV2> cardioEntries = const [],
  }) : date = date.trim(),
       startTime = _normalizeOptional(startTime),
       endTime = _normalizeOptional(endTime),
       sessionName = _normalizeOptional(sessionName),
       memo = _normalizeOptional(memo),
       overallEvaluation = _normalizeOptional(overallEvaluation),
       strengthCalculationMethod = _normalizeOptional(
         strengthCalculationMethod,
       ),
       exercises = List.unmodifiable(exercises),
       cardioEntries = List.unmodifiable(cardioEntries) {
    _validate(allowLegacyUnknown: true);
  }

  bool get hasLegacyUnknown =>
      exercises.any((exercise) => exercise.hasLegacyUnknown) ||
      cardioEntries.any((entry) => entry.hasLegacyUnknown);

  Map<String, Object?> toJson() => {
    'date': date,
    'startTime': startTime,
    'endTime': endTime,
    'sessionName': sessionName,
    'sessionGrade': sessionGrade?.stableId,
    'memo': memo,
    'dynamicStretchCompleted': dynamicStretchCompleted,
    'cooldownStretchCompleted': cooldownStretchCompleted,
    'overallEvaluation': overallEvaluation,
    'estimatedStrengthCaloriesKcal': estimatedStrengthCaloriesKcal,
    'strengthWeightSnapshotKg': strengthWeightSnapshotKg,
    'strengthCalculationMethod': strengthCalculationMethod,
    'strengthCalculationVersion': strengthCalculationVersion,
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
    'cardioEntries': cardioEntries.map((entry) => entry.toJson()).toList(),
  };

  factory TrainingSessionV2.fromJson(Map<String, Object?> json) =>
      TrainingSessionV2._decode(json, allowLegacyUnknown: false);

  factory TrainingSessionV2.fromMigrationJson(Map<String, Object?> json) =>
      TrainingSessionV2._decode(json, allowLegacyUnknown: true);

  static TrainingSessionV2 _decode(
    Map<String, Object?> json, {
    required bool allowLegacyUnknown,
  }) {
    final date = json['date'];
    final startTime = json['startTime'];
    final endTime = json['endTime'];
    final sessionName = json['sessionName'];
    final grade = json['sessionGrade'];
    final memo = json['memo'];
    final dynamicStretch = json['dynamicStretchCompleted'];
    final cooldownStretch = json['cooldownStretchCompleted'];
    final overallEvaluation = json['overallEvaluation'];
    final estimatedStrengthCaloriesKcal = json['estimatedStrengthCaloriesKcal'];
    final strengthWeightSnapshotKg = json['strengthWeightSnapshotKg'];
    final strengthCalculationMethod = json['strengthCalculationMethod'];
    final strengthCalculationVersion = json['strengthCalculationVersion'];
    final exercises = json['exercises'];
    final cardioEntries = json['cardioEntries'];
    if (date is! String ||
        (startTime != null && startTime is! String) ||
        (endTime != null && endTime is! String) ||
        (sessionName != null && sessionName is! String) ||
        (grade != null && grade is! String) ||
        (memo != null && memo is! String) ||
        (dynamicStretch != null && dynamicStretch is! bool) ||
        (cooldownStretch != null && cooldownStretch is! bool) ||
        (overallEvaluation != null && overallEvaluation is! String) ||
        (estimatedStrengthCaloriesKcal != null &&
            estimatedStrengthCaloriesKcal is! num) ||
        (strengthWeightSnapshotKg != null &&
            strengthWeightSnapshotKg is! num) ||
        (strengthCalculationMethod != null &&
            strengthCalculationMethod is! String) ||
        (strengthCalculationVersion != null &&
            strengthCalculationVersion is! int) ||
        exercises is! List ||
        cardioEntries is! List) {
      throw const FormatException('Invalid TRAINING v2 session.');
    }
    final decodedExercises = exercises.map((value) {
      if (value is! Map) {
        throw const FormatException('Invalid TRAINING v2 exercise.');
      }
      final map = Map<String, Object?>.from(value);
      return allowLegacyUnknown
          ? TrainingExerciseV2.fromMigrationJson(map)
          : TrainingExerciseV2.fromJson(map);
    }).toList();
    final decodedCardio = cardioEntries.map((value) {
      if (value is! Map) {
        throw const FormatException('Invalid TRAINING v2 cardio entry.');
      }
      final map = Map<String, Object?>.from(value);
      return allowLegacyUnknown
          ? CardioEntryV2.fromMigrationJson(map)
          : CardioEntryV2.fromJson(map);
    }).toList();
    final decodedGrade = grade == null
        ? null
        : TrainingSessionGrade.fromStableId(grade as String);
    if (allowLegacyUnknown) {
      return TrainingSessionV2.forMigration(
        date: date,
        startTime: startTime as String?,
        endTime: endTime as String?,
        sessionName: sessionName as String?,
        sessionGrade: decodedGrade,
        memo: memo as String?,
        dynamicStretchCompleted: dynamicStretch as bool?,
        cooldownStretchCompleted: cooldownStretch as bool?,
        overallEvaluation: overallEvaluation as String?,
        estimatedStrengthCaloriesKcal: (estimatedStrengthCaloriesKcal as num?)
            ?.toDouble(),
        strengthWeightSnapshotKg: (strengthWeightSnapshotKg as num?)
            ?.toDouble(),
        strengthCalculationMethod: strengthCalculationMethod as String?,
        strengthCalculationVersion: strengthCalculationVersion as int?,
        exercises: decodedExercises,
        cardioEntries: decodedCardio,
      );
    }
    return TrainingSessionV2(
      date: date,
      startTime: startTime as String?,
      endTime: endTime as String?,
      sessionName: sessionName as String?,
      sessionGrade: decodedGrade,
      memo: memo as String?,
      dynamicStretchCompleted: dynamicStretch as bool?,
      cooldownStretchCompleted: cooldownStretch as bool?,
      overallEvaluation: overallEvaluation as String?,
      estimatedStrengthCaloriesKcal: (estimatedStrengthCaloriesKcal as num?)
          ?.toDouble(),
      strengthWeightSnapshotKg: (strengthWeightSnapshotKg as num?)?.toDouble(),
      strengthCalculationMethod: strengthCalculationMethod as String?,
      strengthCalculationVersion: strengthCalculationVersion as int?,
      exercises: decodedExercises,
      cardioEntries: decodedCardio,
    );
  }

  void _validate({required bool allowLegacyUnknown}) {
    if (date.length < 10 || DateTime.tryParse(date) == null) {
      throw ArgumentError.value(date, 'date', 'Invalid TRAINING session date.');
    }
    if (!allowLegacyUnknown && hasLegacyUnknown) {
      throw ArgumentError.value(
        this,
        'session',
        'legacyUnknown values are reserved for migration.',
      );
    }
    final start = _parseOffsetDateTime(startTime, 'startTime');
    final end = _parseOffsetDateTime(endTime, 'endTime');
    if (start != null && end != null) {
      if (!end.isAfter(start)) {
        throw ArgumentError.value(
          endTime,
          'endTime',
          'End Time must be after Start Time.',
        );
      }
      if (cardioDurationSeconds > end.difference(start).inSeconds) {
        throw ArgumentError.value(
          cardioEntries,
          'cardioEntries',
          'Cardio duration must not exceed Session duration.',
        );
      }
    }
    _validateStrengthSnapshot(start: start, end: end);
    final orders = <int>{};
    if (exercises.any((exercise) => !orders.add(exercise.order))) {
      throw ArgumentError.value(
        exercises,
        'exercises',
        'Exercise order values must be unique within a session.',
      );
    }
  }

  int get cardioDurationSeconds =>
      cardioEntries.fold(0, (total, entry) => total + entry.durationSeconds);

  Duration? get sessionDuration {
    final start = _parseOffsetDateTime(startTime, 'startTime');
    final end = _parseOffsetDateTime(endTime, 'endTime');
    return start == null || end == null ? null : end.difference(start);
  }

  Duration? get strengthDuration {
    final total = sessionDuration;
    return total == null
        ? null
        : total - Duration(seconds: cardioDurationSeconds);
  }

  static String formatOffsetDateTime(DateTime value) {
    final local = value.toLocal();
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final absoluteMinutes = offset.inMinutes.abs();
    final offsetHours = absoluteMinutes ~/ 60;
    final offsetMinutes = absoluteMinutes % 60;
    String two(int value) => value.toString().padLeft(2, '0');
    String three(int value) => value.toString().padLeft(3, '0');
    return '${local.year.toString().padLeft(4, '0')}-'
        '${two(local.month)}-${two(local.day)}T${two(local.hour)}:'
        '${two(local.minute)}:${two(local.second)}.${three(local.millisecond)}'
        '$sign${two(offsetHours)}:${two(offsetMinutes)}';
  }

  void _validateStrengthSnapshot({DateTime? start, DateTime? end}) {
    final values = <Object?>[
      estimatedStrengthCaloriesKcal,
      strengthWeightSnapshotKg,
      strengthCalculationMethod,
      strengthCalculationVersion,
    ];
    final hasAny = values.any((value) => value != null);
    if (!hasAny) return;
    if (values.any((value) => value == null) || start == null || end == null) {
      throw ArgumentError.value(
        values,
        'strengthSnapshot',
        'Strength calories snapshot must be complete and timed.',
      );
    }
    final calories = estimatedStrengthCaloriesKcal!;
    final weight = strengthWeightSnapshotKg!;
    if (!calories.isFinite || calories < 0 || !weight.isFinite || weight <= 0) {
      throw ArgumentError.value(
        values,
        'strengthSnapshot',
        'Strength calories snapshot contains invalid values.',
      );
    }
    if (strengthCalculationMethod !=
            TrainingSessionV2.strengthCalculationMethodId ||
        strengthCalculationVersion !=
            TrainingSessionV2.strengthCalculationVersionValue) {
      throw ArgumentError.value(
        values,
        'strengthSnapshot',
        'Strength calories snapshot contract is invalid.',
      );
    }
    final strengthMinutes =
        (end.difference(start).inMilliseconds -
            cardioDurationSeconds * Duration.millisecondsPerSecond) /
        Duration.millisecondsPerMinute;
    final expected = strengthMets * 3.5 * weight / 200 * strengthMinutes;
    if ((expected - calories).abs() > 1e-9) {
      throw ArgumentError.value(
        calories,
        'estimatedStrengthCaloriesKcal',
        'Strength calories snapshot does not match its formal inputs.',
      );
    }
  }
}

DateTime? _parseOffsetDateTime(String? value, String fieldName) {
  if (value == null) return null;
  if (!RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$',
  ).hasMatch(value)) {
    throw ArgumentError.value(
      value,
      fieldName,
      'Expected an offset ISO-8601 datetime.',
    );
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw ArgumentError.value(value, fieldName, 'Invalid datetime.');
  }
  return parsed;
}

String? _normalizeOptional(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
