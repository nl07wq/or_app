part of 'training_v2_migration_executor.dart';

class TrainingV2MigrationIntegrity {
  final IndexedDbDatabase _database;
  final String migrationId;

  const TrainingV2MigrationIntegrity(
    this._database, {
    required this.migrationId,
  });

  Future<void> verifyInitial(
    TrainingV2MigrationPlan plan,
    TrainingV2MigrationWriteOutcome outcome,
    TrainingV2SourceVerifier verifySourceUnchanged,
  ) async {
    if (!await verifySourceUnchanged(plan)) {
      throw const FormatException(
        'TRAINING migration source changed during migration.',
      );
    }
    final actualTargets = <Map<String, Object?>>[];
    for (final expected in outcome.targets) {
      final actual = await _database.findById(
        IndexedDbStoreNames.trainingRecords,
        expected.id,
      );
      if (actual == null ||
          canonicalJson(actual) != canonicalJson(expected.toRecord())) {
        throw FormatException(
          'TRAINING migration target differs: ${expected.id}.',
        );
      }
      actualTargets.add(actual);
    }
    final actualQuarantine = await migrationQuarantineIds();
    final expectedQuarantine = outcome.quarantine
        .map((record) => record.id)
        .toSet();
    final expectedTargetIds = outcome.targets
        .map((record) => record.id)
        .toSet();
    if (!sameSet(actualQuarantine, expectedQuarantine) ||
        outcome.metadata.targetIdDigest != digest(expectedTargetIds) ||
        outcome.metadata.targetDigest != digestCanonical(actualTargets)) {
      throw const FormatException(
        'TRAINING migration verification digest differs.',
      );
    }
  }

  Future<Set<String>> verifyCompletedQuarantine(
    IndexedDbMigrationMetadata metadata,
  ) async {
    final expected =
        metadata.expectedRecordIds[IndexedDbStoreNames.migrationQuarantine]!;
    final actual = await migrationQuarantineIds();
    if (!sameSet(expected, actual)) {
      throw const FormatException(
        'Completed TRAINING migration quarantine differs.',
      );
    }
    return actual;
  }

  Future<Set<String>> migrationQuarantineIds() async {
    final values = await _database.findAll(
      IndexedDbStoreNames.migrationQuarantine,
    );
    return {
      for (final value in values)
        if (IndexedDbQuarantinedRecord.fromRecord(value).migrationId ==
            migrationId)
          value['id'] as String,
    };
  }

  static int problemCount(TrainingV2MigrationPlan plan, String category) {
    return plan.problems
        .where((problem) => problem.category == category)
        .length;
  }

  static bool isTrainingId(String id) {
    try {
      PersistedTrainingRecord.validateId(id);
      return true;
    } on FormatException {
      return false;
    }
  }

  static bool isDigest(String? value) {
    return value != null && RegExp(r'^[0-9a-f]{8}$').hasMatch(value);
  }

  static bool sameSet(Iterable<String> first, Iterable<String> second) {
    final a = first.toSet();
    final b = second.toSet();
    return a.length == b.length && a.containsAll(b);
  }

  static String canonicalJson(Object? value) {
    return TrainingLegacyIdGenerator.canonicalJson(value);
  }

  static String digestCanonical(Iterable<Object?> values) {
    final canonical = values.map(canonicalJson).toList()..sort();
    return digest(canonical);
  }

  static String digest(Iterable<String> values) {
    final sorted = values.toList()..sort();
    return TrainingLegacyIdGenerator.fnv1aDigest(sorted.join('\u0000'));
  }
}
