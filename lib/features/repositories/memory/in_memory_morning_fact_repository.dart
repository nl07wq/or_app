import '../../morning_fact/models/morning_fact.dart';
import '../morning_fact_repository.dart';
import '../repository_record.dart';

class InMemoryMorningFactRepository implements MorningFactRepository {
  final Map<String, RepositoryRecord<MorningFact>> _records = {};

  @override
  Future<List<RepositoryRecord<MorningFact>>> findAll() async {
    return List.unmodifiable(_records.values);
  }

  @override
  Future<RepositoryRecord<MorningFact>?> findById(String id) async {
    return _records[id];
  }

  @override
  Future<void> save(RepositoryRecord<MorningFact> record) async {
    _records[record.id] = record;
  }

  @override
  Future<void> delete(String id) async {
    _records.remove(id);
  }

  @override
  Future<void> clear() async {
    _records.clear();
  }
}
