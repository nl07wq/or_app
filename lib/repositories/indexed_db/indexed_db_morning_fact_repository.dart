import '../../data/indexed_db/indexed_db_database_contract.dart';
import '../../data/indexed_db/indexed_db_store_names.dart';
import '../../features/morning_fact/models/morning_fact.dart';
import '../../features/repositories/morning_fact_repository.dart';
import '../../features/repositories/repository_exception.dart';
import '../../features/repositories/repository_record.dart';

class IndexedDbMorningFactRepository implements MorningFactRepository {
  final IndexedDbDatabase _database;

  const IndexedDbMorningFactRepository(this._database);

  @override
  Future<List<RepositoryRecord<MorningFact>>> findAll() async {
    try {
      final records = await _database.findAll(IndexedDbStoreNames.morningFacts);
      return List.unmodifiable(records.map(_fromStoredRecord));
    } catch (error) {
      throw RepositoryException(operation: 'morningFact.findAll', cause: error);
    }
  }

  @override
  Future<RepositoryRecord<MorningFact>?> findById(String id) async {
    try {
      final record = await _database.findById(
        IndexedDbStoreNames.morningFacts,
        id,
      );
      return record == null ? null : _fromStoredRecord(record);
    } catch (error) {
      throw RepositoryException(
        operation: 'morningFact.findById',
        cause: error,
      );
    }
  }

  @override
  Future<void> save(RepositoryRecord<MorningFact> record) async {
    try {
      await _database.put(IndexedDbStoreNames.morningFacts, {
        'id': record.id,
        'data': _toMap(record.value),
      });
    } catch (error) {
      throw RepositoryException(operation: 'morningFact.save', cause: error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _database.deleteById(IndexedDbStoreNames.morningFacts, id);
    } catch (error) {
      throw RepositoryException(operation: 'morningFact.delete', cause: error);
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _database.clear(IndexedDbStoreNames.morningFacts);
    } catch (error) {
      throw RepositoryException(operation: 'morningFact.clear', cause: error);
    }
  }

  RepositoryRecord<MorningFact> _fromStoredRecord(Map<String, Object?> record) {
    final id = record['id'];
    final data = record['data'];
    if (id is! String || data is! Map) {
      throw const FormatException('Invalid MorningFact stored record.');
    }
    return RepositoryRecord(
      id: id,
      value: _fromMap(Map<String, Object?>.from(data)),
    );
  }

  Map<String, Object?> _toMap(MorningFact fact) {
    return {
      'date': fact.date?.toIso8601String(),
      'weight': fact.weight,
      'bodyFat': fact.bodyFat,
      'sleepDurationMicroseconds': fact.sleepDuration?.inMicroseconds,
      'sleepScore': fact.sleepScore,
      'footPain': fact.footPain,
      'condition': fact.condition,
      'bowel': fact.bowel,
      'hydration': fact.hydration,
      'workSchedule': fact.workSchedule,
    };
  }

  MorningFact _fromMap(Map<String, Object?> data) {
    final dateValue = data['date'];
    final sleepDurationValue = data['sleepDurationMicroseconds'];
    if (dateValue != null && dateValue is! String) {
      throw const FormatException('Invalid MorningFact date.');
    }
    if (sleepDurationValue != null && sleepDurationValue is! int) {
      throw const FormatException('Invalid MorningFact sleep duration.');
    }

    final dateText = dateValue as String?;
    final sleepDurationMicroseconds = sleepDurationValue as int?;
    final date = dateText == null ? null : DateTime.tryParse(dateText);
    if (dateValue != null && date == null) {
      throw const FormatException('Invalid MorningFact date.');
    }

    return MorningFact(
      date: date,
      weight: _optionalDouble(data, 'weight'),
      bodyFat: _optionalDouble(data, 'bodyFat'),
      sleepDuration: sleepDurationMicroseconds == null
          ? null
          : Duration(microseconds: sleepDurationMicroseconds),
      sleepScore: _optionalInt(data, 'sleepScore'),
      footPain: _optionalInt(data, 'footPain'),
      condition: _optionalInt(data, 'condition'),
      bowel: _optionalString(data, 'bowel'),
      hydration: _optionalDouble(data, 'hydration'),
      workSchedule: _optionalString(data, 'workSchedule'),
    );
  }

  double? _optionalDouble(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is! num) throw FormatException('Invalid MorningFact $key.');
    return value.toDouble();
  }

  int? _optionalInt(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is! int) throw FormatException('Invalid MorningFact $key.');
    return value;
  }

  String? _optionalString(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is! String) throw FormatException('Invalid MorningFact $key.');
    return value;
  }
}
