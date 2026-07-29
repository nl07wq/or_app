import 'package:flutter/material.dart';

import '../../../core/models/cardio_entry.dart';
import '../../../core/models/cardio_entry_v2.dart';
import '../../../core/models/training_equipment_snapshot.dart';
import '../../../core/models/training_exercise_v2.dart';
import '../../../core/models/training_session_v2.dart';
import '../../../core/models/training_set_v2.dart';

class TrainingV2FormController {
  final String date;
  final sessionName = TextEditingController();
  final sessionMemo = TextEditingController();
  final overallEvaluation = TextEditingController();
  TrainingSessionGrade? sessionGrade;
  bool? dynamicStretchCompleted;
  bool? cooldownStretchCompleted;
  final List<TrainingV2ExerciseFormController> exercises;
  final List<TrainingV2CardioFormController> cardioEntries;

  TrainingV2FormController.newSession({DateTime? now})
    : date = (now ?? DateTime.now()).toIso8601String(),
      exercises = [TrainingV2ExerciseFormController()],
      cardioEntries = [];

  TrainingV2FormController.fromSession(TrainingSessionV2 session)
    : date = session.date,
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

class TrainingV2ExerciseFormController {
  final exerciseName = TextEditingController();
  TrainingEquipmentSnapshot? equipment;
  final List<TrainingV2SetFormController> sets;
  final evaluation = TextEditingController();
  final targetWeight = TextEditingController();
  final List<TextEditingController> targetReps;
  final targetNotes = TextEditingController();

  TrainingV2ExerciseFormController()
    : sets = [TrainingV2SetFormController()],
      targetReps = [];

  TrainingV2ExerciseFormController.fromDomain(TrainingExerciseV2 exercise)
    : equipment = exercise.equipment,
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
  final minutes = TextEditingController();
  final seconds = TextEditingController();
  final distance = TextEditingController();
  final mets = TextEditingController();
  final averageHeartRate = TextEditingController();
  final maximumHeartRate = TextEditingController();
  final averageSpeed = TextEditingController();
  final notes = TextEditingController();

  TrainingV2CardioFormController();

  TrainingV2CardioFormController.fromDomain(CardioEntryV2 entry)
    : purpose = entry.purpose,
      type = entry.type,
      equipment = entry.equipment {
    minutes.text = '${entry.durationSeconds ~/ 60}';
    seconds.text = '${entry.durationSeconds % 60}';
    distance.text = _number(entry.distanceKm);
    mets.text = _number(entry.mets);
    averageHeartRate.text = entry.averageHeartRateBpm?.toString() ?? '';
    maximumHeartRate.text = entry.maximumHeartRateBpm?.toString() ?? '';
    averageSpeed.text = _number(entry.averageSpeedKmh);
    notes.text = entry.notes ?? '';
  }

  void dispose() {
    minutes.dispose();
    seconds.dispose();
    distance.dispose();
    mets.dispose();
    averageHeartRate.dispose();
    maximumHeartRate.dispose();
    averageSpeed.dispose();
    notes.dispose();
  }
}

String _number(double? value) {
  if (value == null) return '';
  return value == value.roundToDouble()
      ? value.round().toString()
      : value.toString();
}
