import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/daily_log_confirmation/migration/daily_log_confirmation_legacy_reader.dart';
import '../../features/daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import '../../features/daily_log_confirmation/models/daily_log_confirmation_lifecycle_projection.dart';
import '../../features/daily_log_confirmation/repository/daily_log_confirmation_repository.dart';
import '../../features/repositories/app_repository_container.dart';
import '../models/daily_log_confirmation.dart';
import '../services/persistence_access.dart';

class DailyLogConfirmationRepository {
  static const _key = 'daily_log_confirmations';

  static Future<void> save(DailyLogConfirmation confirmation) async {
    PersistenceAccess.requireWrite('confirmation.save');
    if (!PersistenceAccess.usesCompatibilityStorage) {
      return AppRepositoryRegistry.container.confirmation.save(confirmation);
    }
    final records = await _legacyGetAll()
      ..removeWhere((record) => _sameDate(record.date, confirmation.date))
      ..add(confirmation);
    await _legacyWrite(records);
  }

  static Future<DailyLogConfirmation?> findByDate(DateTime date) async {
    PersistenceAccess.requireReadable('confirmation.findByDate');
    if (PersistenceAccess.canReadIndexedDb) {
      final localDate = PersistedDailyLogConfirmationRecord.localDateFromDate(
        date,
      );
      return AppRepositoryRegistry.container.confirmation.findByLocalDate(
        localDate,
      );
    }
    for (final record in await getAll()) {
      if (_sameDate(record.date, date)) return record;
    }
    return null;
  }

  static Future<DailyLogConfirmationLifecycleProjection> getLifecycleProjection(
    DateTime date,
  ) async {
    PersistenceAccess.requireReadable('confirmation.getLifecycleProjection');
    if (PersistenceAccess.canReadIndexedDb) {
      final repository = AppRepositoryRegistry.container.confirmation;
      if (repository is! DailyLogConfirmationLifecycleStore) {
        throw StateError(
          'Daily Log Confirmation lifecycle repository is unavailable.',
        );
      }
      return (repository as DailyLogConfirmationLifecycleStore)
          .findLifecycleProjection(
            PersistedDailyLogConfirmationRecord.localDateFromDate(date),
          );
    }
    return await findByDate(date) == null
        ? const DailyLogConfirmationLifecycleProjection.notFinalized()
        : const DailyLogConfirmationLifecycleProjection.legacyFinalized();
  }

  static Future<List<DailyLogConfirmation>> getAll() async {
    PersistenceAccess.requireReadable('confirmation.getAll');
    if (PersistenceAccess.canReadIndexedDb) {
      return AppRepositoryRegistry.container.confirmation.findAll();
    }
    if (!PersistenceAccess.usesCompatibilityStorage) {
      final result = await DailyLogConfirmationLegacyReader().read();
      final records = result.validRecords.map((record) => record.data).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return List.unmodifiable(records);
    }
    return _legacyGetAll();
  }

  static Future<void> deleteByDate(DateTime date) async {
    PersistenceAccess.requireWrite('confirmation.deleteByDate');
    if (!PersistenceAccess.usesCompatibilityStorage) {
      return AppRepositoryRegistry.container.confirmation.deleteByLocalDate(
        PersistedDailyLogConfirmationRecord.localDateFromDate(date),
      );
    }
    final records = await _legacyGetAll()
      ..removeWhere((record) => _sameDate(record.date, date));
    await _legacyWrite(records);
  }

  static Future<List<DailyLogConfirmation>> _legacyGetAll() async {
    final preferences = await SharedPreferences.getInstance();
    try {
      final records = (preferences.getStringList(_key) ?? const [])
          .map((value) => DailyLogConfirmation.fromJson(jsonDecode(value)))
          .toList();
      records.sort((a, b) => b.date.compareTo(a.date));
      return records;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _legacyWrite(List<DailyLogConfirmation> records) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _key,
      records.map((record) => jsonEncode(record.toJson())).toList(),
    );
  }

  static bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
