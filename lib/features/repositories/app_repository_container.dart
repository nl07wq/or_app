import '../../data/indexed_db/indexed_db_database_contract.dart';
import '../../core/state/app_initialization_state.dart';
import '../activity/repository/activity_repository.dart';
import '../activity/repository/indexed_db_activity_repository.dart';
import '../daily_log_confirmation/repository/daily_log_confirmation_repository.dart';
import '../daily_log_confirmation/repository/indexed_db_daily_log_confirmation_repository.dart';
import '../food/repository/food_repository.dart';
import '../food/repository/indexed_db_food_repository.dart';
import '../status/repositories/indexed_db_status_repository.dart';
import '../status/repositories/status_repository.dart';
import '../training/repository/indexed_db_training_repository.dart';
import '../training/repository/custom_training_exercise_repository.dart';
import '../training/repository/indexed_db_custom_training_exercise_repository.dart';
import '../training/repository/training_session_repository.dart';

class AppRepositoryContainer {
  final StatusRepository status;
  final ActivityRepository activity;
  final FoodRepository food;
  final TrainingSessionRepository training;
  final CustomTrainingExerciseRepository customTrainingExercises;
  final DailyLogConfirmationStore confirmation;

  AppRepositoryContainer._({
    required this.status,
    required this.activity,
    required this.food,
    required this.training,
    required this.customTrainingExercises,
    required this.confirmation,
  });

  factory AppRepositoryContainer.indexedDb(IndexedDbDatabase database) {
    return AppRepositoryContainer._(
      status: IndexedDbStatusRepository(database),
      activity: IndexedDbActivityRepository(database),
      food: IndexedDbFoodRepository(database),
      training: IndexedDbTrainingSessionRepository(database),
      customTrainingExercises: IndexedDbCustomTrainingExerciseRepository(
        database,
      ),
      confirmation: IndexedDbDailyLogConfirmationRepository(database),
    );
  }
}

class AppRepositoryRegistry {
  AppRepositoryRegistry._();

  static AppRepositoryContainer? _container;
  static bool startupManaged = false;
  static AppInitializationController controller = appInitializationController;

  static AppRepositoryContainer get container {
    final value = _container;
    if (value == null) {
      throw StateError('Production repositories are not initialized.');
    }
    return value;
  }

  static bool get hasContainer => _container != null;

  static void beginStartup({AppInitializationController? controller}) {
    startupManaged = true;
    _container = null;
    AppRepositoryRegistry.controller =
        controller ?? appInitializationController;
  }

  static void install(AppRepositoryContainer container) {
    _container = container;
  }

  static void clear() {
    _container = null;
  }

  static void resetForTesting() {
    startupManaged = false;
    _container = null;
    controller = appInitializationController;
  }
}
