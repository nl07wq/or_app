import '../../../core/engine/operation_engine.dart';
import '../../status/repositories/status_repository.dart';
import '../../training/repository/training_session_repository.dart';
import '../../training/services/training_energy_service.dart';

class RecentStatusWeightResolver {
  final StatusRepository _statusRepository;

  const RecentStatusWeightResolver(this._statusRepository);

  Future<double?> resolve({
    required String operationDate,
    required double? currentWeightKg,
  }) async {
    if (currentWeightKg != null) return currentWeightKg;
    final target = DateTime.parse(operationDate);
    final start = _format(DateTime(target.year, target.month, target.day - 7));
    final end = _format(DateTime(target.year, target.month, target.day - 1));
    final result = await _statusRepository.getRange(start, end);
    for (final record in result.records.reversed) {
      final weight = record.data.weight;
      if (weight != null) return weight;
    }
    return null;
  }

  static String _format(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class DailyEstimatedTotalBurnService {
  final StatusRepository _statusRepository;
  final TrainingSessionRepository _trainingRepository;
  final RecentStatusWeightResolver _weightResolver;

  DailyEstimatedTotalBurnService({
    required StatusRepository statusRepository,
    required TrainingSessionRepository trainingRepository,
  }) : _statusRepository = statusRepository,
       _trainingRepository = trainingRepository,
       _weightResolver = RecentStatusWeightResolver(statusRepository);

  Future<double?> calculate(String operationDate) async {
    final status = await _statusRepository.findByLocalDate(operationDate);
    if (status == null) return null;
    final weight = await _weightResolver.resolve(
      operationDate: operationDate,
      currentWeightKg: status.weight,
    );
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
      weightKg: weight,
      workHours: status.workHours,
    );
    return base + exercise;
  }
}
