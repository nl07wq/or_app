import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/default_training_templates.dart';
import '../../../core/repositories/training_repository.dart';

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
    final preferences = await SharedPreferences.getInstance();
    final customExercises =
        preferences.getStringList(_customExercisesKey) ?? const <String>[];

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
        (first, second) => first.toLowerCase().compareTo(second.toLowerCase()),
      );

    return ExerciseCatalog(recent: recentByKey.values.toList(), all: all);
  }

  static Future<void> registerCustom(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

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

  static void _addUnique(Map<String, String> exercises, String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;
    exercises.putIfAbsent(trimmedName.toLowerCase(), () => trimmedName);
  }
}
