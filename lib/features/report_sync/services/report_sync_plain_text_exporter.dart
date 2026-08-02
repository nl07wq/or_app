import '../../../core/models/daily_log_confirmation.dart';
import '../../../core/models/meal_data.dart';
import '../../../core/models/morning_data.dart';
import '../../training/models/training_record_read_model.dart';
import '../models/morning_brief_record.dart';

class ReportSyncPlainTextExporter {
  const ReportSyncPlainTextExporter();

  String training(TrainingRecordReadModel record) => _format(
    sourceName: 'Training Record',
    operationDate: record.localDate,
    values: {
      'recordId': record.id,
      'recordVersion': record.recordVersion,
      'localDate': record.localDate,
      'createdAt': record.createdAt.toUtc().toIso8601String(),
      'updatedAt': record.updatedAt.toUtc().toIso8601String(),
      'session': record.v2Data!.toJson(),
    },
  );

  String food({required String operationDate, required List<MealData> meals}) =>
      _format(
        sourceName: 'Meal Data',
        operationDate: operationDate,
        values: {
          'meals': [for (final meal in meals) meal.toJson()],
        },
      );

  String morning(MorningData value) => _format(
    sourceName: 'Morning Fact',
    operationDate: value.date,
    values: {
      'date': value.date,
      'body': {'weightKg': value.weight, 'bodyFatPercent': value.bodyFat},
      'recovery': {
        'sleepHours': value.sleepHours,
        'sleepScore': value.sleepScore,
      },
      'condition': {
        'footPain': value.footPain,
        'condition': value.condition,
        'previousCarryoverConfirmed': value.previousCarryoverConfirmed,
      },
      'work': {
        'workType': value.workType.name,
        'start': value.workStart,
        'end': value.workEnd,
        'break': value.workBreak,
        'hours': value.workHours,
      },
      'notes': value.memo.isEmpty ? null : value.memo,
    },
  );

  String finalizedDailyData({
    required String operationDate,
    required DailyLogConfirmation confirmation,
    MorningBriefRecord? morningBrief,
  }) => _format(
    sourceName: 'Finalized Daily Data',
    operationDate: operationDate,
    values: {
      'confirmation': confirmation.toJson(),
      'morningBrief': morningBrief == null
          ? null
          : {
              'localDate': morningBrief.localDate,
              'situationAnalysis': morningBrief.situationAnalysis,
              'operationStatus': morningBrief.operationStatus.stableId,
              'commanderIntent': morningBrief.commanderIntent,
              'argoComment': morningBrief.argoComment,
              'strategicResourceDecision':
                  morningBrief.strategicResourceDecision,
              'actions': [
                for (final action in morningBrief.actions) action.toJson(),
              ],
            },
    },
  );

  String _format({
    required String sourceName,
    required String operationDate,
    required Map<String, Object?> values,
  }) {
    final lines = <String>[
      'OPERATION REBOOT',
      'SOURCE: $sourceName',
      'OPERATION DATE: $operationDate',
      '',
    ];
    for (final entry in values.entries) {
      _write(lines, entry.key, entry.value);
    }
    return lines.join('\n').trimRight();
  }

  void _write(List<String> lines, String path, Object? value) {
    if (value is Map) {
      if (value.isEmpty) {
        lines.add('$path: (empty object)');
        return;
      }
      for (final entry in value.entries) {
        _write(lines, '$path.${entry.key}', entry.value);
      }
      return;
    }
    if (value is Iterable) {
      final items = value.toList(growable: false);
      if (items.isEmpty) {
        lines.add('$path: (empty list)');
        return;
      }
      for (var index = 0; index < items.length; index++) {
        _write(lines, '$path[$index]', items[index]);
      }
      return;
    }
    lines.add('$path: ${_scalar(value)}');
  }

  String _scalar(Object? value) {
    if (value == null) return '(null)';
    if (value is String) {
      if (value.isEmpty) return '(empty)';
      return value.replaceAll('\r\n', '\\n').replaceAll('\n', '\\n');
    }
    return value.toString();
  }
}
