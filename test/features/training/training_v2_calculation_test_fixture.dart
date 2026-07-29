import 'package:or_app/core/models/cardio_entry.dart';
import 'package:or_app/core/models/cardio_entry_v2.dart';
import 'package:or_app/core/models/training_equipment_snapshot.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/features/training/models/training_record_read_model.dart';

TrainingSetV2 v2Set({
  required int setNo,
  required TrainingSetType type,
  required double weight,
  required int reps,
  int? rpe,
  int? rest,
}) {
  if (type == TrainingSetType.legacyUnknown) {
    return TrainingSetV2.forMigration(
      setNo: setNo,
      setType: type,
      weightKg: weight,
      reps: reps,
      rpe: rpe,
      restAfterSeconds: rest,
    );
  }
  return TrainingSetV2(
    setNo: setNo,
    setType: type,
    weightKg: weight,
    reps: reps,
    rpe: rpe,
    restAfterSeconds: rest,
  );
}

TrainingExerciseV2 v2Exercise({
  String name = 'Bench Press',
  String? equipmentId = 'power_rack',
  String? equipmentName = 'Power Rack',
  int order = 1,
  List<TrainingSetV2> sets = const [],
  TrainingNextTarget? nextTarget,
}) {
  final equipment = equipmentName == null
      ? null
      : TrainingEquipmentSnapshot(catalogId: equipmentId, name: equipmentName);
  if (sets.any((set) => set.setType == TrainingSetType.legacyUnknown)) {
    return TrainingExerciseV2.forMigration(
      exerciseName: name,
      order: order,
      equipment: equipment,
      sets: sets,
      nextTarget: nextTarget,
    );
  }
  return TrainingExerciseV2(
    exerciseName: name,
    order: order,
    equipment: equipment,
    sets: sets,
    nextTarget: nextTarget,
  );
}

TrainingRecordReadModel v2Record({
  required String id,
  required DateTime createdAt,
  String localDate = '2026-07-30',
  List<TrainingExerciseV2> exercises = const [],
  List<CardioEntryV2> cardioEntries = const [],
  String? sessionName,
  TrainingSessionGrade? grade,
}) {
  final hasLegacy =
      exercises.any((exercise) => exercise.hasLegacyUnknown) ||
      cardioEntries.any((entry) => entry.hasLegacyUnknown);
  final session = hasLegacy
      ? TrainingSessionV2.forMigration(
          date: '${localDate}T12:00:00',
          sessionName: sessionName,
          sessionGrade: grade,
          exercises: exercises,
          cardioEntries: cardioEntries,
        )
      : TrainingSessionV2(
          date: '${localDate}T12:00:00',
          sessionName: sessionName,
          sessionGrade: grade,
          exercises: exercises,
          cardioEntries: cardioEntries,
        );
  return TrainingRecordReadModel.v2(
    id: id,
    localDate: localDate,
    createdAt: createdAt,
    updatedAt: createdAt,
    data: session,
  );
}

TrainingRecordReadModel v1Record({
  required String id,
  required DateTime createdAt,
  String localDate = '2026-07-30',
  String memo = '',
  String exerciseName = 'Bench Press',
  String? equipmentId = 'power_rack',
  List<TrainingSet> sets = const [],
  int cardioCount = 0,
}) {
  return TrainingRecordReadModel.v1(
    id: id,
    localDate: localDate,
    createdAt: createdAt,
    updatedAt: createdAt,
    data: TrainingSession(
      date: '${localDate}T12:00:00',
      memo: memo,
      exercises: [
        TrainingExercise(
          exerciseName: exerciseName,
          order: 1,
          equipmentId: equipmentId,
          sets: sets,
        ),
      ],
      cardioEntries: [
        for (var index = 0; index < cardioCount; index++)
          CardioEntry(
            type: CardioType.walking,
            intensity: CardioIntensity.light,
            durationMinutes: 10,
          ),
      ],
    ),
  );
}
