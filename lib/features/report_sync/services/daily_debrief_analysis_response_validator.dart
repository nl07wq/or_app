import 'dart:convert';

import '../models/daily_debrief_record.dart';
import '../models/report_sync_issue.dart';

class DailyDebriefAnalysisResponseValidator {
  const DailyDebriefAnalysisResponseValidator();

  DailyDebriefAnalysis decode(String input, {required bool hasMorningBrief}) {
    final normalized = normalize(input);
    final Object? decoded;
    try {
      decoded = jsonDecode(normalized);
    } on FormatException catch (error) {
      throw ReportSyncException(
        ReportSyncIssueCode.schemaMismatch,
        error.message,
      );
    }
    if (decoded is! Map) {
      throw const ReportSyncException(
        ReportSyncIssueCode.schemaMismatch,
        'Daily Debrief analysis root must be an object.',
      );
    }
    return validate(
      Map<String, Object?>.from(decoded),
      hasMorningBrief: hasMorningBrief,
    );
  }

  DailyDebriefAnalysis validate(
    Map<String, Object?> json, {
    required bool hasMorningBrief,
  }) {
    try {
      final analysis = DailyDebriefAnalysis.fromJson(json);
      if (!hasMorningBrief && analysis.commanderIntentEvaluation != null) {
        throw const FormatException(
          'Commander Intent evaluation requires Morning Brief.',
        );
      }
      _maximum(
        analysis.commanderIntentEvaluation?.evidence ?? const [],
        3,
        'commanderIntentEvaluation.evidence',
      );
      _maximum(
        analysis.crossAnalysis.keyFactors,
        2,
        'crossAnalysis.keyFactors',
      );
      _maximum(
        analysis.crossAnalysis.interactions,
        2,
        'crossAnalysis.interactions',
      );
      _maximum(
        analysis.crossAnalysis.constraints,
        2,
        'crossAnalysis.constraints',
      );
      _maximum(analysis.crossAnalysis.resources, 2, 'crossAnalysis.resources');
      _maximum(
        analysis.executionEvaluation.successes,
        3,
        'executionEvaluation.successes',
      );
      _maximum(
        analysis.executionEvaluation.adjustments,
        2,
        'executionEvaluation.adjustments',
      );
      _maximum(
        analysis.nextDayHandoff.watchPoints,
        3,
        'nextDayHandoff.watchPoints',
      );
      return analysis;
    } on ReportSyncException {
      rethrow;
    } catch (error) {
      throw ReportSyncException(
        ReportSyncIssueCode.schemaMismatch,
        error.toString(),
      );
    }
  }

  String normalize(String input) {
    var normalized = input.trim();
    if (normalized.startsWith('\uFEFF')) {
      normalized = normalized.substring(1).trim();
    }
    final fenced = RegExp(
      r'^```(?:text|json)?[ \t]*\r?\n([\s\S]*)\r?\n```$',
    ).firstMatch(normalized);
    if (fenced != null) normalized = fenced.group(1)!.trim();
    return normalized;
  }

  void _maximum(List<String> values, int maximum, String path) {
    if (values.length > maximum) {
      throw FormatException('$path must contain at most $maximum items.');
    }
  }
}
