import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/default_training_templates.dart';
import '../../../core/repositories/training_repository.dart';
import '../../../core/services/persistence_access.dart';
import '../../../core/state/app_initialization_state.dart';
import '../../repositories/app_repository_container.dart';
import '../migration/custom_training_exercise_legacy_reader.dart';
import '../models/custom_training_exercise.dart';
import '../repository/custom_training_exercise_id_generator.dart';
import 'exercise_name_localization.dart';

class ExerciseCatalog {
  final List<String> recent;
  final List<String> all;

  ExerciseCatalog({required List<String> recent, required List<String> all})
    : recent = List.unmodifiable(recent),
      all = List.unmodifiable(all);
}

class ExerciseCatalogService {
  ExerciseCatalogService._();

  static const _customExercisesKey = 'training_custom_exercises';
  static const _recentLimit = 5;

  static Future<ExerciseCatalog> load() async {
    final sessions = await TrainingRepository.getAll();
    final customExercises = await _loadCustomNames();

    final recentByKey = <String, String>{};
    for (final session in sessions) {
      for (final exercise in session.exercises) {
        _addUnique(recentByKey, exercise.exerciseName);
        if (recentByKey.length == _recentLimit) break;
      }
      if (recentByKey.length == _recentLimit) break;
    }

    final allByKey = <String, String>{};
    for (final template in defaultTrainingTemplates) {
      for (final exercise in template.exercises) {
        _addUnique(allByKey, exercise);
      }
    }
    for (final exercise in recentByKey.values) {
      _addUnique(allByKey, exercise);
    }
    for (final exercise in customExercises) {
      _addUnique(allByKey, exercise);
    }

    final all = allByKey.values.toList()
      ..sort(
        (first, second) =>
            exerciseDisplayName(first).compareTo(exerciseDisplayName(second)),
      );

    return ExerciseCatalog(recent: recentByKey.values.toList(), all: all);
  }

  static Future<void> registerCustom(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    if (!PersistenceAccess.usesCompatibilityStorage) {
      PersistenceAccess.requireWrite('exerciseCatalog.registerCustom');
      final repository =
          AppRepositoryRegistry.container.customTrainingExercises;
      final normalizedName = exerciseIdentityKey(trimmedName);
      final existing = await repository.findAll();
      if (existing.any(
        (record) => exerciseIdentityKey(record.name) == normalizedName,
      )) {
        return;
      }
      await repository.create(trimmedName);
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    final customByKey = <String, String>{};
    for (final exercise
        in preferences.getStringList(_customExercisesKey) ?? const <String>[]) {
      _addUnique(customByKey, exercise);
    }
    _addUnique(customByKey, trimmedName);

    final customExercises = customByKey.values.toList()
      ..sort(
        (first, second) => first.toLowerCase().compareTo(second.toLowerCase()),
      );
    await preferences.setStringList(_customExercisesKey, customExercises);
  }

  static Future<List<CustomTrainingExercise>> loadCustomRecords() async {
    PersistenceAccess.requireReadable('exerciseCatalog.loadCustomRecords');
    if (PersistenceAccess.canReadIndexedDb) {
      return AppRepositoryRegistry.container.customTrainingExercises.findAll();
    }
    final legacy = await CustomTrainingExerciseLegacyReader().read();
    final recordsByName = <String, CustomTrainingExercise>{};
    for (final record in legacy.validRecords) {
      recordsByName.putIfAbsent(
        exerciseIdentityKey(record.name),
        () => CustomTrainingExercise(
          id: const CustomTrainingExerciseLegacyIdGenerator().generate(
            record.name,
          ),
          name: record.name,
        ),
      );
    }
    final records = recordsByName.values.toList()
      ..sort(
        (first, second) => exerciseDisplayName(
          first.name,
        ).compareTo(exerciseDisplayName(second.name)),
      );
    return List.unmodifiable(records);
  }

  static Future<CustomTrainingExercise> updateCustomById(
    String id,
    String name,
  ) {
    PersistenceAccess.requireWrite('exerciseCatalog.updateCustomById');
    return AppRepositoryRegistry.container.customTrainingExercises.updateById(
      id,
      name,
    );
  }

  static Future<void> deleteCustomById(String id) {
    PersistenceAccess.requireWrite('exerciseCatalog.deleteCustomById');
    return AppRepositoryRegistry.container.customTrainingExercises.deleteById(
      id,
    );
  }

  static Future<List<String>> _loadCustomNames() async {
    if (PersistenceAccess.usesCompatibilityStorage) {
      final preferences = await SharedPreferences.getInstance();
      return List.unmodifiable(
        preferences.getStringList(_customExercisesKey) ?? const <String>[],
      );
    }
    PersistenceAccess.requireReadable('exerciseCatalog.load');
    if (PersistenceAccess.canReadIndexedDb) {
      final records = await AppRepositoryRegistry
          .container
          .customTrainingExercises
          .findAll();
      return List.unmodifiable(records.map((record) => record.name));
    }
    if (AppRepositoryRegistry.controller.value.mode ==
        PersistenceMode.legacyReadOnly) {
      final legacy = await CustomTrainingExerciseLegacyReader().read();
      return List.unmodifiable(
        legacy.validRecords.map((record) => record.name),
      );
    }
    throw StateError('Custom Training Exercise persistence is unavailable.');
  }

  static void _addUnique(Map<String, String> exercises, String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;
    exercises.putIfAbsent(exerciseIdentityKey(trimmedName), () => trimmedName);
  }
}
