import '../models/daily_finalize_result.dart';
import '../models/operation_state.dart';
import '../repository/operation_state_repository.dart';
import 'daily_finalize_coordinator.dart';

class DailyFinalizeRecoveryService {
  final OperationStateRepository _operationState;
  final DailyFinalizeCoordinator _coordinator;

  const DailyFinalizeRecoveryService(this._operationState, this._coordinator);

  Future<DailyFinalizeResult?> recoverIfRequired() async {
    final state = await _operationState.requireCurrent();
    if (state.phase == OperationPhase.open) return null;
    if (state.phase == OperationPhase.awaitingDebrief) {
      await _coordinator.validateAwaitingState(state);
      return null;
    }
    return _coordinator.recover();
  }
}
