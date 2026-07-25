import '../morning_fact/models/morning_fact.dart';
import 'repository_record.dart';

abstract interface class MorningFactRepository {
  Future<List<RepositoryRecord<MorningFact>>> findAll();

  Future<RepositoryRecord<MorningFact>?> findById(String id);

  Future<void> save(RepositoryRecord<MorningFact> record);

  Future<void> delete(String id);

  Future<void> clear();
}
