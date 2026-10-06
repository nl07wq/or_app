import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/reminder_definition.dart';
import '../models/reminder_occurrence.dart';
import 'reminder_repository.dart';

class IndexedDbReminderRepository implements ReminderRepository {
  IndexedDbReminderRepository(this._database);
  final IndexedDbDatabase _database;
  @override
  Future<List<ReminderDefinition>> findDefinitions() async {
    try {
      final values = (await _database.findAll(
        IndexedDbStoreNames.reminderDefinitions,
      )).map(ReminderDefinition.fromRecord).toList();
      values.sort(
        (a, b) => a.startDate == b.startDate
            ? a.id.compareTo(b.id)
            : a.startDate.compareTo(b.startDate),
      );
      return List.unmodifiable(values);
    } catch (error) {
      throw RepositoryException(
        operation: 'reminder.definitions.read',
        cause: error,
      );
    }
  }

  @override
  Future<void> saveDefinition(ReminderDefinition definition) async {
    if (definition.title.trim().isEmpty)
      throw ArgumentError.value(definition.title, 'title');
    try {
      await _database.put(
        IndexedDbStoreNames.reminderDefinitions,
        definition.toRecord(),
      );
    } catch (error) {
      throw RepositoryException(
        operation: 'reminder.definition.save',
        cause: error,
      );
    }
  }

  @override
  Future<void> deleteDefinition(String id) =>
      _database.deleteById(IndexedDbStoreNames.reminderDefinitions, id);
  @override
  Future<List<ReminderOccurrenceState>> findStates() async {
    try {
      final values = (await _database.findAll(
        IndexedDbStoreNames.reminderOccurrenceStates,
      )).map(ReminderOccurrenceState.fromRecord).toList();
      values.sort((a, b) => a.id.compareTo(b.id));
      return List.unmodifiable(values);
    } catch (error) {
      throw RepositoryException(
        operation: 'reminder.states.read',
        cause: error,
      );
    }
  }

  @override
  Future<void> saveState(ReminderOccurrenceState state) async {
    try {
      await _database.put(
        IndexedDbStoreNames.reminderOccurrenceStates,
        state.toRecord(),
      );
    } catch (error) {
      throw RepositoryException(operation: 'reminder.state.save', cause: error);
    }
  }

  @override
  Future<void> deleteState(String id) =>
      _database.deleteById(IndexedDbStoreNames.reminderOccurrenceStates, id);
}
