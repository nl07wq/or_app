import '../models/reminder_definition.dart';
import '../models/reminder_occurrence.dart';

abstract interface class ReminderRepository {
  Future<List<ReminderDefinition>> findDefinitions();
  Future<void> saveDefinition(ReminderDefinition definition);
  Future<void> deleteDefinition(String id);
  Future<List<ReminderOccurrenceState>> findStates();
  Future<void> saveState(ReminderOccurrenceState state);
  Future<void> deleteState(String id);
}
