import '../../data/indexed_db/indexed_db_database_contract.dart';
import '../../core/state/app_initialization_state.dart';
import '../activity/repository/activity_repository.dart';
import '../activity/repository/activity_draft_repository.dart';
import '../activity/repository/indexed_db_activity_draft_repository.dart';
import '../activity/repository/indexed_db_activity_repository.dart';
import '../daily_log_confirmation/repository/daily_log_confirmation_repository.dart';
import '../daily_log_confirmation/repository/indexed_db_daily_log_confirmation_repository.dart';
import '../food/repository/food_repository.dart';
import '../food/repository/food_catalog_repository.dart';
import '../food/repository/food_recipe_repository.dart';
import '../food/repository/daily_meal_v2_repository.dart';
import '../food/repository/indexed_db_food_catalog_repository.dart';
import '../food/repository/indexed_db_food_recipe_repository.dart';
import '../food/repository/indexed_db_daily_meal_v2_repository.dart';
import '../food/repository/indexed_db_food_repository.dart';
import '../food/services/food_mixed_read_service.dart';
import '../operation_date/repository/indexed_db_operation_state_repository.dart';
import '../operation_date/repository/operation_state_repository.dart';
import '../operation_sync/repository/indexed_db_operation_sync_history_repository.dart';
import '../operation_sync/repository/indexed_db_operation_sync_state_repository.dart';
import '../operation_sync/repository/operation_sync_history_repository.dart';
import '../operation_sync/repository/operation_sync_state_repository.dart';
import '../operation_sync/services/operation_sync_core_service.dart';
import '../operation_sync/services/operation_sync_production_registry.dart';
import '../operation_sync/services/operation_sync_validator.dart';
import '../operation_sync/services/operation_transfer_codec.dart';
import '../operation_sync/services/operation_transfer_export_service.dart';
import '../status/repositories/indexed_db_status_repository.dart';
import '../status/repositories/status_repository.dart';
import '../training/repository/indexed_db_training_repository.dart';
import '../training/repository/custom_training_exercise_repository.dart';
import '../training/repository/indexed_db_custom_training_exercise_repository.dart';
import '../training/repository/training_session_repository.dart';

class AppRepositoryContainer {
  final IndexedDbDatabase database;
  final StatusRepository status;
  final ActivityRepository activity;
  final ActivityDraftRepository activityDrafts;
  final FoodRepository food;
  final FoodCatalogRepository foodCatalog;
  final FoodRecipeRepository foodRecipes;
  final DailyMealV2Repository dailyMealsV2;
  final FoodMixedReadService foodMixedRead;
  final TrainingSessionRepository training;
  final CustomTrainingExerciseRepository customTrainingExercises;
  final DailyLogConfirmationStore confirmation;
  final OperationStateRepository operationState;
  final OperationSyncStateRepository operationSyncState;
  final OperationSyncHistoryRepository operationSyncHistory;
  final OperationTransferCodec operationTransferCodec;
  final OperationSyncCoreService operationSyncCore;
  final OperationTransferExportService operationTransferExport;

  AppRepositoryContainer._({
    required this.database,
    required this.status,
    required this.activity,
    required this.activityDrafts,
    required this.food,
    required this.foodCatalog,
    required this.foodRecipes,
    required this.dailyMealsV2,
    required this.foodMixedRead,
    required this.training,
    required this.customTrainingExercises,
    required this.confirmation,
    required this.operationState,
    required this.operationSyncState,
    required this.operationSyncHistory,
    required this.operationTransferCodec,
    required this.operationSyncCore,
    required this.operationTransferExport,
  });

  factory AppRepositoryContainer.indexedDb(IndexedDbDatabase database) {
    final food = IndexedDbFoodRepository(database);
    final dailyMealsV2 = IndexedDbDailyMealV2Repository(database);
    final operationSyncState = IndexedDbOperationSyncStateRepository(database);
    final operationSyncHistory = IndexedDbOperationSyncHistoryRepository(
      database,
    );
    const operationTransferCodec = OperationTransferCodec();
    final operationState = IndexedDbOperationStateRepository(database);
    final operationSyncRegistry = OperationSyncProductionRegistry.create(
      database,
    );
    final operationSyncCore = OperationSyncCoreService(
      codec: operationTransferCodec,
      validator: OperationSyncValidator(
        operationSyncRegistry,
        operationStateRepository: operationState,
      ),
      stateRepository: operationSyncState,
      historyRepository: operationSyncHistory,
      database: database,
    );
    return AppRepositoryContainer._(
      database: database,
      status: IndexedDbStatusRepository(database),
      activity: IndexedDbActivityRepository(database),
      activityDrafts: IndexedDbActivityDraftRepository(database),
      food: food,
      foodCatalog: IndexedDbFoodCatalogRepository(database),
      foodRecipes: IndexedDbFoodRecipeRepository(database),
      dailyMealsV2: dailyMealsV2,
      foodMixedRead: FoodMixedReadService(
        legacyRepository: food,
        v2Repository: dailyMealsV2,
      ),
      training: IndexedDbTrainingSessionRepository(database),
      customTrainingExercises: IndexedDbCustomTrainingExerciseRepository(
        database,
      ),
      confirmation: IndexedDbDailyLogConfirmationRepository(database),
      operationState: operationState,
      operationSyncState: operationSyncState,
      operationSyncHistory: operationSyncHistory,
      operationTransferCodec: operationTransferCodec,
      operationSyncCore: operationSyncCore,
      operationTransferExport: OperationTransferExportService(
        registry: operationSyncRegistry,
        operationStateRepository: operationState,
      ),
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
