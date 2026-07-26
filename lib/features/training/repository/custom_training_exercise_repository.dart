import '../models/custom_training_exercise.dart';

abstract interface class CustomTrainingExerciseRepository {
  Future<CustomTrainingExercise> create(String name);

  Future<CustomTrainingExercise?> findById(String id);

  Future<List<CustomTrainingExercise>> findAll();

  Future<CustomTrainingExercise> updateById(String id, String name);

  Future<void> deleteById(String id);

  Future<void> clear();
}
