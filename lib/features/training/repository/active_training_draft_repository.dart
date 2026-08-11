import '../models/active_training_draft.dart';

abstract interface class ActiveTrainingDraftRepository {
  Future<void> save(ActiveTrainingDraft draft);

  Future<ActiveTrainingDraft?> findByOperationDate(String operationDate);

  Future<void> deleteByOperationDate(String operationDate);
}
