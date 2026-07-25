import 'memory/in_memory_morning_fact_repository.dart';
import 'memory/in_memory_training_repository.dart';
import 'morning_fact_repository.dart';
import 'training_repository.dart';

class RepositoryProvider {
  final MorningFactRepository morningFactRepository;
  final TrainingRepository trainingRepository;

  RepositoryProvider.inMemory()
    : morningFactRepository = InMemoryMorningFactRepository(),
      trainingRepository = InMemoryTrainingRepository();

  // TODO: Add Food, Activity, Mission, and Body repositories.
}
