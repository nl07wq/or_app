import '../../repositories/app_repository_container.dart';
import '../../status/repositories/status_repository.dart';

class TrainingStatusWeightResolver {
  final StatusRepository _repository;

  TrainingStatusWeightResolver({StatusRepository? repository})
    : _repository = repository ?? AppRepositoryRegistry.container.status;

  Future<double?> resolve(String localDate) async {
    final status = await _repository.findByLocalDate(localDate);
    final weight = status?.weight;
    if (weight == null || !weight.isFinite || weight <= 0) {
      return null;
    }
    return weight;
  }
}
