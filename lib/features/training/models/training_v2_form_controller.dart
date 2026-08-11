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
  final evaluation = TextEditingController();
  final targetWeight = TextEditingController();
  final List<TextEditingController> targetReps;
  final targetNotes = TextEditingController();

  TrainingV2ExerciseFormController()
    : equipmentSelectionMade = false,
      sets = [TrainingV2SetFormController()],
      targetReps = [];

  TrainingV2ExerciseFormController.fromDomain(TrainingExerciseV2 exercise)
    : equipment = exercise.equipment,
      equipmentSelectionMade = true,
      sets = exercise.sets.map(TrainingV2SetFormController.fromDomain).toList(),
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
    final previous = sets.lastOrNull;
    sets.add(
      TrainingV2SetFormController(
        setType: previous?.setType ?? TrainingSetType.main,
        rest: previous?.rest.text,
      ),
    );
  }

  void removeSet(TrainingV2SetFormController value) {
    if (sets.length == 1) return;
    value.dispose();
    sets.remove(value);
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
  TrainingSetType setType;
  final weight = TextEditingController();
  final reps = TextEditingController();
  int? rpe;
  final rest = TextEditingController();

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
