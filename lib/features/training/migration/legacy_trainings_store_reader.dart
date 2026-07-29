import '../../../core/models/training_session.dart';
import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../models/persisted_training_record.dart';

class LegacyTrainingsStoreEntry {
  final String sourceId;
  final int sourceIndex;
  final Map<String, Object?> rawRecord;
  final TrainingSession session;

  const LegacyTrainingsStoreEntry({
    required this.sourceId,
    required this.sourceIndex,
    required this.rawRecord,
    required this.session,
  });
}

class InvalidLegacyTrainingsStoreEntry {
  final String sourceId;
  final int sourceIndex;
  final Map<String, Object?> rawRecord;
  final String errorCode;
  final String errorMessage;

  const InvalidLegacyTrainingsStoreEntry({
    required this.sourceId,
    required this.sourceIndex,
    required this.rawRecord,
    required this.errorCode,
    required this.errorMessage,
  });
}

class LegacyTrainingsStoreReadResult {
  final List<Map<String, Object?>> rawRecords;
  final List<LegacyTrainingsStoreEntry> validRecords;
  final List<InvalidLegacyTrainingsStoreEntry> invalidRecords;

  LegacyTrainingsStoreReadResult({
    required Iterable<Map<String, Object?>> rawRecords,
    required Iterable<LegacyTrainingsStoreEntry> validRecords,
    required Iterable<InvalidLegacyTrainingsStoreEntry> invalidRecords,
  }) : rawRecords = List.unmodifiable(rawRecords),
       validRecords = List.unmodifiable(validRecords),
       invalidRecords = List.unmodifiable(invalidRecords);
}

class LegacyTrainingsStoreReader {
  final IndexedDbDatabase _database;

  const LegacyTrainingsStoreReader(this._database);

  Future<LegacyTrainingsStoreReadResult> read() async {
    final values = await _database.findAll(IndexedDbStoreNames.trainings);
    values.sort((first, second) {
      return (first['id']?.toString() ?? '').compareTo(
        second['id']?.toString() ?? '',
      );
    });
    final valid = <LegacyTrainingsStoreEntry>[];
    final invalid = <InvalidLegacyTrainingsStoreEntry>[];
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      final rawId = value['id'];
      final sourceId = rawId is String && rawId.isNotEmpty
          ? rawId
          : 'invalid-source-$index';
      try {
        if (rawId is! String || rawId.isEmpty || value['data'] is! Map) {
          throw const FormatException(
            'Legacy trainings record requires id and data.',
          );
        }
        final session = TrainingSession.fromJson(
          Map<String, dynamic>.from(value['data']! as Map),
        );
        PersistedTrainingRecord.localDateFromSession(session);
        valid.add(
          LegacyTrainingsStoreEntry(
            sourceId: rawId,
            sourceIndex: index,
            rawRecord: _copyMap(value),
            session: session,
          ),
        );
      } catch (error) {
        invalid.add(
          InvalidLegacyTrainingsStoreEntry(
            sourceId: sourceId,
            sourceIndex: index,
            rawRecord: _copyMap(value),
            errorCode: 'invalidLegacyStoreRecord',
            errorMessage: error.toString(),
          ),
        );
      }
    }
    return LegacyTrainingsStoreReadResult(
      rawRecords: values.map(_copyMap),
      validRecords: valid,
      invalidRecords: invalid,
    );
  }

  static Map<String, Object?> _copyMap(Map source) => {
    for (final entry in source.entries)
      entry.key.toString(): _copyValue(entry.value),
  };

  static Object? _copyValue(Object? value) {
    if (value is Map) return _copyMap(value);
    if (value is Iterable) {
      return [for (final item in value) _copyValue(item)];
    }
    return value;
  }
}
