import '../models/activity_draft.dart';

abstract interface class ActivityDraftRepository {
  Future<void> save(ActivityDraft draft);

  Future<ActivityDraft?> findById(String id);

  Future<ActivityDraft?> findByDate(DateTime date);

  Future<List<ActivityDraft>> findAll();

  Future<void> deleteById(String id);

  Future<void> deleteByDate(DateTime date);

  Future<void> clear();
}
