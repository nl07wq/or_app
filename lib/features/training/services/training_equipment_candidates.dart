import '../../../core/models/training_equipment_snapshot.dart';
import '../models/training_record_read_model.dart';
import 'equipment_catalog.dart';
import 'exercise_equipment_mapping.dart';
import 'exercise_name_localization.dart';

class TrainingEquipmentCandidates {
  final List<TrainingEquipmentSnapshot> values;

  const TrainingEquipmentCandidates._(this.values);

  factory TrainingEquipmentCandidates.forExercise({
    required String exerciseName,
    required Iterable<TrainingRecordReadModel> preferredRecords,
  }) {
    final exerciseKey = exerciseIdentityKey(exerciseName);
    if (exerciseKey.isEmpty) {
      return const TrainingEquipmentCandidates._([]);
    }
    final candidates = <TrainingEquipmentSnapshot>[
      for (final equipment in compatibleEquipment(exerciseName))
        TrainingEquipmentSnapshot(
          catalogId: equipment.id,
          name: equipment.displayName,
        ),
    ];
    for (final record in preferredRecords) {
      final session = record.v2Data;
      if (session == null) continue;
      for (final exercise in session.exercises) {
        if (exerciseIdentityKey(exercise.exerciseName) != exerciseKey) {
          continue;
        }
        final equipment = exercise.equipment;
        if (equipment != null) candidates.add(equipment);
      }
    }
    return TrainingEquipmentCandidates._(_deduplicate(candidates));
  }

  factory TrainingEquipmentCandidates.forCardio(
    Iterable<TrainingRecordReadModel> preferredRecords,
  ) {
    final candidates = <TrainingEquipmentSnapshot>[
      for (final equipment in builtInEquipment)
        TrainingEquipmentSnapshot(
          catalogId: equipment.id,
          name: equipment.displayName,
        ),
    ];
    for (final record in preferredRecords) {
      final session = record.v2Data;
      if (session == null) continue;
      candidates.addAll(
        session.cardioEntries.map((entry) => entry.equipment).nonNulls,
      );
    }
    return TrainingEquipmentCandidates._(_deduplicate(candidates));
  }

  bool contains(TrainingEquipmentSnapshot value) {
    final identity = _identity(value);
    return values.any((candidate) => _identity(candidate) == identity);
  }

  static List<TrainingEquipmentSnapshot> _deduplicate(
    Iterable<TrainingEquipmentSnapshot> values,
  ) {
    final seen = <String>{};
    return List.unmodifiable(
      values.where((value) => seen.add(_identity(value))),
    );
  }

  static String _identity(TrainingEquipmentSnapshot value) {
    return canonicalEquipmentIdentityKey(
      catalogId: value.catalogId,
      name: value.name,
    );
  }
}

String trainingEquipmentDisplayLabel(TrainingEquipmentSnapshot value) {
  final catalog = equipmentById(
    canonicalEquipmentId(catalogId: value.catalogId, name: value.name),
  );
  return catalog == null ? value.name : equipmentDisplayNameJa(catalog);
}
