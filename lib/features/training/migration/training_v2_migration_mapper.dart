import '../../../core/models/cardio_entry_v2.dart';
import '../../../core/models/training_equipment_snapshot.dart';
import '../../../core/models/training_exercise_v2.dart';
import '../../../core/models/training_session.dart';
import '../../../core/models/training_session_v2.dart';
import '../../../core/models/training_set_v2.dart';
import '../models/persisted_training_record.dart';
import '../services/equipment_catalog.dart';

class TrainingV2MappingException implements Exception {
  final String code;
  final String message;
  final bool needsReview;

  const TrainingV2MappingException(
    this.code,
    this.message, {
    this.needsReview = false,
  });

  @override
  String toString() => '$code: $message';
}

abstract final class TrainingV2MigrationMapper {
  static PersistedTrainingRecord map({
    required String targetId,
    required String localDate,
    required DateTime createdAt,
    required DateTime updatedAt,
    required TrainingMigrationSource migrationSource,
    required TrainingSession source,
  }) {
    try {
      final exercises = source.exercises.map((exercise) {
        final equipmentId = exercise.equipmentId;
        final catalog = equipmentById(equipmentId);
        if (equipmentId != null && catalog == null) {
          throw TrainingV2MappingException(
            'unknownEquipmentId',
            'Unknown TRAINING equipment ID: $equipmentId.',
            needsReview: true,
          );
        }
        return TrainingExerciseV2.forMigration(
          exerciseName: exercise.exerciseName,
          order: exercise.order,
          equipment: catalog == null
              ? null
              : TrainingEquipmentSnapshot(
                  catalogId: catalog.id,
                  name: catalog.displayName,
                ),
          sets: [
            for (final set in exercise.sets)
              TrainingSetV2.forMigration(
                setNo: set.setNo,
                setType: TrainingSetType.legacyUnknown,
                weightKg: set.weight,
                reps: set.reps,
              ),
          ],
        );
      }).toList();
      final cardio = source.cardioEntries
          .map(
            (entry) => CardioEntryV2.forMigration(
              purpose: CardioPurpose.legacyUnknown,
              type: entry.type,
              durationSeconds: entry.durationMinutes * 60,
              distanceKm: entry.distanceKm,
              notes: entry.notes,
              legacyIntensity: entry.intensity.name,
              legacyReferenceCaloriesKcal: entry.estimatedCalories,
            ),
          )
          .toList();
      return PersistedTrainingRecord.v2ForMigration(
        id: targetId,
        localDate: localDate,
        createdAt: createdAt,
        updatedAt: updatedAt,
        migrationSource: migrationSource,
        data: TrainingSessionV2.forMigration(
          date: source.date,
          memo: source.memo,
          exercises: exercises,
          cardioEntries: cardio,
        ),
      );
    } on TrainingV2MappingException {
      rethrow;
    } catch (error) {
      throw TrainingV2MappingException('invalidV2Mapping', error.toString());
    }
  }
}
