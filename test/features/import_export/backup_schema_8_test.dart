import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_database_contract.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/import_export/services/backup_import_service.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/system/models/profile_model.dart';
import 'package:or_app/features/system/repository/indexed_db_profile_repository.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  final timestamp = DateTime.utc(2026, 8, 3, 12);

  test(
    'Current schema exports and restores Profile in the formal transaction',
    () async {
      final database = FakeIndexedDbDatabase();
      database.seed(
        IndexedDbStoreNames.operationState,
        'current',
        OperationState(
          operationDate: OperationLocalDate.parse('2026-08-03'),
          createdAt: timestamp,
          updatedAt: timestamp,
        ).toRecord(),
      );
      final repository = IndexedDbProfileRepository(
        database,
        clock: () => timestamp,
      );
      await repository.save(
        ProfileModel.validated(
          userName: 'Kazuma',
          heightCm: 175.5,
          gender: ProfileGender.male,
          nationality: '日本',
        ),
      );
      final controller = AppInitializationController()..markReady();
      final package = await BackupExportService(
        database: database,
        controller: controller,
        clock: () => timestamp,
      ).create();

      expect(package.schemaVersion, BackupPackage.currentSchemaVersion);
      expect(package.data.keys, BackupSections.schema14);
      expect(package.data[BackupSections.profile], [
        {
          'version': 1,
          'userName': 'Kazuma',
          'heightCm': 175.5,
          'gender': 'male',
          'nationality': '日本',
        },
      ]);
      expect(
        package.includedSections,
        hasLength(BackupSections.schema14.length),
      );

      await repository.save(ProfileModel.validated(userName: 'Changed'));
      final service = BackupImportService(
        database: database,
        controller: controller,
        restore: () async {},
      );
      final plan = await service.dryRun(package, BackupImportMode.replaceAll);
      final before = database.transactionCount;
      final result = await service.execute(plan);

      expect(result.success, isTrue);
      expect(database.transactionCount, before + 1);
      final restored = await repository.findCurrent();
      expect(restored!.userName, 'Kazuma');
      expect(restored.heightCm, 175.5);
      expect(restored.nationality, '日本');
    },
  );

  test(
    'Schema 2 through 7 REPLACE ALL clears the newer Profile store',
    () async {
      for (var schema = 2; schema <= 7; schema++) {
        final database = FakeIndexedDbDatabase();
        final repository = IndexedDbProfileRepository(
          database,
          clock: () => timestamp,
        );
        await repository.save(ProfileModel.validated(userName: 'Old value'));
        final controller = AppInitializationController()..markReady();
        final data = {
          for (final section in BackupSections.forSchema(schema))
            section: <Map<String, Object?>>[],
        };
        if (schema >= 3) {
          data[BackupSections.operationState] = [
            OperationState(
              operationDate: OperationLocalDate.parse('2026-08-03'),
              createdAt: timestamp,
              updatedAt: timestamp,
            ).toRecord(),
          ];
        }
        final package = BackupExportService.buildPackage(
          exportId: 'schema-$schema',
          exportedAt: timestamp,
          source: const BackupSource(platform: 'test'),
          data: data,
          schemaVersion: schema,
        );
        final service = BackupImportService(
          database: database,
          controller: controller,
          restore: () async {},
        );
        final plan = await service.dryRun(package, BackupImportMode.replaceAll);
        final result = await service.execute(plan);
        expect(result.success, isTrue, reason: 'schema $schema');
        expect(
          await repository.findCurrent(),
          isNull,
          reason: 'schema $schema',
        );
      }
    },
  );

  test('Profile section rejects invalid values', () {
    expect(
      () => BackupExportService.buildPackage(
        exportId: 'invalid-profile',
        exportedAt: timestamp,
        source: const BackupSource(platform: 'test'),
        data: {
          for (final section in BackupSections.schema8)
            section: section == BackupSections.profile
                ? [
                    {
                      'version': 1,
                      'userName': null,
                      'heightCm': 175.55,
                      'gender': 'invalid',
                      'nationality': '架空国',
                    },
                  ]
                : <Map<String, Object?>>[],
        },
      ),
      throwsA(anyOf(isA<FormatException>(), isA<BackupException>())),
    );
  });

  test(
    'Profile read-back failure rolls back the whole restore transaction',
    () async {
      final database = _CorruptProfileReadBackDatabase();
      final repository = IndexedDbProfileRepository(
        database,
        clock: () => timestamp,
      );
      await repository.save(ProfileModel.validated(userName: 'Before'));
      database.seed(
        IndexedDbStoreNames.operationState,
        'current',
        OperationState(
          operationDate: OperationLocalDate.parse('2026-08-03'),
          createdAt: timestamp,
          updatedAt: timestamp,
        ).toRecord(),
      );
      final controller = AppInitializationController()..markReady();
      final exported = await BackupExportService(
        database: database,
        controller: controller,
        clock: () => timestamp,
      ).create();
      final data = {
        for (final entry in exported.data.entries)
          entry.key: [
            for (final record in entry.value) Map<String, Object?>.from(record),
          ],
      };
      data[BackupSections.profile] = [
        {
          'version': 1,
          'userName': 'After',
          'heightCm': null,
          'gender': null,
          'nationality': null,
        },
      ];
      final package = BackupExportService.buildPackage(
        exportId: 'profile-rollback',
        exportedAt: timestamp,
        source: const BackupSource(platform: 'test'),
        data: data,
      );
      final service = BackupImportService(
        database: database,
        controller: controller,
        restore: () async {},
      );
      final plan = await service.dryRun(package, BackupImportMode.replaceAll);
      database.corruptProfileReadBack = true;

      final result = await service.execute(plan);

      expect(result.success, isFalse);
      database.corruptProfileReadBack = false;
      expect((await repository.findCurrent())!.userName, 'Before');
    },
  );
}

class _CorruptProfileReadBackDatabase extends FakeIndexedDbDatabase {
  bool corruptProfileReadBack = false;

  @override
  Future<T> runTransaction<T>({
    required Iterable<String> storeNames,
    required IndexedDbTransactionMode mode,
    required Future<T> Function(IndexedDbTransaction transaction) action,
  }) => super.runTransaction(
    storeNames: storeNames,
    mode: mode,
    action: (transaction) => action(
      corruptProfileReadBack && mode == IndexedDbTransactionMode.readWrite
          ? _CorruptProfileTransaction(transaction)
          : transaction,
    ),
  );
}

class _CorruptProfileTransaction implements IndexedDbTransaction {
  const _CorruptProfileTransaction(this.delegate);

  final IndexedDbTransaction delegate;

  @override
  Future<void> clear(String storeName) => delegate.clear(storeName);

  @override
  Future<void> deleteById(String storeName, String id) =>
      delegate.deleteById(storeName, id);

  @override
  Future<List<Map<String, Object?>>> findAll(String storeName) =>
      storeName == IndexedDbStoreNames.profileRecords
      ? Future.value(const [])
      : delegate.findAll(storeName);

  @override
  Future<Map<String, Object?>?> findById(String storeName, String id) =>
      delegate.findById(storeName, id);

  @override
  Future<void> put(String storeName, Map<String, Object?> record) =>
      delegate.put(storeName, record);
}
