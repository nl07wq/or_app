import '../models/morning_fact.dart';

abstract class MorningRepository {
  Future<MorningFact?> load();

  Future<void> save(MorningFact fact);

  Future<void> delete();
}
