import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/repositories/app_repository_container.dart';
import '../../features/training/migration/training_legacy_reader.dart';
import '../../features/training/models/persisted_training_record.dart';
import '../../features/training/repository/training_record_id_generator.dart';
import '../../features/training/services/training_cardio_energy_service.dart';
import '../../features/training/services/training_status_weight_resolver.dart';
import '../models/training_session.dart';
import '../models/training_session_v2.dart';
import '../services/persistence_access.dart';

class TrainingRepository {
  static const _key = 'training_sessions';

  static Future<void> save(TrainingSession session) async {
    await saveNew(session);
  }

  static Future<TrainingRecord> saveNew(TrainingSession session) async {
    PersistenceAccess.requireWrite('training.saveNew');
    if (!PersistenceAccess.usesCompatibilityStorage) {
      return AppRepositoryRegistry.container.training.saveNew(session);
    }
    final records = await _legacyGetAll()
      ..add(session);
    await _legacyWrite(records);
    return TrainingRecord(
      id: _legacyId(session, records.length - 1),
      session: session,
    );
  }

  static Future<TrainingRecord> saveNewV2(TrainingSessionV2 session) async {
    PersistenceAccess.requireWrite('training.saveNewV2');
    if (!PersistenceAccess.canReadIndexedDb) {
      throw StateError('TRAINING v2 writes require IndexedDB.');
    }
    return AppRepositoryRegistry.container.training.saveNewV2(
      await _prepareV2(session),
    );
  }

  static Future<void> replaceForLocalDate(TrainingSession session) async {
    PersistenceAccess.requireWrite('training.replaceForLocalDate');
    if (!PersistenceAccess.usesCompatibilityStorage) {
      throw StateError('ID-based update is required for persistent TRAINING.');
    }
    final target = session.date.substring(0, 10);
    final records = await _legacyGetAll();
    final index = records.indexWhere(
      (record) => record.date.substring(0, 10) == target,
    );
    index == -1 ? records.add(session) : records[index] = session;
    await _legacyWrite(records);
  }

  static Future<TrainingRecord> updateById(
    String id,
    TrainingSession session,
  ) async {
    PersistenceAccess.requireWrite('training.updateById');
    if (!PersistenceAccess.usesCompatibilityStorage) {
      return AppRepositoryRegistry.container.training.updateById(id, session);
    }
    throw StateError('Legacy TRAINING does not support persistent IDs.');
  }

  static Future<TrainingRecord> updateV2ById(
    String id,
    TrainingSessionV2 session,
  ) async {
    PersistenceAccess.requireWrite('training.updateV2ById');
    if (!PersistenceAccess.canReadIndexedDb) {
      throw StateError('TRAINING v2 writes require IndexedDB.');
    }
    return AppRepositoryRegistry.container.training.updateV2ById(
      id,
      await _prepareV2(session),
    );
  }

  static Future<List<TrainingRecord>> getRecords() async {
    PersistenceAccess.requireReadable('training.getRecords');
    if (PersistenceAccess.canReadIndexedDb) {
      return AppRepositoryRegistry.container.training.findAll();
    }
    if (!PersistenceAccess.usesCompatibilityStorage) {
      final result = await TrainingLegacyReader().read();
      return List.unmodifiable([
        for (final record in result.validRecords)
          TrainingRecord(
            id: const TrainingLegacyIdGenerator().generate(
              sessionJson: record.decodedPayload,
              sourceIndex: record.sourceIndex,
              duplicateOrdinal: 0,
            ),
            session: record.data,
          ),
      ]);
    }
    final sessions = await _legacyGetAll();
    return List.unmodifiable([
      for (var index = 0; index < sessions.length; index++)
        TrainingRecord(
          id: _legacyId(sessions[index], index),
          session: sessions[index],
        ),
    ]);
  }

  static Future<List<TrainingRecordReadModel>> getReadModels() async {
    PersistenceAccess.requireReadable('training.getReadModels');
    if (PersistenceAccess.canReadIndexedDb) {
      return AppRepositoryRegistry.container.training.findAllRecords();
    }
    return List.unmodifiable(
      (await getRecords()).map((record) => record.readModel),
    );
  }

  static Future<List<TrainingSession>> getAll() async {
    PersistenceAccess.requireReadable('training.getAll');
    if (PersistenceAccess.canReadIndexedDb) {
      return AppRepositoryRegistry.container.training.findAllSessions();
    }
    final records = await getReadModels();
    return List.unmodifiable(
      records
          .where((record) => record.v1Data != null)
          .map((record) => PersistedTrainingRecord.copySession(record.v1Data!)),
    );
  }

  static Future<void> deleteById(String id) async {
    PersistenceAccess.requireWrite('training.deleteById');
    if (!PersistenceAccess.usesCompatibilityStorage) {
      return AppRepositoryRegistry.container.training.deleteById(id);
    }
    throw StateError('Legacy TRAINING does not support persistent IDs.');
  }

  static Future<void> remove(TrainingSession session) async {
    PersistenceAccess.requireWrite('training.remove');
    if (!PersistenceAccess.usesCompatibilityStorage) {
      throw StateError('ID-based delete is required for persistent TRAINING.');
    }
    final records = await _legacyGetAll()
      ..removeWhere(
        (record) => record.date == session.date && record.memo == session.memo,
      );
    await _legacyWrite(records);
  }

  static Future<void> clear() async {
    PersistenceAccess.requireWrite('training.clear');
    if (!PersistenceAccess.usesCompatibilityStorage) {
      return AppRepositoryRegistry.container.training.clear();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<List<TrainingSession>> _legacyGetAll() async {
    final prefs = await SharedPreferences.getInstance();
    final records = (prefs.getStringList(_key) ?? const [])
        .map((value) => TrainingSession.fromJson(jsonDecode(value)))
        .toList();
    records.sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  static Future<void> _legacyWrite(List<TrainingSession> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      records.map((record) => jsonEncode(record.toJson())).toList(),
    );
  }

  static String _legacyId(TrainingSession session, int sourceIndex) {
    return const TrainingLegacyIdGenerator().generate(
      sessionJson: session.toJson(),
      sourceIndex: sourceIndex,
      duplicateOrdinal: 0,
    );
  }

  static Future<TrainingSessionV2> _prepareV2(TrainingSessionV2 session) async {
    double? statusWeight;
    if (TrainingCardioEnergyService.requiresStatusWeight(session)) {
      final localDate = PersistedTrainingRecord.localDateFromV2Session(session);
      statusWeight = await TrainingStatusWeightResolver().resolve(localDate);
    }
    return TrainingCardioEnergyService.applyForSave(
      session: session,
      statusWeightKg: statusWeight,
    );
  }
}
