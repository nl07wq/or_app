import 'dart:convert';

import '../../report_sync/services/report_sync_canonical_service.dart';
import '../models/dns_archive_models.dart';

class DnsSourceCodec {
  const DnsSourceCodec();

  String encode(DnsSourcePackage package) => jsonEncode(package.toJson());

  DnsSourcePackage decode(String input) {
    final root = _root(input);
    _exact(root, const {
      'format',
      'envelopeVersion',
      'schemaVersion',
      'sourceType',
      'sourcePackageId',
      'createdAt',
      'records',
    });
    if (root['format'] != DnsSourcePackage.format ||
        root['envelopeVersion'] != 1 ||
        root['schemaVersion'] != '1.0' ||
        root['sourceType'] != 'dnsArchive') {
      throw const FormatException('Unsupported DNS source envelope.');
    }
    final records = <DnsSourceRecord>[];
    final ids = <String>{};
    final orders = <int>{};
    for (final raw in _list(root['records'], 'records')) {
      final json = _map(raw, 'record');
      _exact(json, const {
        'sourceRecordId',
        'sourceOrder',
        'reportType',
        'rawText',
      });
      if (json['reportType'] != 'dns') {
        throw const FormatException('Unknown reportType.');
      }
      final id = _string(json['sourceRecordId'], 'sourceRecordId');
      final order = json['sourceOrder'];
      if (order is! int || order < 0 || !ids.add(id) || !orders.add(order)) {
        throw const FormatException('Invalid source identity.');
      }
      records.add(
        DnsSourceRecord(
          sourceRecordId: id,
          sourceOrder: order,
          rawText: _string(json['rawText'], 'rawText'),
        ),
      );
    }
    if (records.isEmpty) {
      throw const FormatException('records must not be empty.');
    }
    records.sort((a, b) => a.sourceOrder.compareTo(b.sourceOrder));
    return DnsSourcePackage(
      sourcePackageId: _string(root['sourcePackageId'], 'sourcePackageId'),
      createdAt: _utc(root['createdAt'], 'createdAt'),
      records: records,
    );
  }

  DnsSourcePackage splitConcatenated({
    required String sourcePackageId,
    required String text,
    required DateTime createdAt,
  }) {
    if (text.trim().isEmpty) {
      throw const FormatException('DNS source text is empty.');
    }
    final boundary = RegExp(
      r'^DNS-(\d{4}-\d{2}-\d{2})(?:\s|$)',
      multiLine: true,
    );
    final matches = boundary.allMatches(text).toList();
    if (matches.isEmpty ||
        text.substring(0, matches.first.start).trim().isNotEmpty) {
      throw const FormatException('recordBoundaryUnclear');
    }
    final records = <DnsSourceRecord>[];
    for (var index = 0; index < matches.length; index++) {
      final match = matches[index];
      final date = match.group(1)!;
      _date(date, 'DNS boundary date');
      final end = index + 1 < matches.length
          ? matches[index + 1].start
          : text.length;
      final rawText = text.substring(match.start, end).trim();
      if (rawText.isEmpty) throw const FormatException('recordBoundaryUnclear');
      records.add(
        DnsSourceRecord(
          sourceRecordId: '$sourcePackageId-$date-${index + 1}',
          sourceOrder: index,
          rawText: rawText,
        ),
      );
    }
    return DnsSourcePackage(
      sourcePackageId: sourcePackageId,
      createdAt: createdAt.toUtc(),
      records: records,
    );
  }
}

class DnsNormalizedCodec {
  static const _dataSections = {
    'body',
    'nutrition',
    'hydration',
    'activity',
    'work',
    'operation',
  };
  static const _fields = <String, Set<String>>{
    'body': {'weightKg', 'bodyFatPercent'},
    'nutrition': {
      'intakeCalories',
      'expenditureCalories',
      'calorieBalance',
      'proteinGrams',
      'fatGrams',
      'carbohydrateGrams',
    },
    'hydration': {'totalMilliliters', 'beverageBreakdown'},
    'activity': {
      'steps',
      'trainingPerformed',
      'trainingSummary',
      'digestiveSummary',
    },
    'work': {'workStatus', 'startTime', 'endTime'},
    'operation': {'operationStatus', 'commanderIntentEvaluation', 'ciSummary'},
  };

  const DnsNormalizedCodec();
  String encode(DnsNormalizedPackage package) => jsonEncode(package.toJson());

  String encodeStandalone(DnsNormalizedPackage package) => jsonEncode({
    'format': DnsNormalizedPackage.format,
    'envelopeVersion': 1,
    'schemaVersion': '1.0',
    'sourceType': 'dnsArchive',
    'generatedAt': package.generatedAt.toUtc().toIso8601String(),
    'records': [
      for (final record in package.records)
        {
          'operationDate': record.operationDate,
          'parseStatus': record.parseStatus.name,
          'data': record.data,
          'warnings': record.warnings
              .map((warning) => warning.toJson())
              .toList(),
          'unmappedFragments': record.unmappedFragments,
        },
    ],
  });

  DnsNormalizedPackage decodeStandalone(String input) {
    final root = _root(input);
    _exact(root, const {
      'format',
      'envelopeVersion',
      'schemaVersion',
      'sourceType',
      'generatedAt',
      'records',
    });
    if (root['format'] != DnsNormalizedPackage.format ||
        root['envelopeVersion'] != 1 ||
        root['schemaVersion'] != '1.0' ||
        root['sourceType'] != 'dnsArchive') {
      throw const FormatException('Unsupported DNS normalized envelope.');
    }
    final generatedAt = _utc(root['generatedAt'], 'generatedAt');
    final sourcePackageId =
        'dns-response-${ReportSyncCanonicalService.digest(root).substring(0, 24)}';
    final records = <DnsNormalizedRecord>[];
    final dates = <String>{};
    for (final raw in _list(root['records'], 'records')) {
      final json = _map(raw, 'record');
      _exact(json, const {
        'operationDate',
        'parseStatus',
        'data',
        'warnings',
        'unmappedFragments',
      });
      final status = DnsParseStatus.values.byName(
        _string(json['parseStatus'], 'parseStatus'),
      );
      final operationDate = json['operationDate'] == null
          ? null
          : _date(json['operationDate'], 'operationDate');
      if (status != DnsParseStatus.blocked && operationDate == null) {
        throw const FormatException(
          'operationDate is required for parsed records.',
        );
      }
      if (operationDate != null && !dates.add(operationDate)) {
        throw const FormatException('Duplicate operationDate.');
      }
      records.add(
        DnsNormalizedRecord(
          sourceRecordId:
              'dns-${operationDate ?? 'blocked'}-${ReportSyncCanonicalService.digest(json).substring(0, 16)}',
          operationDate: operationDate,
          parseStatus: status,
          data: _validateData(_map(json['data'], 'data')),
          warnings: _list(json['warnings'], 'warnings')
              .map((value) => DnsWarning.fromJson(_map(value, 'warning')))
              .toList(),
          unmappedFragments: _list(
            json['unmappedFragments'],
            'unmappedFragments',
          ).map((value) => _string(value, 'fragment')).toList(),
        ),
      );
    }
    if (records.isEmpty) {
      throw const FormatException('records must not be empty.');
    }
    return DnsNormalizedPackage(
      sourcePackageId: sourcePackageId,
      generatedAt: generatedAt,
      records: records,
    );
  }

  DnsNormalizedPackage decode(String input) {
    final root = _root(input);
    _exact(root, const {
      'format',
      'envelopeVersion',
      'schemaVersion',
      'sourceType',
      'sourcePackageId',
      'generatedAt',
      'records',
    });
    if (root['format'] != DnsNormalizedPackage.format ||
        root['envelopeVersion'] != 1 ||
        root['schemaVersion'] != '1.0' ||
        root['sourceType'] != 'dnsArchive') {
      throw const FormatException('Unsupported DNS normalized envelope.');
    }
    final records = <DnsNormalizedRecord>[];
    final ids = <String>{};
    for (final raw in _list(root['records'], 'records')) {
      final json = _map(raw, 'record');
      _exact(json, const {
        'sourceRecordId',
        'operationDate',
        'parseStatus',
        'data',
        'warnings',
        'unmappedFragments',
      });
      final id = _string(json['sourceRecordId'], 'sourceRecordId');
      if (!ids.add(id)) {
        throw const FormatException('Duplicate sourceRecordId.');
      }
      final status = DnsParseStatus.values.byName(
        _string(json['parseStatus'], 'parseStatus'),
      );
      final operationDate = json['operationDate'] == null
          ? null
          : _date(json['operationDate'], 'operationDate');
      final data = _validateData(_map(json['data'], 'data'));
      final warnings = _list(
        json['warnings'],
        'warnings',
      ).map((value) => DnsWarning.fromJson(_map(value, 'warning'))).toList();
      final fragments = _list(
        json['unmappedFragments'],
        'unmappedFragments',
      ).map((value) => _string(value, 'fragment')).toList();
      if (status != DnsParseStatus.blocked && operationDate == null) {
        throw const FormatException(
          'operationDate is required for parsed records.',
        );
      }
      records.add(
        DnsNormalizedRecord(
          sourceRecordId: id,
          operationDate: operationDate,
          parseStatus: status,
          data: data,
          warnings: warnings,
          unmappedFragments: fragments,
        ),
      );
    }
    return DnsNormalizedPackage(
      sourcePackageId: _string(root['sourcePackageId'], 'sourcePackageId'),
      generatedAt: _utc(root['generatedAt'], 'generatedAt'),
      records: records,
    );
  }

  Map<String, Object?> _validateData(Map<String, Object?> data) {
    _exact(data, _dataSections);
    return {
      for (final section in _dataSections)
        section: data[section] == null
            ? null
            : _validateSection(section, _map(data[section], section)),
    };
  }

  Map<String, Object?> _validateSection(
    String section,
    Map<String, Object?> data,
  ) {
    _exact(data, _fields[section]!);
    return {
      for (final entry in data.entries)
        entry.key: _validateValue(
          entry.value,
          '$section.${entry.key}',
          numeric: _numericFields.contains('$section.${entry.key}'),
          boolean: '$section.${entry.key}' == 'activity.trainingPerformed',
        ),
    };
  }

  static const _numericFields = {
    'body.weightKg',
    'body.bodyFatPercent',
    'nutrition.intakeCalories',
    'nutrition.expenditureCalories',
    'nutrition.calorieBalance',
    'nutrition.proteinGrams',
    'nutrition.fatGrams',
    'nutrition.carbohydrateGrams',
    'hydration.totalMilliliters',
    'activity.steps',
  };

  Object? _validateValue(
    Object? value,
    String name, {
    required bool numeric,
    required bool boolean,
  }) {
    if (value == null) return null;
    if (numeric && value is Map) {
      return DnsNumericValue.fromJson(
        Map<String, Object?>.from(value),
      ).toJson();
    }
    if (numeric) throw FormatException('$name must be a numeric value object.');
    if (boolean && value is bool) return value;
    if (boolean) throw FormatException('$name must be a boolean.');
    if (value is String) return value;
    if (value is List &&
        value.every((entry) => entry is String && entry.trim().isNotEmpty)) {
      return List<String>.from(value);
    }
    throw FormatException('$name is invalid.');
  }
}

Map<String, Object?> _root(String input) {
  final Object? value;
  try {
    value = jsonDecode(input);
  } on FormatException {
    rethrow;
  }
  return _map(value, 'root');
}

void _exact(Map<String, Object?> json, Set<String> fields) {
  if (json.keys.toSet().difference(fields).isNotEmpty ||
      fields.difference(json.keys.toSet()).isNotEmpty) {
    throw const FormatException('Unknown or missing field.');
  }
}

Map<String, Object?> _map(Object? value, String name) {
  if (value is! Map) throw FormatException('$name must be an object.');
  return Map<String, Object?>.from(value);
}

List<Object?> _list(Object? value, String name) {
  if (value is! List) throw FormatException('$name must be an array.');
  return value.cast<Object?>();
}

String _string(Object? value, String name) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$name is invalid.');
  }
  return value;
}

String _date(Object? value, String name) {
  final text = _string(value, name);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ||
      DateTime.tryParse(
            '${text}T00:00:00Z',
          )?.toIso8601String().substring(0, 10) !=
          text) {
    throw FormatException('$name is invalid.');
  }
  return text;
}

DateTime _utc(Object? value, String name) {
  final date = value is String ? DateTime.tryParse(value) : null;
  if (date == null || !date.isUtc) throw FormatException('$name must be UTC.');
  return date;
}
