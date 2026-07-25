import '../../data/indexed_db/indexed_db_database.dart';
import '../../repositories/indexed_db/indexed_db_morning_fact_repository.dart';
import '../../repositories/indexed_db/indexed_db_training_repository.dart';
import '../activity/repository/activity_repository.dart';
import '../activity/repository/in_memory_activity_repository.dart';
import 'memory/in_memory_morning_fact_repository.dart';
import 'memory/in_memory_training_repository.dart';
import 'morning_fact_repository.dart';
import 'repository_exception.dart';
import 'training_repository.dart';

class RepositoryProvider {
  final MorningFactRepository morningFactRepository;
  final TrainingRepository trainingRepository;
  final ActivityRepository activityRepository;

  RepositoryProvider.inMemory()
    : morningFactRepository = InMemoryMorningFactRepository(),
      trainingRepository = InMemoryTrainingRepository(),
      activityRepository = InMemoryActivityRepository();

  RepositoryProvider._({
    required this.morningFactRepository,
    required this.trainingRepository,
    required this.activityRepository,
  });

  static Future<RepositoryProvider> indexedDb() async {
    try {
      final database = await openIndexedDbDatabase();
      return RepositoryProvider._(
        morningFactRepository: IndexedDbMorningFactRepository(database),
        trainingRepository: IndexedDbTrainingRepository(database),
        activityRepository: InMemoryActivityRepository(),
      );
    } catch (error) {
      throw RepositoryException(operation: 'provider.indexedDb', cause: error);
    }
  }

  // TODO: Add Food, Activity, Mission, and Body repositories.
}
