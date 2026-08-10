import 'package:flutter/material.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../repositories/app_repository_container.dart';
import '../models/daily_aggregate_v1.dart';
import '../repository/daily_aggregate_repository.dart';

class DailyAggregateRecordsPage extends StatefulWidget {
  final DailyAggregateRepository? repository;

  const DailyAggregateRecordsPage({super.key, this.repository});

  @override
  State<DailyAggregateRecordsPage> createState() =>
      _DailyAggregateRecordsPageState();
}

class _DailyAggregateRecordsPageState extends State<DailyAggregateRecordsPage> {
  late final DailyAggregateRepository _repository;
  late Future<List<DailyAggregateV1>> _records;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? AppRepositoryRegistry.container.dailyAggregates;
    _reload();
  }

  void _reload() {
    _records = _repository.getRange('0000-01-01', '9999-12-31').then((records) {
      final sorted = records.toList()
        ..sort(
          (first, second) =>
              second.operationDate.compareTo(first.operationDate),
        );
      return List.unmodifiable(sorted);
    });
  }

  Future<void> _open(DailyAggregateV1 aggregate) async {
    final changed = await Navigator.pushNamed(
      context,
      AppRoutes.dailyAggregateDetail,
      arguments: aggregate.operationDate,
    );
    if (changed == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('DAILY AGGREGATE RECORDS')),
    body: FutureBuilder<List<DailyAggregateV1>>(
      future: _records,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Text('Daily Aggregateを読み込めませんでした。'));
        }
        final records = snapshot.requireData;
        return ListView(
          padding: AppSpacing.cardPadding,
          children: [
            const SectionHeader(
              icon: Icons.inventory_2_outlined,
              title: 'DAILY AGGREGATE RECORDS',
            ),
            AppSpacing.gapSM,
            const Text('保存済みDaily Aggregateの正式内容とSourceを確認します。'),
            AppSpacing.gapLG,
            if (records.isEmpty)
              const OperationCard(child: Text('保存済みRecordはありません。'))
            else
              for (var index = 0; index < records.length; index++) ...[
                _AggregateRow(
                  aggregate: records[index],
                  onTap: () => _open(records[index]),
                ),
                if (index != records.length - 1) AppSpacing.gapSM,
              ],
          ],
        );
      },
    ),
  );
}

class _AggregateRow extends StatelessWidget {
  final DailyAggregateV1 aggregate;
  final VoidCallback onTap;

  const _AggregateRow({required this.aggregate, required this.onTap});

  @override
  Widget build(BuildContext context) => OperationCard(
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.article_outlined),
      title: Text(aggregate.operationDate),
      subtitle: Text('Source Type  ${aggregate.sourceType.name}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class DailyAggregateDetailPage extends StatefulWidget {
  final String operationDate;
  final DailyAggregateRepository? repository;

  const DailyAggregateDetailPage({
    super.key,
    required this.operationDate,
    this.repository,
  });

  @override
  State<DailyAggregateDetailPage> createState() =>
      _DailyAggregateDetailPageState();
}

class _DailyAggregateDetailPageState extends State<DailyAggregateDetailPage> {
  late final DailyAggregateRepository _repository;
  late Future<DailyAggregateV1?> _record;
  bool _deleting = false;
  String? _deleteError;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? AppRepositoryRegistry.container.dailyAggregates;
    _record = _repository.getByDate(widget.operationDate);
  }

  Future<void> _delete(DailyAggregateV1 aggregate) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DELETE DAILY AGGREGATE'),
        content: Text(
          'Operation Date: ${aggregate.operationDate}\n\n'
          'Daily Aggregateのみを削除します。STATUS / FOOD / ACTIVITY / '
          'TRAINING等のSource Recordは削除しません。\n\n'
          '${aggregate.sourceType == DailyAggregateSourceType.records ? 'Source Recordが残るため、再度FINALIZEまたは再生成した場合はDaily Aggregateが再作成される可能性があります。' : 'Historical DNSのSourceやImport履歴は削除しません。'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() {
      _deleting = true;
      _deleteError = null;
    });
    try {
      final existing = await _repository.getByDate(aggregate.operationDate);
      if (existing == null) {
        throw StateError('削除対象のDaily Aggregateが存在しません。');
      }
      await _repository.deleteByDate(aggregate.operationDate);
      if (await _repository.getByDate(aggregate.operationDate) != null) {
        throw StateError('Daily Aggregateの削除Read-backに失敗しました。');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _deleteError = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('DAILY AGGREGATE DETAIL')),
    body: FutureBuilder<DailyAggregateV1?>(
      future: _record,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Daily Aggregateを読み込めませんでした。'));
        }
        final aggregate = snapshot.data;
        if (aggregate == null) {
          return const Center(child: Text('Daily Aggregateが存在しません。'));
        }
        return ListView(
          padding: AppSpacing.cardPadding,
          children: [
            const SectionHeader(
              icon: Icons.article_outlined,
              title: 'DAILY AGGREGATE DETAIL',
            ),
            AppSpacing.gapSM,
            Text(aggregate.operationDate),
            AppSpacing.gapLG,
            _DetailSection(
              title: 'BODY',
              fields: {
                'Weight Kg': aggregate.weightKg,
                'Body Fat Percent': aggregate.bodyFatPercent,
              },
            ),
            _DetailSection(
              title: 'RECOVERY',
              fields: {
                'Sleep Duration Minutes': aggregate.sleepDurationMinutes,
                'Sleep Score': aggregate.sleepScore,
                'Sleep Type': aggregate.sleepType?.name,
              },
            ),
            _DetailSection(
              title: 'CONDITION',
              fields: {
                'Plantar Fasciitis Level': aggregate.plantarFasciitisLevel,
              },
              children: [
                _StringListField(
                  label: 'Condition Fact Summary',
                  values: aggregate.conditionFactSummary,
                ),
              ],
            ),
            _DetailSection(
              title: 'WORK',
              fields: {
                'Work Start Time': aggregate.workStartTime,
                'Work End Time': aggregate.workEndTime,
                'Work Break Minutes': aggregate.workBreakMinutes,
                'Actual Work Minutes': aggregate.actualWorkMinutes,
              },
            ),
            _DetailSection(
              title: 'NUTRITION',
              fields: {
                'Intake Calories Kcal': aggregate.intakeCaloriesKcal,
                'Estimated Expenditure Kcal':
                    aggregate.estimatedExpenditureKcal,
                'Estimated Calorie Balance Kcal':
                    aggregate.estimatedCalorieBalanceKcal,
                'Protein G': aggregate.proteinG,
                'Fat G': aggregate.fatG,
                'Carbs G': aggregate.carbsG,
              },
            ),
            _DetailSection(
              title: 'HYDRATION',
              fields: {'Hydration Ml': aggregate.hydrationMl},
            ),
            _DetailSection(
              title: 'ACTIVITY',
              fields: {
                'Official Steps': aggregate.officialSteps,
                'Measured Steps': aggregate.measuredSteps,
                'Training Performed': aggregate.trainingPerformed,
              },
            ),
            _DetailSection(
              title: 'DIGESTIVE',
              fields: {'Digestive Count': aggregate.digestiveCount},
              children: [
                _DigestiveEventsField(events: aggregate.digestiveEvents),
              ],
            ),
            _DetailSection(
              title: 'OPERATION',
              fields: {'Operation Status': aggregate.operationStatus},
            ),
            _DetailSection(
              title: 'SOURCE',
              fields: {
                'Operation Date': aggregate.operationDate,
                'Source Type': aggregate.sourceType.name,
              },
            ),
            AppSpacing.gapMD,
            if (_deleteError != null)
              Text(
                _deleteError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_deleteError != null) AppSpacing.gapSM,
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('DELETE DAILY AGGREGATE'),
                ),
                onPressed: _deleting ? null : () => _delete(aggregate),
              ),
            ),
            AppSpacing.gapLG,
          ],
        );
      },
    ),
  );
}

class _DetailSection extends StatelessWidget {
  final String title;
  final Map<String, Object?> fields;
  final List<Widget> children;

  const _DetailSection({
    required this.title,
    required this.fields,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          AppSpacing.gapSM,
          for (final entry in fields.entries)
            _FieldRow(label: entry.key, value: entry.value),
          ...children,
        ],
      ),
    ),
  );
}

class _FieldRow extends StatelessWidget {
  final String label;
  final Object? value;

  const _FieldRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(_displayValue(value), textAlign: TextAlign.end)),
      ],
    ),
  );
}

class _StringListField extends StatelessWidget {
  final String label;
  final List<String> values;

  const _StringListField({required this.label, required this.values});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      AppSpacing.gapXS,
      if (values.isEmpty)
        const Text('なし')
      else
        for (final value in values) Text('• $value'),
    ],
  );
}

class _DigestiveEventsField extends StatelessWidget {
  final List<DailyAggregateDigestiveEventV1> events;

  const _DigestiveEventsField({required this.events});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Digestive Events'),
      AppSpacing.gapXS,
      if (events.isEmpty)
        const Text('なし')
      else
        for (var index = 0; index < events.length; index++) ...[
          Text('Event ${index + 1}'),
          _FieldRow(label: 'Amount', value: events[index].amount),
          _FieldRow(label: 'Shape', value: events[index].shape),
          _FieldRow(label: 'Relief', value: events[index].relief),
        ],
    ],
  );
}

String _displayValue(Object? value) {
  if (value == null) return '—';
  if (value is bool) return value ? 'true' : 'false';
  return '$value';
}
