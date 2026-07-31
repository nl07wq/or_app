import '../../repositories/app_repository_container.dart';
import '../models/operation_local_date.dart';
import '../repository/operation_state_repository.dart';

class OperationDateService {
  final OperationStateRepository? _repository;

  const OperationDateService([this._repository]);

  Future<OperationLocalDate> current() async {
    final repository =
        _repository ?? AppRepositoryRegistry.container.operationState;
    return (await repository.requireCurrent()).operationDate;
  }
}
