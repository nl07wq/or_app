import 'package:flutter/material.dart';

import '../../../core/models/cardio_entry.dart';
import '../../../core/models/cardio_entry_v2.dart';
import '../../../core/models/training_equipment_snapshot.dart';
import '../../../core/models/training_exercise_v2.dart';
import '../../../core/models/training_session_v2.dart';
import '../../../core/models/training_set_v2.dart';

class TrainingTimeValidationException implements Exception {
  final String message;

  const TrainingTimeValidationException(this.message);

  @override
  String toString() => message;
}

class TrainingV2FormController {
  final String date;
  String? startTime;
  String? endTime;
  final String? initialStartTime;
  final String? initialEndTime;
  final int initialCardioDurationSeconds;
  double? estimatedStrengthCaloriesKcal;
  double? strengthWeightSnapshotKg;
  String? strengthCalculationMethod;
  int? strengthCalculationVersion;
  final sessionName = TextEditingController();
  final sessionMemo = TextEditingController();
  final overallEvaluation = TextEditingController();
  TrainingSessionGrade? sessionGrade;
  bool? dynamicStretchCompleted;
  bool? cooldownStretchCompleted;
  final List<TrainingV2ExerciseFormController> exercises;
  final List<TrainingV2CardioFormController> cardioEntries;
  String? planExchangeId;
  String? planSourceDigest;
  String? planSourceRecordId;
  String? planSourceOperationDate;
  String? planNote;

  bool get hasPlan => planExchangeId != null;

  TrainingV2FormController.newSession({DateTime? now, String? localDate})
    : assert(now == null || localDate == null),
      date = localDate == null
          ? (now ?? DateTime.now()).toIso8601String()
          : '${localDate}T00:00:00.000',
      initialStartTime = null,
      initialEndTime = null,
      initialCardioDurationSeconds = 0,
      exercises = [TrainingV2ExerciseFormController()],
      cardioEntries = [];

  TrainingV2FormController.fromSession(TrainingSessionV2 session)
    : date = session.date,
      startTime = session.startTime,
      endTime = session.endTime,
      initialStartTime = session.startTime,
      initialEndTime = session.endTime,
      initialCardioDurationSeconds = session.cardioDurationSeconds,
      estimatedStrengthCaloriesKcal = session.estimatedStrengthCaloriesKcal,
      strengthWeightSnapshotKg = session.strengthWeightSnapshotKg,
      strengthCalculationMethod = session.strengthCalculationMethod,
      strengthCalculationVersion = session.strengthCalculationVersion,
      exercises = session.exercises
          .map(TrainingV2ExerciseFormController.fromDomain)
          .toList(),
      cardioEntries = session.cardioEntries
          .map(TrainingV2CardioFormController.fromDomain)
          .toList() {
    sessionName.text = session.sessionName ?? '';
    sessionMemo.text = session.memo ?? '';
    overallEvaluation.text = session.overallEvaluation ?? '';
    sessionGrade = session.sessionGrade;
    dynamicStretchCompleted = session.dynamicStretchCompleted;
    cooldownStretchCompleted = session.cooldownStretchCompleted;
  }

  void addExercise() => exercises.add(TrainingV2ExerciseFormController());

  void startTraining(DateTime now) {
    startTime = TrainingSessionV2.formatOffsetDateTime(now);
    endTime = null;
    _clearStrengthSnapshot();
  }

  void endTraining(DateTime now) {
    if (startTime == null) return;
    endTime = TrainingSessionV2.formatOffsetDateTime(now);
    _clearStrengthSnapshot();
  }

  void undoEnd() {
    if (endTime == null) return;
    endTime = null;
    _clearStrengthSnapshot();
  }

  void restoreDraftTimes({String? startTime, String? endTime}) {
    if (startTime == null && endTime != null) {
      throw const TrainingTimeValidationException(
        'Start TimeなしでEnd Timeを復元できません。',
      );
    }
    TrainingSessionV2(date: date, startTime: startTime, endTime: endTime);
    this.startTime = startTime;
    this.endTime = endTime;
    _clearStrengthSnapshot();
  }

  Map<String, Object?> toDraftState() => {
    'sessionName': sessionName.text,
    'sessionMemo': sessionMemo.text,
    'overallEvaluation': overallEvaluation.text,
    'sessionGrade': sessionGrade?.stableId,
    'dynamicStretchCompleted': dynamicStretchCompleted,
    'cooldownStretchCompleted': cooldownStretchCompleted,
    'planMetadata': hasPlan
        ? {
            'exchangeId': planExchangeId,
            'sourceDigest': planSourceDigest,
            'sourceRecordId': planSourceRecordId,
            'sourceOperationDate': planSourceOperationDate,
            'note': planNote,
          }
        : null,
    'exercises': [
      for (final exercise in exercises)
        {
          'exerciseName': exercise.exerciseName.text,
          'equipment': exercise.equipment?.toJson(),
          'equipmentSelectionMade': exercise.equipmentSelectionMade,
          'evaluation': exercise.evaluation.text,
          'targetWeight': exercise.targetWeight.text,
          'targetReps': [for (final value in exercise.targetReps) value.text],
          'targetNotes': exercise.targetNotes.text,
          'planSlots': [
            for (final slot in exercise.planSlots) slot.toDraftState(),
          ],
          'sets': [
            for (final set in exercise.sets)
              {
                'planSlotIndex': set.planSlotIndex,
                'setType': set.setType.stableId,
                'weight': set.weight.text,
                'reps': set.reps.text,
                'rpe': set.rpe,
                'rest': set.rest.text,
                'plannedWeightKg': set.plannedWeightKg,
                'targetMinReps': set.targetMinReps,
                'targetMaxReps': set.targetMaxReps,
              },
          ],
        },
    ],
    'cardioEntries': [
      for (final cardio in cardioEntries)
        {
          'purpose': cardio.purpose?.name,
          'type': cardio.type?.name,
          'equipment': cardio.equipment?.toJson(),
          'duration': cardio.duration.text,
          'distance': cardio.distance.text,
          'mets': cardio.mets.text,
          'averageHeartRate': cardio.averageHeartRate.text,
          'maximumHeartRate': cardio.maximumHeartRate.text,
          'averageSpeed': cardio.averageSpeed.text,
          'notes': cardio.notes.text,
          'weightSnapshotKg': cardio.weightSnapshotKg,
          'estimatedCaloriesKcal': cardio.estimatedCaloriesKcal,
          'calculationMethod': cardio.calculationMethod,
          'calculationVersion': cardio.calculationVersion,
          'initialMets': cardio.initialMets,
          'initialDurationSeconds': cardio.initialDurationSeconds,
        },
    ],
  };

  void restoreDraftState(Map<String, Object?> state) {
    sessionName.text = _draftString(state, 'sessionName');
    sessionMemo.text = _draftString(state, 'sessionMemo');
    overallEvaluation.text = _draftString(state, 'overallEvaluation');
    sessionGrade = _draftEnum(
      TrainingSessionGrade.values,
      state['sessionGrade'],
      (value) => value.stableId,
    );
    dynamicStretchCompleted = _draftNullableBool(
      state,
      'dynamicStretchCompleted',
    );
    cooldownStretchCompleted = _draftNullableBool(
      state,
      'cooldownStretchCompleted',
    );
    final rawPlanMetadata = state['planMetadata'];
    if (rawPlanMetadata != null && rawPlanMetadata is! Map) {
      throw const FormatException(
        'Invalid Active Training Draft planMetadata.',
      );
    }
    final planMetadata = rawPlanMetadata == null
        ? null
        : Map<String, Object?>.from(rawPlanMetadata as Map);
    planExchangeId = planMetadata == null
        ? null
        : _draftNullableString(planMetadata, 'exchangeId');
    planSourceDigest = planMetadata == null
        ? null
        : _draftNullableString(planMetadata, 'sourceDigest');
    planSourceRecordId = planMetadata == null
        ? null
        : _draftNullableString(planMetadata, 'sourceRecordId');
    planSourceOperationDate = planMetadata == null
        ? null
        : _draftNullableString(planMetadata, 'sourceOperationDate');
    planNote = planMetadata == null
        ? null
        : _draftNullableString(planMetadata, 'note');
    final exerciseValues = _draftMaps(state, 'exercises');
    final cardioValues = _draftMaps(state, 'cardioEntries');
    for (final exercise in exercises) {
      exercise.dispose();
    }
    for (final cardio in cardioEntries) {
      cardio.dispose();
    }
    exercises
      ..clear()
      ..addAll(exerciseValues.map(_exerciseFromDraft));
    cardioEntries
      ..clear()
      ..addAll(cardioValues.map(_cardioFromDraft));
  }

  static TrainingV2ExerciseFormController _exerciseFromDraft(
    Map<String, Object?> value,
  ) {
    final exercise = TrainingV2ExerciseFormController();
    for (final set in exercise.sets) {
      set.dispose();
    }
    exercise.exerciseName.text = _draftString(value, 'exerciseName');
    exercise.equipment = _draftEquipment(value['equipment']);
    exercise.equipmentSelectionMade = _draftBool(
      value,
      'equipmentSelectionMade',
    );
    exercise.evaluation.text = _draftString(value, 'evaluation');
    exercise.targetWeight.text = _draftString(value, 'targetWeight');
    exercise.targetNotes.text = _draftString(value, 'targetNotes');
    exercise.targetReps.addAll(
      _draftStrings(
        value,
        'targetReps',
      ).map((text) => TextEditingController(text: text)),
    );
    final setValues = _draftMaps(value, 'sets');
    final restoredSets = [for (final set in setValues) _setFromDraft(set)];
    final rawPlanSlots = value['planSlots'];
    final planSlots = rawPlanSlots == null
        ? _legacyPlanSlots(restoredSets)
        : _draftMaps(value, 'planSlots')
              .map(TrainingV2PlannedSetSlot.fromDraftState)
              .toList(growable: false);
    final planSlotIndices = planSlots.map((slot) => slot.index).toSet();
    final executionSlotIndices = restoredSets
        .map((set) => set.planSlotIndex)
        .whereType<int>()
        .toList(growable: false);
    if (planSlotIndices.length != planSlots.length ||
        executionSlotIndices.toSet().length != executionSlotIndices.length ||
        executionSlotIndices.any((index) => !planSlotIndices.contains(index))) {
      throw const FormatException(
        'Invalid Active Training Draft plan slot linkage.',
      );
    }
    exercise.sets
      ..clear()
      ..addAll(restoredSets);
    exercise._planSlots
      ..clear()
      ..addAll(planSlots);
    return exercise;
  }

  static List<TrainingV2PlannedSetSlot> _legacyPlanSlots(
    List<TrainingV2SetFormController> sets,
  ) {
    final slots = <TrainingV2PlannedSetSlot>[];
    for (final (index, set) in sets.indexed) {
      if (set.plannedWeightKg == null &&
          set.targetMinReps == null &&
          set.targetMaxReps == null) {
        continue;
      }
      set.planSlotIndex = index;
      slots.add(TrainingV2PlannedSetSlot.fromExecution(index, set));
    }
    return slots;
  }

  static TrainingV2SetFormController _setFromDraft(Map<String, Object?> value) {
    final set = TrainingV2SetFormController(
      setType: TrainingSetType.fromStableId(_draftString(value, 'setType')),
      rest: _draftString(value, 'rest'),
    );
    set.weight.text = _draftString(value, 'weight');
    set.reps.text = _draftString(value, 'reps');
    final rpe = value['rpe'];
    if (rpe != null && rpe is! int) {
      throw const FormatException('Invalid Active Training Draft RPE.');
    }
    set.rpe = rpe as int?;
    set.planSlotIndex = _draftNullableInt(value, 'planSlotIndex');
    set.plannedWeightKg = _draftNullableDouble(value, 'plannedWeightKg');
    set.targetMinReps = _draftNullableInt(value, 'targetMinReps');
    set.targetMaxReps = _draftNullableInt(value, 'targetMaxReps');
    return set;
  }

  static TrainingV2CardioFormController _cardioFromDraft(
    Map<String, Object?> value,
  ) {
    final cardio = TrainingV2CardioFormController();
    cardio.purpose = _draftNamedEnum(CardioPurpose.values, value['purpose']);
    cardio.type = _draftNamedEnum(CardioType.values, value['type']);
    cardio.equipment = _draftEquipment(value['equipment']);
    cardio.duration.text = _draftString(value, 'duration');
    cardio.distance.text = _draftString(value, 'distance');
    cardio.mets.text = _draftString(value, 'mets');
    cardio.averageHeartRate.text = _draftString(value, 'averageHeartRate');
    cardio.maximumHeartRate.text = _draftString(value, 'maximumHeartRate');
    cardio.averageSpeed.text = _draftString(value, 'averageSpeed');
    cardio.notes.text = _draftString(value, 'notes');
    cardio.weightSnapshotKg = _draftNullableDouble(value, 'weightSnapshotKg');
    cardio.estimatedCaloriesKcal = _draftNullableDouble(
      value,
      'estimatedCaloriesKcal',
    );
    cardio.calculationMethod = _draftNullableString(value, 'calculationMethod');
    cardio.calculationVersion = _draftNullableInt(value, 'calculationVersion');
    cardio.initialMets = _draftNullableDouble(value, 'initialMets');
    cardio.initialDurationSeconds = _draftNullableInt(
      value,
      'initialDurationSeconds',
    );
    return cardio;
  }

  void editStartTime(TimeOfDay value, {required DateTime now}) {
    final currentStart = startTime;
    if (currentStart == null) return;
    final candidate = _replaceTime(currentStart, value);
    final candidateInstant = DateTime.parse(candidate);
    final currentEnd = endTime;
    if (currentEnd == null && candidateInstant.isAfter(now)) {
      throw const TrainingTimeValidationException(
        'Start Timeは現在時刻より未来に設定できません。',
      );
    }
    if (currentEnd != null &&
        !DateTime.parse(currentEnd).isAfter(candidateInstant)) {
      throw const TrainingTimeValidationException(
        'Start TimeはEnd Timeより前に設定してください。',
      );
    }
    startTime = candidate;
    _clearStrengthSnapshot();
  }

  void editEndTime(TimeOfDay value) {
    final currentStart = startTime;
    final currentEnd = endTime;
    if (currentStart == null || currentEnd == null) return;
    final candidate = _replaceTime(currentEnd, value);
    final startInstant = DateTime.parse(currentStart);
    final endInstant = DateTime.parse(candidate);
    if (!endInstant.isAfter(startInstant)) {
      throw const TrainingTimeValidationException(
        'End TimeはStart Timeより後に設定してください。',
      );
    }
    final cardioDuration = _validCardioDurationSeconds();
    if (cardioDuration != null &&
        cardioDuration > endInstant.difference(startInstant).inSeconds) {
      throw const TrainingTimeValidationException(
        'Session DurationはCardio Duration合計以上にしてください。',
      );
    }
    endTime = candidate;
    _clearStrengthSnapshot();
  }

  void _clearStrengthSnapshot() {
    estimatedStrengthCaloriesKcal = null;
    strengthWeightSnapshotKg = null;
    strengthCalculationMethod = null;
    strengthCalculationVersion = null;
  }

  int? _validCardioDurationSeconds() {
    var total = 0;
    for (final cardio in cardioEntries) {
      final duration = _tryParseDurationSeconds(cardio.duration.text);
      if (duration == null) return null;
      total += duration;
    }
    return total;
  }

  void removeExercise(TrainingV2ExerciseFormController value) {
    value.dispose();
    exercises.remove(value);
  }

  void addCardio() => cardioEntries.add(TrainingV2CardioFormController());

  void removeCardio(TrainingV2CardioFormController value) {
    value.dispose();
    cardioEntries.remove(value);
  }

  void dispose() {
    sessionName.dispose();
    sessionMemo.dispose();
    overallEvaluation.dispose();
    for (final exercise in exercises) {
      exercise.dispose();
    }
    for (final cardio in cardioEntries) {
      cardio.dispose();
    }
  }
}

String _replaceTime(String source, TimeOfDay value) {
  final match = RegExp(
    r'^(\d{4}-\d{2}-\d{2})T\d{2}:\d{2}:\d{2}(?:\.\d+)?(Z|[+-]\d{2}:\d{2})$',
  ).firstMatch(source);
  if (match == null) {
    throw const TrainingTimeValidationException('Formal Timeを読み取れませんでした。');
  }
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${match.group(1)}T$hour:$minute:00.000${match.group(2)}';
}

int? _tryParseDurationSeconds(String source) {
  final parts = source.trim().split(':');
  if (parts.length != 2 && parts.length != 3) return null;
  final values = parts.map(int.tryParse).toList(growable: false);
  if (values.any((value) => value == null || value < 0)) return null;
  final hours = parts.length == 3 ? values[0]! : 0;
  final minutes = parts.length == 3 ? values[1]! : values[0]!;
  final seconds = parts.length == 3 ? values[2]! : values[1]!;
  if (seconds > 59 || parts.length == 3 && minutes > 59) return null;
  return hours * 3600 + minutes * 60 + seconds;
}

class TrainingV2ExerciseFormController {
  final exerciseName = TextEditingController();
  TrainingEquipmentSnapshot? equipment;
  bool equipmentSelectionMade;
  final List<TrainingV2SetFormController> sets;
  final List<TrainingV2PlannedSetSlot> _planSlots;
  List<TrainingV2PlannedSetSlot> get planSlots => List.unmodifiable(_planSlots);
  final evaluation = TextEditingController();
  final targetWeight = TextEditingController();
  final List<TextEditingController> targetReps;
  final targetNotes = TextEditingController();

  TrainingV2ExerciseFormController({
    Iterable<TrainingV2PlannedSetSlot> planSlots = const [],
  }) : equipmentSelectionMade = false,
       sets = [TrainingV2SetFormController()],
       _planSlots = List.of(planSlots),
       targetReps = [];

  TrainingV2ExerciseFormController.fromDomain(TrainingExerciseV2 exercise)
    : equipment = exercise.equipment,
      equipmentSelectionMade = true,
      sets = exercise.sets.map(TrainingV2SetFormController.fromDomain).toList(),
      _planSlots = [],
      targetReps =
          exercise.nextTarget?.targetReps
              .map((value) => TextEditingController(text: '$value'))
              .toList() ??
          [] {
    exerciseName.text = exercise.exerciseName;
    evaluation.text = exercise.evaluation ?? '';
    targetWeight.text = _number(exercise.nextTarget?.targetWeightKg);
    targetNotes.text = exercise.nextTarget?.notes ?? '';
  }

  void addSet() {
    final representedSlots = {
      for (final set in sets)
        if (set.planSlotIndex != null) set.planSlotIndex!,
    };
    final missingSlots =
        _planSlots
            .where((slot) => !representedSlots.contains(slot.index))
            .toList(growable: false)
          ..sort((a, b) => a.index.compareTo(b.index));
    if (missingSlots.isNotEmpty) {
      final slot = missingSlots.first;
      final restored = slot.createExecution();
      final insertionIndex = sets.indexWhere(
        (set) => set.planSlotIndex == null || set.planSlotIndex! > slot.index,
      );
      if (insertionIndex == -1) {
        sets.add(restored);
      } else {
        sets.insert(insertionIndex, restored);
      }
      return;
    }
    final previous = sets.lastOrNull;
    sets.add(
      TrainingV2SetFormController(
        setType: previous?.setType ?? TrainingSetType.main,
        rest: previous?.rest.text,
      ),
    );
  }

  void removeSet(TrainingV2SetFormController value) {
    if (!sets.remove(value)) return;
    value.dispose();
  }

  void addTargetRep() => targetReps.add(TextEditingController());

  void removeTargetRep(TextEditingController value) {
    value.dispose();
    targetReps.remove(value);
  }

  void dispose() {
    exerciseName.dispose();
    evaluation.dispose();
    targetWeight.dispose();
    targetNotes.dispose();
    for (final set in sets) {
      set.dispose();
    }
    for (final reps in targetReps) {
      reps.dispose();
    }
  }
}

class TrainingV2SetFormController {
  int? planSlotIndex;
  TrainingSetType setType;
  final weight = TextEditingController();
  final reps = TextEditingController();
  int? rpe;
  final rest = TextEditingController();
  double? plannedWeightKg;
  int? targetMinReps;
  int? targetMaxReps;

  TrainingV2SetFormController({
    this.setType = TrainingSetType.main,
    String? rest,
  }) {
    this.rest.text = rest ?? '';
  }

  TrainingV2SetFormController.fromDomain(TrainingSetV2 set)
    : setType = set.setType {
    weight.text = _number(set.weightKg);
    reps.text = '${set.reps}';
    rpe = set.rpe;
    rest.text = set.restAfterSeconds?.toString() ?? '';
  }

  void dispose() {
    weight.dispose();
    reps.dispose();
    rest.dispose();
  }
}

class TrainingV2PlannedSetSlot {
  final int index;
  final TrainingSetType setType;
  final double? plannedWeightKg;
  final int? targetMinReps;
  final int? targetMaxReps;
  final int? restAfterSeconds;

  const TrainingV2PlannedSetSlot({
    required this.index,
    required this.setType,
    required this.plannedWeightKg,
    required this.targetMinReps,
    required this.targetMaxReps,
    required this.restAfterSeconds,
  });

  factory TrainingV2PlannedSetSlot.fromExecution(
    int index,
    TrainingV2SetFormController set,
  ) => TrainingV2PlannedSetSlot(
    index: index,
    setType: set.setType,
    plannedWeightKg: set.plannedWeightKg,
    targetMinReps: set.targetMinReps,
    targetMaxReps: set.targetMaxReps,
    restAfterSeconds: int.tryParse(set.rest.text.trim()),
  );

  factory TrainingV2PlannedSetSlot.fromDraftState(Map<String, Object?> value) {
    final index = value['index'];
    if (index is! int || index < 0) {
      throw const FormatException('Invalid Active Training Draft plan slot.');
    }
    return TrainingV2PlannedSetSlot(
      index: index,
      setType: TrainingSetType.fromStableId(_draftString(value, 'setType')),
      plannedWeightKg: _draftNullableDouble(value, 'plannedWeightKg'),
      targetMinReps: _draftNullableInt(value, 'targetMinReps'),
      targetMaxReps: _draftNullableInt(value, 'targetMaxReps'),
      restAfterSeconds: _draftNullableInt(value, 'restAfterSeconds'),
    );
  }

  Map<String, Object?> toDraftState() => {
    'index': index,
    'setType': setType.stableId,
    'plannedWeightKg': plannedWeightKg,
    'targetMinReps': targetMinReps,
    'targetMaxReps': targetMaxReps,
    'restAfterSeconds': restAfterSeconds,
  };

  TrainingV2SetFormController createExecution() {
    final set =
        TrainingV2SetFormController(
            setType: setType,
            rest: restAfterSeconds?.toString(),
          )
          ..planSlotIndex = index
          ..plannedWeightKg = plannedWeightKg
          ..targetMinReps = targetMinReps
          ..targetMaxReps = targetMaxReps;
    set.weight.text = _number(plannedWeightKg);
    set.reps.text = targetMinReps?.toString() ?? '';
    return set;
  }
}

class TrainingV2CardioFormController {
  CardioPurpose? purpose;
  CardioType? type;
  TrainingEquipmentSnapshot? equipment;
  final duration = TextEditingController();
  final distance = TextEditingController();
  final mets = TextEditingController();
  final averageHeartRate = TextEditingController();
  final maximumHeartRate = TextEditingController();
  final averageSpeed = TextEditingController();
  final notes = TextEditingController();
  double? weightSnapshotKg;
  double? estimatedCaloriesKcal;
  String? calculationMethod;
  int? calculationVersion;
  double? initialMets;
  int? initialDurationSeconds;

  TrainingV2CardioFormController();

  TrainingV2CardioFormController.fromDomain(CardioEntryV2 entry)
    : purpose = entry.purpose,
      type = entry.type,
      equipment = entry.equipment,
      weightSnapshotKg = entry.weightSnapshotKg,
      estimatedCaloriesKcal = entry.estimatedCaloriesKcal,
      calculationMethod = entry.calculationMethod,
      calculationVersion = entry.calculationVersion,
      initialMets = entry.mets,
      initialDurationSeconds = entry.durationSeconds {
    duration.text = _duration(entry.durationSeconds);
    distance.text = _number(entry.distanceKm);
    mets.text = _number(entry.mets);
    averageHeartRate.text = entry.averageHeartRateBpm?.toString() ?? '';
    maximumHeartRate.text = entry.maximumHeartRateBpm?.toString() ?? '';
    averageSpeed.text = _number(entry.averageSpeedKmh);
    notes.text = entry.notes ?? '';
  }

  void dispose() {
    duration.dispose();
    distance.dispose();
    mets.dispose();
    averageHeartRate.dispose();
    maximumHeartRate.dispose();
    averageSpeed.dispose();
    notes.dispose();
  }
}

String _duration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainingSeconds = seconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
}

String _number(double? value) {
  if (value == null) return '';
  return value == value.roundToDouble()
      ? value.round().toString()
      : value.toString();
}

String _draftString(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result is! String) {
    throw FormatException('Invalid Active Training Draft $key.');
  }
  return result;
}

String? _draftNullableString(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result != null && result is! String) {
    throw FormatException('Invalid Active Training Draft $key.');
  }
  return result as String?;
}

bool _draftBool(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result is! bool) {
    throw FormatException('Invalid Active Training Draft $key.');
  }
  return result;
}

bool? _draftNullableBool(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result != null && result is! bool) {
    throw FormatException('Invalid Active Training Draft $key.');
  }
  return result as bool?;
}

int? _draftNullableInt(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result != null && result is! int) {
    throw FormatException('Invalid Active Training Draft $key.');
  }
  return result as int?;
}

double? _draftNullableDouble(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result != null && result is! num) {
    throw FormatException('Invalid Active Training Draft $key.');
  }
  return (result as num?)?.toDouble();
}

List<Map<String, Object?>> _draftMaps(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result is! List || result.any((entry) => entry is! Map)) {
    throw FormatException('Invalid Active Training Draft $key.');
  }
  return [for (final entry in result) Map<String, Object?>.from(entry as Map)];
}

List<String> _draftStrings(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result is! List || result.any((entry) => entry is! String)) {
    throw FormatException('Invalid Active Training Draft $key.');
  }
  return result.cast<String>();
}

T? _draftEnum<T>(
  Iterable<T> values,
  Object? raw,
  String Function(T value) stableId,
) {
  if (raw == null) return null;
  if (raw is! String) {
    throw const FormatException('Invalid Active Training Draft enum.');
  }
  return values.firstWhere(
    (value) => stableId(value) == raw,
    orElse: () =>
        throw const FormatException('Unknown Active Training Draft enum.'),
  );
}

T? _draftNamedEnum<T extends Enum>(Iterable<T> values, Object? raw) =>
    _draftEnum(values, raw, (value) => value.name);

TrainingEquipmentSnapshot? _draftEquipment(Object? raw) {
  if (raw == null) return null;
  if (raw is! Map) {
    throw const FormatException('Invalid Active Training Draft equipment.');
  }
  return TrainingEquipmentSnapshot.fromJson(Map<String, Object?>.from(raw));
}
