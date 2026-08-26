import '../../../core/engine/operation_engine.dart';
import '../../status/repositories/status_repository.dart';
import '../../training/repository/training_session_repository.dart';
import '../../training/services/training_energy_service.dart';
import '../../training/services/training_status_weight_resolver.dart';

class DailyEstimatedTotalBurnResult {
  const DailyEstimatedTotalBurnResult({
    required this.totalBurnKcal,
    required this.weight,
  });

  final double totalBurnKcal;
  final TrainingStatusWeightResolution weight;
}

class DailyEstimatedTotalBurnService {
  final StatusRepository _statusRepository;
  final TrainingSessionRepository _trainingRepository;
  final TrainingStatusWeightResolver _weightResolver;

  DailyEstimatedTotalBurnService({
    required StatusRepository statusRepository,
    required TrainingSessionRepository trainingRepository,
  }) : _statusRepository = statusRepository,
       _trainingRepository = trainingRepository,
       _weightResolver = TrainingStatusWeightResolver(
         repository: statusRepository,
       );

  Future<double?> calculate(String operationDate) async =>
      (await calculateWithSource(operationDate))?.totalBurnKcal;

  Future<DailyEstimatedTotalBurnResult?> calculateWithSource(
    String operationDate,
  ) async {
    final status = await _statusRepository.findByLocalDate(operationDate);
    if (status == null) return null;
    final weight = await _weightResolver.resolveWithSource(operationDate);
    if (weight == null) return null;
    final records = await _trainingRepository.findRecordsByLocalDate(
      operationDate,
    );
    final exercise = TrainingEnergyService.summarize(
      preferredRecords: records,
      localDate: operationDate,
    ).trainingEstimatedCaloriesKcal;
    if (exercise == null) return null;
    final base = const OperationEngine().estimateTDEEFromFacts(
      weightKg: weight.weightKg,
      workHours: status.workHours,
    );
    return DailyEstimatedTotalBurnResult(
      totalBurnKcal: base + exercise,
      weight: weight,
    );
  }
}
