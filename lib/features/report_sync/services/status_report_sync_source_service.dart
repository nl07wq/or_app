import '../../../core/models/morning_data.dart';
import '../../../core/models/work_type.dart';
import '../../../core/services/work_calculator.dart';
import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../operation_date/models/operation_local_date.dart';
import '../../status/models/persisted_status_record.dart';
import '../models/status_report_sync_source.dart';
import 'report_sync_canonical_service.dart';

class StatusReportSyncSourceService {
  const StatusReportSyncSourceService(this._database);

  final IndexedDbDatabase _database;

  Future<StatusReportSyncSourceExport> generate({
    required String operationDate,
    required DateTime exportedAt,
  }) async {
    final targetDate = _parseOperationDate(operationDate);
    final current = await _readCanonical(targetDate.value, required: true);
    final previousDate = targetDate.addDays(-1).value;
    _StoredStatusSource? previous;
    try {
      previous = await _readCanonical(previousDate, required: false);
    } on StatusReportSyncSourceException {
      // A missing or invalid previous-day record never blocks the current
      // STATUS export. Its derived comparison remains unavailable.
      previous = null;
    }
    final source = _project(
      current!,
      previousOperationDate: previousDate,
      previous: previous,
    );
    final canonicalText = _serializeSource(source);
    final digest = ReportSyncCanonicalService.digestUtf8(canonicalText);
    if (!ReportSyncCanonicalService.isDigest(digest)) {
      throw StatusReportSyncSourceException(
        code: 'statusSourceDigestFailed',
        stage: 'SOURCE DIGEST',
        message: 'STATUS Source Digestを作成できませんでした。',
        operationDate: operationDate,
      );
    }
    final utcExportedAt = exportedAt.toUtc();
    return StatusReportSyncSourceExport(
      source: source,
      exportedAt: utcExportedAt,
      sourceDigest: digest,
      canonicalText: canonicalText,
      plainText: _serializeDisplay(
        canonicalText,
        exportedAt: utcExportedAt,
        sourceDigest: digest,
      ),
    );
  }

  OperationLocalDate _parseOperationDate(String value) {
    try {
      return OperationLocalDate.parse(value);
    } catch (_) {
      throw StatusReportSyncSourceException(
        code: 'statusSourceDateMismatch',
        stage: 'SOURCE VALIDATION',
        message: 'STATUSの日付が対象日と一致しません。',
        operationDate: value,
        field: 'operationDate',
      );
    }
  }

  Future<_StoredStatusSource?> _readCanonical(
    String operationDate, {
    required bool required,
  }) async {
    final expectedId = PersistedStatusRecord.canonicalId(operationDate);
    final raw = await _database.findById(
      IndexedDbStoreNames.statusRecords,
      expectedId,
    );
    if (raw == null) {
      if (!required) return null;
      throw StatusReportSyncSourceException(
        code: 'statusSourceMissing',
        stage: 'SOURCE READ',
        message: '対象日のSTATUSがありません。',
        operationDate: operationDate,
      );
    }
    if (raw['id'] != expectedId ||
        raw['recordKind'] != StatusRecordKind.canonical.name ||
        raw['canonicalDate'] != operationDate) {
      throw StatusReportSyncSourceException(
        code: 'statusSourceNotCanonical',
        stage: 'SOURCE VALIDATION',
        message: '正式STATUSとして確認できません。',
        operationDate: operationDate,
        field: 'id',
      );
    }
    if (raw['localDate'] != operationDate) {
      throw StatusReportSyncSourceException(
        code: 'statusSourceDateMismatch',
        stage: 'SOURCE VALIDATION',
        message: 'STATUSの日付が対象日と一致しません。',
        operationDate: operationDate,
        field: 'localDate',
      );
    }
    if (raw['recordVersion'] != PersistedStatusRecord.currentRecordVersion) {
      throw StatusReportSyncSourceException(
        code: 'statusSourceInvalid',
        stage: 'SOURCE VALIDATION',
        message: 'STATUSに不正な値があります。',
        operationDate: operationDate,
        field: 'recordVersion',
      );
    }
    final data = raw['data'];
    if (data is! Map) {
      throw StatusReportSyncSourceException(
        code: 'statusSourceIncomplete',
        stage: 'SOURCE VALIDATION',
        message: 'STATUS必須項目が不足しています。',
        operationDate: operationDate,
        field: 'data',
      );
    }
    final sourceData = Map<String, Object?>.from(data);
    const requiredFields = {
      'date',
      'footPain',
      'workType',
      'workStart',
      'workEnd',
      'workBreak',
      'workHours',
      'memo',
    };
    final missing = requiredFields.difference(sourceData.keys.toSet());
    if (missing.isNotEmpty) {
      throw StatusReportSyncSourceException(
        code: 'statusSourceIncomplete',
        stage: 'SOURCE VALIDATION',
        message: 'STATUS必須項目が不足しています。',
        operationDate: operationDate,
        field: missing.first,
      );
    }
    _validateRawData(operationDate, sourceData);
    final record = _decodeRecord(raw, operationDate);
    if (PersistedStatusRecord.localDateFromSource(record.data.date) !=
        operationDate) {
      throw StatusReportSyncSourceException(
        code: 'statusSourceDateMismatch',
        stage: 'SOURCE VALIDATION',
        message: 'STATUSの日付が対象日と一致しません。',
        operationDate: operationDate,
        field: 'data.date',
      );
    }
    _validateRecord(record, sourceData);
    return _StoredStatusSource(record: record);
  }

  void _validateRawData(String operationDate, Map<String, Object?> rawData) {
    if (rawData['date'] is! String ||
        (rawData['weight'] != null && rawData['weight'] is! num) ||
        (rawData['bodyFat'] != null && rawData['bodyFat'] is! num) ||
        (rawData['sleepHours'] != null && rawData['sleepHours'] is! num) ||
        (rawData['sleepScore'] != null && rawData['sleepScore'] is! int) ||
        rawData['footPain'] is! int ||
        rawData['workType'] is! String ||
        rawData['workStart'] is! String ||
        rawData['workEnd'] is! String ||
        rawData['workBreak'] is! String ||
        rawData['workHours'] is! num ||
        rawData['memo'] is! String) {
      _invalid(operationDate, 'data');
    }
    if (!WorkType.values.any((value) => value.name == rawData['workType'])) {
      _invalid(operationDate, 'workType');
    }
    String sourceLocalDate;
    try {
      sourceLocalDate = PersistedStatusRecord.localDateFromSource(
        rawData['date']! as String,
      );
    } catch (_) {
      _invalid(operationDate, 'data.date');
    }
    if (sourceLocalDate != operationDate) {
      throw StatusReportSyncSourceException(
        code: 'statusSourceDateMismatch',
        stage: 'SOURCE VALIDATION',
        message: 'STATUSの日付が対象日と一致しません。',
        operationDate: operationDate,
        field: 'data.date',
      );
    }
  }

  PersistedStatusRecord _decodeRecord(
    Map<String, Object?> raw,
    String operationDate,
  ) {
    try {
      return PersistedStatusRecord.fromRecord(raw);
    } catch (_) {
      throw StatusReportSyncSourceException(
        code: 'statusSourceInvalid',
        stage: 'SOURCE VALIDATION',
        message: 'STATUSに不正な値があります。',
        operationDate: operationDate,
      );
    }
  }

  void _validateRecord(
    PersistedStatusRecord record,
    Map<String, Object?> rawData,
  ) {
    final date = record.localDate;
    final data = record.data;
    if (record.updatedAt.isBefore(record.createdAt)) {
      _invalid(date, 'updatedAt');
    }
    if (data.weight != null &&
        (!data.weight!.isFinite || data.weight! < 40 || data.weight! > 180)) {
      _invalid(date, 'weight');
    }
    if (data.bodyFat != null &&
        (!data.bodyFat!.isFinite || data.bodyFat! < 0 || data.bodyFat! > 60)) {
      _invalid(date, 'bodyFat');
    }
    if (data.sleepHours != null &&
        (!data.sleepHours!.isFinite ||
            data.sleepHours! < 0 ||
            data.sleepHours! >= 24)) {
      _invalid(date, 'sleepHours');
    }
    final sleepMinutes = data.sleepHours == null ? null : data.sleepHours! * 60;
    if (sleepMinutes != null &&
        (sleepMinutes - sleepMinutes.round()).abs() > 0.000000001) {
      _invalid(date, 'sleepHours');
    }
    if (data.sleepScore != null &&
        (data.sleepScore! < 0 || data.sleepScore! > 100)) {
      _invalid(date, 'sleepScore');
    }
    if (data.footPain < 1 || data.footPain > 10) {
      _invalid(date, 'footPain');
    }
    if (rawData['condition'] != null && rawData['condition'] is! int) {
      _invalid(date, 'condition');
    }
    if (rawData['previousCarryoverConfirmed'] != null &&
        rawData['previousCarryoverConfirmed'] is! bool) {
      _invalid(date, 'previousCarryoverConfirmed');
    }
    if (rawData['memo'] is! String) _invalid(date, 'memo');

    if (data.workType.isWorking) {
      if (!_validTime(data.workStart) ||
          !_validTime(data.workEnd) ||
          !_validTime(data.workBreak)) {
        _invalid(date, 'work');
      }
      final calculated = WorkCalculator.calculate(
        start: data.workStart,
        end: data.workEnd,
        workBreak: data.workBreak,
      );
      if (!data.workHours.isFinite ||
          data.workHours < 0 ||
          (calculated - data.workHours).abs() > 0.000000001) {
        _invalid(date, 'workHours');
      }
    } else if (data.workStart.isNotEmpty ||
        data.workEnd.isNotEmpty ||
        data.workBreak.isNotEmpty ||
        data.workHours != 0) {
      _invalid(date, 'work');
    }
  }

  Never _invalid(String operationDate, String field) {
    throw StatusReportSyncSourceException(
      code: 'statusSourceInvalid',
      stage: 'SOURCE VALIDATION',
      message: 'STATUSに不正な値があります。',
      operationDate: operationDate,
      field: field,
    );
  }

  bool _validTime(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
    if (match == null) return false;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
  }

  StatusReportSyncSource _project(
    _StoredStatusSource current, {
    required String previousOperationDate,
    required _StoredStatusSource? previous,
  }) {
    try {
      final data = current.record.data;
      final previousData = previous?.record.data;
      return StatusReportSyncSource(
        operationDate: current.record.localDate,
        sourceRecordId: current.record.id,
        sourceRecordVersion: current.record.recordVersion,
        body: StatusReportSyncBodySource(
          weightKg: data.weight,
          bodyFatPercent: data.bodyFat,
        ),
        recovery: StatusReportSyncRecoverySource(
          sleepDurationMinutes: data.sleepHours == null
              ? null
              : (data.sleepHours! * 60).round(),
          sleepScore: data.sleepScore,
        ),
        condition: StatusReportSyncConditionSource(
          footPainLevel: data.footPain,
          condition: data.condition,
          notes: data.memo.isEmpty ? null : data.memo,
        ),
        work: StatusReportSyncWorkSource(
          workType: data.workType.name,
          startTime: data.workType.isWorking
              ? _normalizeTime(data.workStart)
              : null,
          endTime: data.workType.isWorking
              ? _normalizeTime(data.workEnd)
              : null,
          breakDurationMinutes: data.workType.isWorking
              ? _durationMinutes(data.workBreak)
              : null,
          workHours: data.workHours,
        ),
        previousCarryoverConfirmed: data.previousCarryoverConfirmed,
        previousDayComparison: StatusReportSyncPreviousDayComparison(
          previousOperationDate: previousOperationDate,
          previousStatusAvailable: previousData != null,
          weightDifferenceKg:
              previousData?.weight == null || data.weight == null
              ? null
              : _decimalDifference(data.weight!, previousData!.weight!),
          bodyFatDifferencePoint:
              previousData?.bodyFat == null || data.bodyFat == null
              ? null
              : _decimalDifference(data.bodyFat!, previousData!.bodyFat!),
        ),
      );
    } catch (error) {
      if (error is StatusReportSyncSourceException) rethrow;
      throw StatusReportSyncSourceException(
        code: 'statusSourceProjectionFailed',
        stage: 'SOURCE PROJECTION',
        message: 'STATUS Sourceを作成できませんでした。',
        operationDate: current.record.localDate,
      );
    }
  }

  int _durationMinutes(String value) {
    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  String _normalizeTime(String value) {
    final parts = value.split(':');
    return '${parts[0].padLeft(2, '0')}:${parts[1]}';
  }

  String _decimalDifference(double current, double previous) {
    final currentParts = _decimalParts(current.toString());
    final previousParts = _decimalParts(previous.toString());
    final scale = currentParts.scale > previousParts.scale
        ? currentParts.scale
        : previousParts.scale;
    final currentScaled =
        currentParts.value * _power10(scale - currentParts.scale);
    final previousScaled =
        previousParts.value * _power10(scale - previousParts.scale);
    return _formatScaled(currentScaled - previousScaled, scale);
  }

  ({BigInt value, int scale}) _decimalParts(String value) {
    final negative = value.startsWith('-');
    final unsigned = negative ? value.substring(1) : value;
    final parts = unsigned.split('.');
    final fraction = parts.length == 1 ? '' : parts[1];
    final digits = '${parts[0]}$fraction';
    final parsed = BigInt.parse(digits);
    return (value: negative ? -parsed : parsed, scale: fraction.length);
  }

  BigInt _power10(int exponent) => BigInt.from(10).pow(exponent);

  String _formatScaled(BigInt value, int scale) {
    if (value == BigInt.zero) return '0';
    final negative = value.isNegative;
    var digits = value.abs().toString().padLeft(scale + 1, '0');
    if (scale > 0) {
      digits =
          '${digits.substring(0, digits.length - scale)}.'
          '${digits.substring(digits.length - scale)}';
      digits = digits.replaceFirst(RegExp(r'0+$'), '');
      digits = digits.replaceFirst(RegExp(r'\.$'), '');
    }
    return '${negative ? '-' : '+'}$digits';
  }

  String _serializeSource(StatusReportSyncSource source) {
    final comparison = source.previousDayComparison;
    final lines = <String>[
      'OPERATION REBOOT',
      'FORMAT: operation-reboot-status-source',
      'FORMAT VERSION: 1',
      'MODULE: STATUS',
      'OPERATION DATE: ${source.operationDate}',
      'SOURCE RECORD ID: ${source.sourceRecordId}',
      'SOURCE RECORD VERSION: ${source.sourceRecordVersion}',
      '',
      '[BODY]',
      'WEIGHT KG: ${_nullable(source.body.weightKg)}',
      'BODY FAT PERCENT: ${_nullable(source.body.bodyFatPercent)}',
      'PREVIOUS DAY OPERATION DATE: ${comparison.previousOperationDate}',
      'PREVIOUS DAY STATUS AVAILABLE: ${comparison.previousStatusAvailable}',
      'PREVIOUS DAY WEIGHT DIFFERENCE KG: ${_available(comparison.weightDifferenceKg)}',
      'PREVIOUS DAY BODY FAT DIFFERENCE POINT: ${_available(comparison.bodyFatDifferencePoint)}',
      '',
      '[RECOVERY]',
      'SLEEP DURATION MINUTES: ${_nullable(source.recovery.sleepDurationMinutes)}',
      'SLEEP SCORE: ${_nullable(source.recovery.sleepScore)}',
      '',
      '[CONDITION]',
      'FOOT PAIN LEVEL: ${source.condition.footPainLevel}',
      'CONDITION: ${_nullable(source.condition.condition)}',
      'NOTES: ${_nullableText(source.condition.notes)}',
      '',
      '[WORK]',
      'WORK TYPE: ${source.work.workType}',
      'START TIME: ${_nullable(source.work.startTime)}',
      'END TIME: ${_nullable(source.work.endTime)}',
      'BREAK DURATION MINUTES: ${_nullable(source.work.breakDurationMinutes)}',
      'WORK HOURS: ${_number(source.work.workHours)}',
      '',
      '[CARRYOVER]',
      'PREVIOUS CARRYOVER CONFIRMED: ${_nullable(source.previousCarryoverConfirmed)}',
    ];
    return '${lines.join('\n')}\n';
  }

  String _serializeDisplay(
    String canonicalText, {
    required DateTime exportedAt,
    required String sourceDigest,
  }) {
    final lines = canonicalText.trimRight().split('\n');
    final recordVersionIndex = lines.indexWhere(
      (line) => line.startsWith('SOURCE RECORD VERSION:'),
    );
    lines.insertAll(recordVersionIndex + 1, [
      'EXPORTED AT: ${exportedAt.toIso8601String()}',
      'SOURCE DIGEST: $sourceDigest',
    ]);
    return '${lines.join('\n')}\n';
  }

  String _number(num value) => value.toString();
  String _nullable(Object? value) => value == null ? '(null)' : '$value';
  String _nullableText(String? value) {
    if (value == null) return '(null)';
    return value
        .replaceAll('\r\n', r'\n')
        .replaceAll('\r', r'\n')
        .replaceAll('\n', r'\n');
  }

  String _available(String? value) => value ?? '(not available)';
}

class _StoredStatusSource {
  const _StoredStatusSource({required this.record});

  final PersistedStatusRecord record;
}
