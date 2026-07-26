import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_migration_metadata.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/repositories/repository_exception.dart';
import 'package:or_app/features/training/migration/custom_training_exercise_migration_service.dart';
import 'package:or_app/features/training/models/custom_training_exercise.dart';
import 'package:or_app/features/training/models/persisted_custom_training_exercise_record.dart';
import 'package:or_app/features/training/repository/custom_training_exercise_id_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('migrates names, aggregates duplicates, and preserves Legacy', () async {
    const source = <String>[
      'Custom Press',
      'Custom Press',
      ' custom_press ',
      'Custom Row',
    ];
    SharedPreferences.setMockInitialValues({
      'training_custom_exercises': source,
      'unrelated': 'keep',
    });
    final database = FakeIndexedDbDatabase();
    final service = CustomTrainingExerciseMigrationService(
      database,
      now: () => DateTime.utc(2026, 7, 26),
      ownerId: 'test',
    );

    final result = await service.migrate();

    expect(result.sourceCount, 4);
    expect(result.validCount, 4);
    expect(result.duplicateCount, 2);
    expect(result.writtenCount, 2);
    expect(result.conflictCount, 0);
    expect(
      await database.findAll(IndexedDbStoreNames.customTrainingExercises),
      hasLength(2),
    );
    expect(
      await database.findAll(IndexedDbStoreNames.migrationQuarantine),
      hasLength(2),
    );
    final metadata = IndexedDbMigrationMetadata.fromRecord(
      (await database.findById(
        IndexedDbStoreNames.migrationMetadata,
        CustomTrainingExerciseMigrationService.migrationId,
      ))!,
    );
    expect(metadata.status, IndexedDbMigrationStatus.completed);
    expect(metadata.validCounts['aggregatedRecordCount'], 2);
    expect(metadata.validCounts['duplicateRecordCount'], 2);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('training_custom_exercises'), source);
    expect(preferences.getString('unrelated'), 'keep');

    final repeated = await service.migrate();
    expect(repeated.alreadyCompleted, isTrue);
    expect(
      await database.findAll(IndexedDbStoreNames.customTrainingExercises),
      hasLength(2),
    );
  });

  test('accepts an existing same-ID same-content record', () async {
    SharedPreferences.setMockInitialValues({
      'training_custom_exercises': <String>['Custom Press'],
    });
    final database = FakeIndexedDbDatabase();
    final record = _legacyRecord('Custom Press');
    database.seed(
      IndexedDbStoreNames.customTrainingExercises,
      record.id,
      record.toRecord(),
    );

    final result = await CustomTrainingExerciseMigrationService(
      database,
      ownerId: 'test',
    ).migrate();

    expect(result.existingMatchCount, 1);
    expect(result.writtenCount, 0);
  });

  test('same ID with different content is quarantined as conflict', () async {
    SharedPreferences.setMockInitialValues({
      'training_custom_exercises': <String>['Custom Press'],
    });
    final database = FakeIndexedDbDatabase();
    final id = const CustomTrainingExerciseLegacyIdGenerator().generate(
      'Custom Press',
    );
    final conflicting = PersistedCustomTrainingExerciseRecord(
      id: id,
      normalizedName: 'other',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      data: CustomTrainingExercise(id: id, name: 'Other'),
    );
    database.seed(
      IndexedDbStoreNames.customTrainingExercises,
      id,
      conflicting.toRecord(),
    );

    await expectLater(
      CustomTrainingExerciseMigrationService(
        database,
        ownerId: 'test',
      ).migrate(),
      throwsA(isA<RepositoryException>()),
    );

    final metadata = IndexedDbMigrationMetadata.fromRecord(
      (await database.findById(
        IndexedDbStoreNames.migrationMetadata,
        CustomTrainingExerciseMigrationService.migrationId,
      ))!,
    );
    expect(metadata.status, IndexedDbMigrationStatus.failed);
    expect(metadata.validCounts['conflictRecordCount'], 1);
    expect(
      (await database.findAll(
        IndexedDbStoreNames.migrationQuarantine,
      )).single['conflictType'],
      'sameIdDifferentContent',
    );
  });

  test('different ID with same normalized name is a conflict', () async {
    SharedPreferences.setMockInitialValues({
      'training_custom_exercises': <String>['Custom Press'],
    });
    final database = FakeIndexedDbDatabase();
    const id = 'custom-exercise:00000000-0000-4000-8000-000000000000';
    final existing = PersistedCustomTrainingExerciseRecord(
      id: id,
      normalizedName: 'custompress',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      data: const CustomTrainingExercise(id: id, name: 'Custom Press'),
    );
    database.seed(
      IndexedDbStoreNames.customTrainingExercises,
      id,
      existing.toRecord(),
    );

    await expectLater(
      CustomTrainingExerciseMigrationService(
        database,
        ownerId: 'test',
      ).migrate(),
      throwsA(isA<RepositoryException>()),
    );

    expect(
      (await database.findAll(
        IndexedDbStoreNames.migrationQuarantine,
      )).single['conflictType'],
      'sameNormalizedNameDifferentId',
    );
  });

  test(
    'invalid Legacy container is quarantined and distinguished from empty',
    () async {
      SharedPreferences.setMockInitialValues({
        'training_custom_exercises': 'not-a-string-list',
      });
      final database = FakeIndexedDbDatabase();

      final result = await CustomTrainingExerciseMigrationService(
        database,
        ownerId: 'test',
      ).migrate();

      expect(result.sourceCount, 1);
      expect(result.invalidCount, 1);
      expect(result.writtenCount, 0);
      expect(
        await database.findAll(IndexedDbStoreNames.migrationQuarantine),
        hasLength(1),
      );
    },
  );

  test('transaction failure stays incomplete and can retry cleanly', () async {
    SharedPreferences.setMockInitialValues({
      'training_custom_exercises': <String>['Custom Press'],
    });
    final database = FakeIndexedDbDatabase()..failOnTransactionNumber = 2;
    final service = CustomTrainingExerciseMigrationService(
      database,
      ownerId: 'test',
    );

    await expectLater(service.migrate(), throwsA(isA<RepositoryException>()));
    final failed = IndexedDbMigrationMetadata.fromRecord(
      (await database.findById(
        IndexedDbStoreNames.migrationMetadata,
        CustomTrainingExerciseMigrationService.migrationId,
      ))!,
    );
    expect(failed.status, IndexedDbMigrationStatus.failed);
    expect(
      await database.findAll(IndexedDbStoreNames.customTrainingExercises),
      isEmpty,
    );

    database.failOnTransactionNumber = null;
    final retried = await service.migrate();
    expect(retried.writtenCount, 1);
    expect(
      await database.findAll(IndexedDbStoreNames.customTrainingExercises),
      hasLength(1),
    );
  });
}

PersistedCustomTrainingExerciseRecord _legacyRecord(String name) {
  final id = const CustomTrainingExerciseLegacyIdGenerator().generate(name);
  return PersistedCustomTrainingExerciseRecord(
    id: id,
    normalizedName: 'custompress',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    data: CustomTrainingExercise(id: id, name: name),
  );
}
