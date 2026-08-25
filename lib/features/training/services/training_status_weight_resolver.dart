import '../../repositories/app_repository_container.dart';
import '../../status/repositories/status_repository.dart';
import '../../status/services/status_latest_valid_values_resolver.dart';

enum TrainingStatusWeightSource { measuredToday, latestRecordedFallback }

class TrainingStatusWeightResolution {
  const TrainingStatusWeightResolution({
    required this.weightKg,
    required this.source,
    required this.sourceLocalDate,
  });

  final double weightKg;
  final TrainingStatusWeightSource source;
  final String sourceLocalDate;
}

class TrainingStatusWeightResolver {
  final StatusRepository _repository;

  TrainingStatusWeightResolver({StatusRepository? repository})
    : _repository = repository ?? AppRepositoryRegistry.container.status;

  Future<TrainingStatusWeightResolution?> resolveWithSource(
    String localDate,
  ) async {
    final status = await _repository.findByLocalDate(localDate);
    final weight = status?.weight;
    if (weight != null && weight.isFinite && weight > 0) {
      return TrainingStatusWeightResolution(
        weightKg: weight,
        source: TrainingStatusWeightSource.measuredToday,
        sourceLocalDate: localDate,
      );
    }
    final history = await _repository.findAllCanonical();
    if (history.hasIssues) return null;
    final resolved = StatusLatestValidValuesResolver.resolve(
      history.values,
      beforeOrOnLocalDate: localDate,
    ).weight;
    if (resolved == null || resolved.localDate == localDate) return null;
    return TrainingStatusWeightResolution(
      weightKg: resolved.value,
      source: TrainingStatusWeightSource.latestRecordedFallback,
      sourceLocalDate: resolved.localDate,
    );
  }

  Future<double?> resolve(String localDate) async =>
      (await resolveWithSource(localDate))?.weightKg;
}
