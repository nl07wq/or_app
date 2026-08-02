import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../import_export/services/backup_store_registry.dart';
import '../models/operation_sync_issue.dart';
import '../models/operation_transfer_package.dart';
import 'operation_sync_record_envelope.dart';
import 'operation_sync_validator.dart';

typedef OperationSyncRecordMatcher = bool Function(Map<String, Object?>);

class OperationSyncRecordPolicy {
  final String recordType;
  final String storeName;
  final String backupSection;
  final Set<int> recordVersions;
  final bool dateBound;
  final OperationSyncRecordMatcher matches;
  final List<String> uniqueFields;

  const OperationSyncRecordPolicy({
    required this.recordType,
    required this.storeName,
    required this.backupSection,
    required this.recordVersions,
    required this.dateBound,
    required this.matches,
    this.uniqueFields = const [],
  });

  String recordId(Map<String, Object?> record) =>
      BackupStoreRegistry.recordId(backupSection, record);

  int recordVersion(Map<String, Object?> record) {
    final value = record['recordVersion'];
    if (value is! int || !recordVersions.contains(value)) {
      throw const OperationSyncException(
        OperationSyncIssueCode.versionUnsupported,
        'Operation Sync record version is unsupported.',
      );
    }
    return value;
  }

  String localDate(Map<String, Object?> record) {
    final value = dateBound ? record['localDate'] : record['createdAt'];
    if (value is! String || value.length < 10) {
      throw const OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        'Operation Sync record date is invalid.',
      );
    }
    return value.substring(0, 10);
  }

  void validate(Map<String, Object?> record) {
    try {
      BackupStoreRegistry.validateRecord(backupSection, record);
    } catch (error) {
      throw OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        'Operation Sync $recordType record is invalid: $error',
      );
    }
  }
}

abstract class IndexedDbOperationTransferModuleAdapter
    implements OperationTransferModuleAdapter {
  final IndexedDbDatabase database;
  final List<OperationSyncRecordPolicy> policies;

  IndexedDbOperationTransferModuleAdapter({
    required this.database,
    required Iterable<OperationSyncRecordPolicy> policies,
  }) : policies = List.unmodifiable(policies);

  @override
  Set<int> get supportedRecordVersions => {
    for (final policy in policies) ...policy.recordVersions,
  };

  @override
  Set<String> get storeNames => {
    for (final policy in policies) policy.storeName,
  };

  @override
  Future<List<OperationTransferRecord>> exportRecords() async {
    final result = <OperationTransferRecord>[];
    for (final storeName in storeNames) {
      final stored = await database.findAll(storeName);
      for (final record in stored) {
        final policy = _policyForStored(record, storeName: storeName);
        policy.validate(record);
        result.add(
          OperationSyncRecordEnvelope.transferRecord(
            recordType: policy.recordType,
            record: record,
            recordId: policy.recordId(record),
            recordVersion: policy.recordVersion(record),
            localDate: policy.localDate(record),
          ),
        );
      }
    }
    result.sort((a, b) {
      final first = OperationSyncRecordEnvelope.fromTransfer(a);
      final second = OperationSyncRecordEnvelope.fromTransfer(b);
      final byType = _policyIndex(
        first.recordType,
      ).compareTo(_policyIndex(second.recordType));
      return byType != 0 ? byType : a.recordId.compareTo(b.recordId);
    });
    return List.unmodifiable(result);
  }

  @override
  Future<OperationSyncRecordInspection> inspect(
    OperationTransferRecord record,
    OperationSyncInspectionContext context,
  ) async {
    try {
      final parsed = _parse(record);
      final referenceIssues = await inspectReferences(parsed, context);
      if (referenceIssues.isNotEmpty) {
        return OperationSyncRecordInspection(
          disposition: OperationSyncRecordDisposition.conflict,
          issues: referenceIssues,
        );
      }
      final existing = await database.findById(
        parsed.policy.storeName,
        record.recordId,
      );
      if (existing == null) {
        final conflict = await _findUniqueConflict(parsed);
        if (conflict != null) return conflict;
        return const OperationSyncRecordInspection.create();
      }
      return _compareExisting(parsed, existing);
    } on OperationSyncException catch (error) {
      return OperationSyncRecordInspection(
        disposition: OperationSyncRecordDisposition.conflict,
        issues: [
          OperationSyncIssue(
            level: OperationSyncIssueLevel.blocking,
            code: error.code,
            message: error.message,
            module: module,
            recordId: record.recordId,
          ),
        ],
      );
    } catch (error) {
      return OperationSyncRecordInspection(
        disposition: OperationSyncRecordDisposition.conflict,
        issues: [
          OperationSyncIssue(
            level: OperationSyncIssueLevel.blocking,
            code: OperationSyncIssueCode.integrityFailure,
            message: 'Operation Sync inspection failed: $error',
            module: module,
            recordId: record.recordId,
          ),
        ],
      );
    }
  }

  @override
  bool isDateBound(OperationTransferRecord record) =>
      _parse(record).policy.dateBound;

  @override
  Future<bool> hasTargetRecords() async {
    for (final storeName in storeNames) {
      if ((await database.findAll(storeName)).isNotEmpty) return true;
    }
    return false;
  }

  @override
  Future<OperationSyncApplyCounts> apply(
    IndexedDbTransaction transaction,
    List<OperationTransferRecord> records,
    OperationSyncInspectionContext context,
  ) async {
    final ordered = records.toList()
      ..sort((first, second) {
        final firstType = OperationSyncRecordEnvelope.fromTransfer(
          first,
        ).recordType;
        final secondType = OperationSyncRecordEnvelope.fromTransfer(
          second,
        ).recordType;
        return _policyIndex(firstType).compareTo(_policyIndex(secondType));
      });
    var created = 0;
    var noChanges = 0;
    for (final source in ordered) {
      final parsed = _parse(source);
      await validateReferencesInTransaction(parsed, transaction, context);
      final existing = await transaction.findById(
        parsed.policy.storeName,
        source.recordId,
      );
      if (existing != null) {
        final inspection = _compareExisting(parsed, existing);
        if (inspection.disposition == OperationSyncRecordDisposition.noChange) {
          noChanges++;
          continue;
        }
        throw const OperationSyncException(
          OperationSyncIssueCode.recordIdConflict,
          'Target record changed after preview.',
        );
      }
      await _requireUniqueInTransaction(parsed, transaction);
      await transaction.put(parsed.policy.storeName, parsed.envelope.record);
      created++;
    }
    return OperationSyncApplyCounts(created: created, noChanges: noChanges);
  }

  @override
  Future<bool> verify(
    IndexedDbTransaction transaction,
    List<OperationTransferRecord> records,
  ) async {
    for (final source in records) {
      final parsed = _parse(source);
      final stored = await transaction.findById(
        parsed.policy.storeName,
        source.recordId,
      );
      if (stored == null ||
          !OperationSyncRecordEnvelope.persistedEqual(
            stored,
            parsed.envelope.record,
          )) {
        return false;
      }
      parsed.policy.validate(stored);
    }
    return true;
  }

  Future<List<OperationSyncIssue>> inspectReferences(
    OperationSyncParsedRecord record,
    OperationSyncInspectionContext context,
  ) async => const [];

  Future<void> validateReferencesInTransaction(
    OperationSyncParsedRecord record,
    IndexedDbTransaction transaction,
    OperationSyncInspectionContext context,
  ) async {}

  OperationSyncParsedRecord parseRecord(OperationTransferRecord record) =>
      _parse(record);

  int _policyIndex(String recordType) =>
      policies.indexWhere((policy) => policy.recordType == recordType);

  OperationSyncParsedRecord _parse(OperationTransferRecord source) {
    final envelope = OperationSyncRecordEnvelope.fromTransfer(source);
    final policy = policies
        .where((candidate) => candidate.recordType == envelope.recordType)
        .firstOrNull;
    if (policy == null) {
      throw const OperationSyncException(
        OperationSyncIssueCode.versionUnsupported,
        'Operation Sync recordType is unsupported.',
      );
    }
    policy.validate(envelope.record);
    if (!policy.matches(envelope.record) ||
        policy.recordId(envelope.record) != source.recordId ||
        policy.recordVersion(envelope.record) != source.recordVersion ||
        policy.localDate(envelope.record) != source.localDate) {
      throw const OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        'Operation Sync transport envelope does not match its record.',
      );
    }
    return OperationSyncParsedRecord(
      source: source,
      envelope: envelope,
      policy: policy,
    );
  }

  OperationSyncRecordPolicy _policyForStored(
    Map<String, Object?> record, {
    required String storeName,
  }) {
    final matches = policies
        .where(
          (policy) => policy.storeName == storeName && policy.matches(record),
        )
        .toList();
    if (matches.length != 1) {
      throw const OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        'Persisted record cannot be assigned to one Operation Sync type.',
      );
    }
    return matches.single;
  }

  OperationSyncRecordInspection _compareExisting(
    OperationSyncParsedRecord incoming,
    Map<String, Object?> existing,
  ) {
    incoming.policy.validate(existing);
    final existingEnvelope = OperationSyncRecordEnvelope(
      recordType: incoming.envelope.recordType,
      record: existing,
    );
    if (existingEnvelope.domainDigest != incoming.envelope.domainDigest) {
      return OperationSyncRecordInspection(
        disposition: OperationSyncRecordDisposition.conflict,
        issues: [
          OperationSyncIssue(
            level: OperationSyncIssueLevel.blocking,
            code: OperationSyncIssueCode.recordIdConflict,
            message: 'The target record ID contains different domain data.',
            module: module,
            recordId: incoming.source.recordId,
          ),
        ],
      );
    }
    if (existingEnvelope.persistedDigest != incoming.envelope.persistedDigest) {
      return OperationSyncRecordInspection(
        disposition: OperationSyncRecordDisposition.conflict,
        issues: [
          OperationSyncIssue(
            level: OperationSyncIssueLevel.blocking,
            code: OperationSyncIssueCode.canonicalConflict,
            message: 'The target record timestamps do not match.',
            module: module,
            recordId: incoming.source.recordId,
          ),
        ],
      );
    }
    return const OperationSyncRecordInspection.noChange();
  }

  Future<OperationSyncRecordInspection?> _findUniqueConflict(
    OperationSyncParsedRecord incoming,
  ) async {
    if (incoming.policy.uniqueFields.isEmpty) return null;
    final stored = await database.findAll(incoming.policy.storeName);
    for (final existing in stored) {
      if (_hasUniqueConflict(incoming, existing)) {
        return OperationSyncRecordInspection(
          disposition: OperationSyncRecordDisposition.conflict,
          issues: [
            OperationSyncIssue(
              level: OperationSyncIssueLevel.blocking,
              code: OperationSyncIssueCode.canonicalConflict,
              message: 'The record conflicts with a target unique index.',
              module: module,
              recordId: incoming.source.recordId,
            ),
          ],
        );
      }
    }
    return null;
  }

  Future<void> _requireUniqueInTransaction(
    OperationSyncParsedRecord incoming,
    IndexedDbTransaction transaction,
  ) async {
    if (incoming.policy.uniqueFields.isEmpty) return;
    final stored = await transaction.findAll(incoming.policy.storeName);
    if (stored.any((existing) => _hasUniqueConflict(incoming, existing))) {
      throw const OperationSyncException(
        OperationSyncIssueCode.canonicalConflict,
        'The record conflicts with a target unique index.',
      );
    }
  }

  bool _hasUniqueConflict(
    OperationSyncParsedRecord incoming,
    Map<String, Object?> existing,
  ) {
    if (incoming.policy.recordId(existing) == incoming.source.recordId) {
      return false;
    }
    return incoming.policy.uniqueFields.any((field) {
      final value = incoming.envelope.record[field];
      return value != null && existing[field] == value;
    });
  }
}

class OperationSyncParsedRecord {
  final OperationTransferRecord source;
  final OperationSyncRecordEnvelope envelope;
  final OperationSyncRecordPolicy policy;

  const OperationSyncParsedRecord({
    required this.source,
    required this.envelope,
    required this.policy,
  });
}
