import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_schema.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/import_export/services/backup_import_service.dart';
import 'package:or_app/features/import_export/services/backup_package_codec.dart';
import 'package:or_app/features/training/models/custom_training_exercise.dart';
import 'package:or_app/features/training/models/persisted_custom_training_exercise_record.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../daily_log_confirmation/daily_log_confirmation_test_fixture.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late AppInitializationController controller;

  setUp(() {
    database = FakeIndexedDbDatabase();
    controller = AppInitializationController()..markReady();
  });

  test(
    'exports deterministic Schema 2.0 package with all six sections',
    () async {
      final package = await BackupExportService(
        database: database,
        controller: controller,
        clock: () => DateTime.utc(2026, 7, 26, 12),
      ).create(origin: 'https://example.test');

      expect(package.schema, BackupPackage.schemaName);
      expect(package.schemaVersion, 2);
      expect(package.databaseVersion, IndexedDbSchema.databaseVersion);
      expect(package.data.keys, containsAll(BackupSections.all));
      expect(
        package.recordCounts.values.values.every((count) => count == 0),
        isTrue,
      );

      final decoded = const BackupPackageCodec().decode(
        BackupExportService.encode(package),
      );
      expect(decoded.digests.package, package.digests.package);
    },
  );

  test('rejects changed section content and invalid package digest', () async {
    final package = await BackupExportService(
      database: database,
      controller: controller,
    ).create();
    final json =
        jsonDecode(BackupExportService.encode(package)) as Map<String, dynamic>;
    json['recordCounts']['status'] = 1;

    expect(
      () => const BackupPackageCodec().decode(jsonEncode(json)),
      throwsA(isA<BackupException>()),
    );
  });

  test('accepts UTF-8 BOM and rejects an empty file', () async {
    final package = await BackupExportService(
      database: database,
      controller: controller,
    ).create();
    final bytes = [
      0xef,
      0xbb,
      0xbf,
      ...utf8.encode(BackupExportService.encode(package)),
    ];

    expect(const BackupPackageCodec().decodeUtf8(bytes).schemaVersion, 2);
    expect(
      () => const BackupPackageCodec().decodeUtf8(const []),
      throwsA(
        isA<BackupException>().having(
          (error) => error.code,
          'code',
          'empty_file',
        ),
      ),
    );
  });

  test('Schema 2.0 accepts old Confirmation without energy field', () async {
    final envelope = PersistedDailyLogConfirmationRecord(
      id: 'confirmation:2026-07-26',
      localDate: '2026-07-26',
      createdAt: DateTime.utc(2026, 7, 26),
      updatedAt: DateTime.utc(2026, 7, 26),
      data: completeConfirmation(),
    ).toRecord();
    (envelope['data']! as Map).remove('estimatedTotalBurnKcal');
    database.seed(
      IndexedDbStoreNames.dailyLogConfirmations,
      envelope['id']! as String,
      envelope,
    );

    final package = await BackupExportService(
      database: database,
      controller: controller,
    ).create();
    final decoded = const BackupPackageCodec().decode(
      BackupExportService.encode(package),
    );

    expect(
      (decoded.data[BackupSections.confirmations]!.single['data']! as Map)
          .containsKey('estimatedTotalBurnKcal'),
      isFalse,
    );
  });

  test('Schema 2.0 exports and imports the energy Snapshot value', () async {
    final envelope = PersistedDailyLogConfirmationRecord(
      id: 'confirmation:2026-07-26',
      localDate: '2026-07-26',
      createdAt: DateTime.utc(2026, 7, 26),
      updatedAt: DateTime.utc(2026, 7, 26),
      data: completeConfirmation(),
    ).toRecord();
    database.seed(
      IndexedDbStoreNames.dailyLogConfirmations,
      envelope['id']! as String,
      envelope,
    );
    final package = await BackupExportService(
      database: database,
      controller: controller,
    ).create();
    final restoredDatabase = FakeIndexedDbDatabase();
    final restoredController = AppInitializationController()..markReady();
    final importService = BackupImportService(
      database: restoredDatabase,
      controller: restoredController,
      restore: () async {},
    );

    final plan = await importService.dryRun(
      package,
      BackupImportMode.replaceAll,
    );
    final result = await importService.execute(plan);
    final restoredEnvelope = PersistedDailyLogConfirmationRecord.fromRecord(
      (await restoredDatabase.findById(
        IndexedDbStoreNames.dailyLogConfirmations,
        'confirmation:2026-07-26',
      ))!,
    );

    expect(result.success, isTrue);
    expect(restoredEnvelope.data.estimatedTotalBurnKcal, 2875.5);
  });

  test('Schema 1.0 converts STATUS and TRAINING only using exportedAt', () {
    final exportedAt = DateTime.utc(2026, 1, 2, 3, 4, 5);
    final morning = MorningData(
      date: '2026-01-02T07:00:00.000',
      weight: 70,
      bodyFat: 15,
      sleepHours: 7,
      sleepScore: 80,
      footPain: 2,
      workType: WorkType.work,
      workStart: '',
      workEnd: '',
      workBreak: '',
      workHours: 0,
      memo: '',
    );
    final training = TrainingSession(
      date: '2026-01-02T18:00:00.000',
      memo: '',
      exercises: const [],
    );
    final package = const BackupPackageCodec().decode(
      jsonEncode({
        'schemaVersion': '1.0',
        'exportedAt': exportedAt.toIso8601String(),
        'morningFact': [morning.toJson()],
        'training': [training.toJson()],
        'metadata': <String, Object?>{},
      }),
    );

    expect(package.includedSections, {
      BackupSections.status,
      BackupSections.training,
    });
    expect(package.permitsReplaceAll, isFalse);
    expect(
      package.data[BackupSections.status]!.single['createdAt'],
      exportedAt.toIso8601String(),
    );
    expect(
      package.data[BackupSections.training]!.single['updatedAt'],
      exportedAt.toIso8601String(),
    );
    expect(
      package.data[BackupSections.training]!.single['id'],
      startsWith('legacy-training:'),
    );
  });

  test(
    'Schema 1.0 refuses REPLACE ALL and preserves absent sections',
    () async {
      final package = const BackupPackageCodec().decode(
        jsonEncode({
          'schemaVersion': '1.0',
          'exportedAt': DateTime.utc(2026, 1, 2).toIso8601String(),
          'morningFact': <Object?>[],
          'training': <Object?>[],
        }),
      );
      final service = BackupImportService(
        database: database,
        controller: controller,
        restore: () async {},
      );

      expect(
        () => service.dryRun(package, BackupImportMode.replaceAll),
        throwsA(
          isA<BackupException>().having(
            (error) => error.code,
            'code',
            'legacy_replace_forbidden',
          ),
        ),
      );
    },
  );

  test('MERGE adds missing envelope and repeats idempotently', () async {
    final record = _customRecord(
      'custom-exercise:00000000-0000-4000-8000-000000000001',
    );
    final package = BackupExportService.buildPackage(
      exportId: '00000000-0000-4000-8000-000000000002',
      exportedAt: DateTime.utc(2026, 7, 26),
      source: const BackupSource(platform: 'web'),
      data: {
        for (final section in BackupSections.all)
          section: section == BackupSections.customExercises ? [record] : [],
      },
    );
    final service = BackupImportService(
      database: database,
      controller: controller,
      restore: () async {},
    );
    final firstPlan = await service.dryRun(package, BackupImportMode.merge);
    expect(firstPlan.sections[BackupSections.customExercises]!.add, 1);
    expect((await service.execute(firstPlan)).success, isTrue);

    final secondPlan = await service.dryRun(package, BackupImportMode.merge);
    expect(secondPlan.sections[BackupSections.customExercises]!.skip, 1);
    expect(secondPlan.sections[BackupSections.customExercises]!.add, 0);
  });

  test('MERGE conflict never starts a write transaction', () async {
    final id = 'custom-exercise:00000000-0000-4000-8000-000000000005';
    final existing = _customRecord(id);
    database.seed(IndexedDbStoreNames.customTrainingExercises, id, existing);
    final changed = Map<String, Object?>.from(existing)
      ..['updatedAt'] = DateTime.utc(2026, 7, 27).toIso8601String();
    final package = BackupExportService.buildPackage(
      exportId: '00000000-0000-4000-8000-000000000006',
      exportedAt: DateTime.utc(2026, 7, 27),
      source: const BackupSource(platform: 'web'),
      data: {
        for (final section in BackupSections.all)
          section: section == BackupSections.customExercises ? [changed] : [],
      },
    );
    final service = BackupImportService(
      database: database,
      controller: controller,
      restore: () async {},
    );

    final plan = await service.dryRun(package, BackupImportMode.merge);

    expect(plan.hasConflicts, isTrue);
    expect((await service.execute(plan)).errorCode, 'import_conflict');
    expect(database.transactionCount, 0);
  });

  test(
    'maintenance mode is active only while approved import executes',
    () async {
      final package = BackupExportService.buildPackage(
        exportId: '00000000-0000-4000-8000-000000000007',
        exportedAt: DateTime.utc(2026, 7, 27),
        source: const BackupSource(platform: 'web'),
        data: {for (final section in BackupSections.all) section: []},
      );
      var modeDuringRestore = PersistenceMode.failed;
      final service = BackupImportService(
        database: database,
        controller: controller,
        restore: () async {
          modeDuringRestore = controller.value.mode;
        },
      );
      final plan = await service.dryRun(package, BackupImportMode.replaceAll);
      expect(controller.value.mode, PersistenceMode.indexedDbReadWrite);

      final result = await service.execute(plan);

      expect(result.success, isTrue);
      expect(modeDuringRestore, PersistenceMode.maintenance);
      expect(controller.value.mode, PersistenceMode.indexedDbReadWrite);
    },
  );

  test(
    'failed REPLACE ALL transaction rolls back and returns ready mode',
    () async {
      final existing = _customRecord(
        'custom-exercise:00000000-0000-4000-8000-000000000003',
      );
      database.seed(
        IndexedDbStoreNames.customTrainingExercises,
        existing['id'] as String,
        existing,
      );
      final package = BackupExportService.buildPackage(
        exportId: '00000000-0000-4000-8000-000000000004',
        exportedAt: DateTime.utc(2026, 7, 26),
        source: const BackupSource(platform: 'web'),
        data: {for (final section in BackupSections.all) section: []},
      );
      final service = BackupImportService(
        database: database,
        controller: controller,
        restore: () async {},
      );
      final plan = await service.dryRun(package, BackupImportMode.replaceAll);
      database.failNextTransactionWith = StateError('write failed');

      final result = await service.execute(plan);

      expect(result.success, isFalse);
      expect(controller.value.mode, PersistenceMode.indexedDbReadWrite);
      expect(
        await database.findAll(IndexedDbStoreNames.customTrainingExercises),
        hasLength(1),
      );
    },
  );
}

Map<String, Object?> _customRecord(String id) {
  final timestamp = DateTime.utc(2026, 7, 26);
  return PersistedCustomTrainingExerciseRecord(
    id: id,
    normalizedName: 'testexercise',
    createdAt: timestamp,
    updatedAt: timestamp,
    data: CustomTrainingExercise(id: id, name: 'Test Exercise'),
  ).toRecord();
}
