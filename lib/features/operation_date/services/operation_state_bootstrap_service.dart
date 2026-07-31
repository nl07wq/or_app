import '../../daily_log_confirmation/repository/daily_log_confirmation_repository.dart';
import '../models/operation_local_date.dart';
import '../models/operation_state.dart';
import '../repository/operation_state_repository.dart';

class OperationStateBootstrapResult {
  final OperationState state;
  final bool created;

  const OperationStateBootstrapResult({
    required this.state,
    required this.created,
  });

  bool get recoveryRequired => state.requiresRecovery;
}

class OperationStateBootstrapService {
  final OperationStateRepository _operationState;
  final DailyLogConfirmationStore _confirmations;
  final DateTime Function() _now;

  OperationStateBootstrapService(
    this._operationState,
    this._confirmations, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  Future<OperationStateBootstrapResult> bootstrap() async {
    final existing = await _operationState.findCurrent();
    if (existing != null) {
      final verified = await _operationState.validateCurrent();
      return OperationStateBootstrapResult(state: verified, created: false);
    }

    final confirmations = await _confirmations.findAll();
    final operationDate = confirmations.isEmpty
        ? OperationLocalDate.fromDateTime(_now())
        : confirmations
              .map((value) => OperationLocalDate.fromDateTime(value.date))
              .reduce(
                (first, second) => first.compareTo(second) > 0 ? first : second,
              )
              .addDays(1);
    await _operationState.createInitial(operationDate);
    final verified = await _operationState.validateCurrent();
    return OperationStateBootstrapResult(state: verified, created: true);
  }
}
