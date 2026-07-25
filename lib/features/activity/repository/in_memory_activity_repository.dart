import '../../../core/models/activity_data.dart';
import 'activity_repository.dart';

class InMemoryActivityRepository implements ActivityRepository {
  final Map<String, ActivityData> _records = {};

  @override
  Future<void> save(ActivityData data) async {
    _records.removeWhere(
      (id, record) => id != data.id && _isSameDate(record.date, data.date),
    );
    _records[data.id] = _copy(data);
  }

  @override
  Future<ActivityData?> findById(String id) async {
    final record = _records[id];
    return record == null ? null : _copy(record);
  }

  @override
  Future<ActivityData?> findByDate(DateTime date) async {
    for (final record in _records.values) {
      if (_isSameDate(record.date, date)) return _copy(record);
    }
    return null;
  }

  @override
  Future<List<ActivityData>> findAll() async {
    final records = _records.values.map(_copy).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(records);
  }

  @override
  Future<List<ActivityData>> getAll() => findAll();

  @override
  Future<void> delete(String id) async {
    _records.remove(id);
  }

  @override
  Future<void> deleteByDate(DateTime date) async {
    _records.removeWhere((_, record) => _isSameDate(record.date, date));
  }

  @override
  Future<void> clear() async {
    _records.clear();
  }

  ActivityData _copy(ActivityData data) =>
      ActivityData.fromJson(Map<String, dynamic>.from(data.toJson()));

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
