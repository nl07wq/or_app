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
  final String date;
  final String? sessionName;
  final TrainingSessionGrade? sessionGrade;
  final String? memo;
  final bool? dynamicStretchCompleted;
  final bool? cooldownStretchCompleted;
  final String? overallEvaluation;
  final List<TrainingExerciseV2> exercises;
  final List<CardioEntryV2> cardioEntries;

  TrainingSessionV2({
    required String date,
    String? sessionName,
    this.sessionGrade,
    String? memo,
    this.dynamicStretchCompleted,
    this.cooldownStretchCompleted,
    String? overallEvaluation,
    List<TrainingExerciseV2> exercises = const [],
    List<CardioEntryV2> cardioEntries = const [],
  }) : date = date.trim(),
       sessionName = _normalizeOptional(sessionName),
       memo = _normalizeOptional(memo),
       overallEvaluation = _normalizeOptional(overallEvaluation),
       exercises = List.unmodifiable(exercises),
       cardioEntries = List.unmodifiable(cardioEntries) {
    _validate(allowLegacyUnknown: false);
  }

  TrainingSessionV2.forMigration({
    required String date,
    String? sessionName,
    this.sessionGrade,
    String? memo,
    this.dynamicStretchCompleted,
    this.cooldownStretchCompleted,
    String? overallEvaluation,
    List<TrainingExerciseV2> exercises = const [],
    List<CardioEntryV2> cardioEntries = const [],
  }) : date = date.trim(),
       sessionName = _normalizeOptional(sessionName),
       memo = _normalizeOptional(memo),
       overallEvaluation = _normalizeOptional(overallEvaluation),
       exercises = List.unmodifiable(exercises),
       cardioEntries = List.unmodifiable(cardioEntries) {
    _validate(allowLegacyUnknown: true);
  }

  bool get hasLegacyUnknown =>
      exercises.any((exercise) => exercise.hasLegacyUnknown) ||
      cardioEntries.any((entry) => entry.hasLegacyUnknown);

  Map<String, Object?> toJson() => {
    'date': date,
    'sessionName': sessionName,
    'sessionGrade': sessionGrade?.stableId,
    'memo': memo,
    'dynamicStretchCompleted': dynamicStretchCompleted,
    'cooldownStretchCompleted': cooldownStretchCompleted,
    'overallEvaluation': overallEvaluation,
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
    final sessionName = json['sessionName'];
    final grade = json['sessionGrade'];
    final memo = json['memo'];
    final dynamicStretch = json['dynamicStretchCompleted'];
    final cooldownStretch = json['cooldownStretchCompleted'];
    final overallEvaluation = json['overallEvaluation'];
    final exercises = json['exercises'];
    final cardioEntries = json['cardioEntries'];
    if (date is! String ||
        (sessionName != null && sessionName is! String) ||
        (grade != null && grade is! String) ||
        (memo != null && memo is! String) ||
        (dynamicStretch != null && dynamicStretch is! bool) ||
        (cooldownStretch != null && cooldownStretch is! bool) ||
        (overallEvaluation != null && overallEvaluation is! String) ||
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
        sessionName: sessionName as String?,
        sessionGrade: decodedGrade,
        memo: memo as String?,
        dynamicStretchCompleted: dynamicStretch as bool?,
        cooldownStretchCompleted: cooldownStretch as bool?,
        overallEvaluation: overallEvaluation as String?,
        exercises: decodedExercises,
        cardioEntries: decodedCardio,
      );
    }
    return TrainingSessionV2(
      date: date,
      sessionName: sessionName as String?,
      sessionGrade: decodedGrade,
      memo: memo as String?,
      dynamicStretchCompleted: dynamicStretch as bool?,
      cooldownStretchCompleted: cooldownStretch as bool?,
      overallEvaluation: overallEvaluation as String?,
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
    final orders = <int>{};
    if (exercises.any((exercise) => !orders.add(exercise.order))) {
      throw ArgumentError.value(
        exercises,
        'exercises',
        'Exercise order values must be unique within a session.',
      );
    }
  }
}

String? _normalizeOptional(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
