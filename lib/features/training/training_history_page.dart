import 'package:flutter/material.dart';

import 'package:or_app/core/widgets/global_touch_ripple.dart';

import '../../core/models/training_set_v2.dart';
import '../../core/repositories/training_repository.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/widgets/confirmed_log_message.dart';
import '../../core/theme/app_spacing.dart';

import '../../core/widgets/history/history_delete_dialog.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/state/app_initialization_state.dart';
import 'training_detail_page.dart';
import 'training_entry_page.dart';
import 'models/training_summary_state.dart';
import 'services/training_equipment_candidates.dart';
import 'models/persisted_training_record.dart';
import 'services/training_v2_statistics_service.dart';
import 'widgets/training_dot_matrix_title.dart';
import 'widgets/training_led_back_button.dart';
import 'widgets/training_kinetic_scaffold.dart';

class TrainingHistoryPage extends StatefulWidget {
  const TrainingHistoryPage({super.key});

  @override
  State<TrainingHistoryPage> createState() => _TrainingHistoryPageState();
}

class _TrainingHistoryPageState extends State<TrainingHistoryPage> {
  late Future<List<TrainingRecord>> _records;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  void _loadRecords() {
    _records = TrainingRepository.getRecords();
  }

  Future<void> _deleteRecord(TrainingRecord record) async {
    if (!record.isEditable) return;
    final result = await showHistoryDeleteDialog(context, title: '運動記録');

    if (!result) return;

    try {
      await DailyLogMutationGuard.assertDateMutable(
        DateTime.parse(record.session.date),
      );
      await TrainingRepository.deleteById(record.id);
    } on ConfirmedDailyLogException catch (error) {
      if (mounted) showConfirmedLogMessage(context, error);
      return;
    }
    await refreshTrainingSummary();

    _loadRecords();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TrainingKineticScaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? const TrainingLedBackButton()
            : null,
        title: const TrainingDotMatrixTitle(title: 'TRAINING RECORD'),
      ),
      body: Padding(
        padding: AppSpacing.cardPadding,
        child: FutureBuilder<List<TrainingRecord>>(
          future: _records,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final sessions = snapshot.data!;

            if (sessions.isEmpty) {
              return const Center(child: Text('No Training Records'));
            }

            return ListView.separated(
              itemCount: sessions.length,
              separatorBuilder: (_, _) => AppSpacing.gapMD,
              itemBuilder: (context, index) {
                final record = sessions[index];
                final readModel = record.readModel;
                final session = record.session;
                final v2 = readModel.v2Data;
                final mainSetCount =
                    v2?.exercises.fold<int>(
                      0,
                      (sum, exercise) =>
                          sum +
                          TrainingV2StatisticsService.calculate(
                            exercise,
                          ).mainSetCount,
                    ) ??
                    0;
                final warmUpSetCount =
                    v2?.exercises.fold<int>(
                      0,
                      (sum, exercise) =>
                          sum +
                          exercise.sets
                              .where(
                                (set) => set.setType == TrainingSetType.warmUp,
                              )
                              .length,
                    ) ??
                    0;
                final legacySetCount =
                    v2?.exercises.fold<int>(
                      0,
                      (sum, exercise) =>
                          sum +
                          exercise.sets
                              .where(
                                (set) =>
                                    set.setType ==
                                    TrainingSetType.legacyUnknown,
                              )
                              .length,
                    ) ??
                    0;
                final equipmentNames =
                    v2?.exercises
                        .map(
                          (exercise) => exercise.equipment == null
                              ? null
                              : trainingEquipmentDisplayLabel(
                                  exercise.equipment!,
                                ),
                        )
                        .whereType<String>()
                        .toSet()
                        .toList() ??
                    const <String>[];

                return OperationCard(
                  selectable: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TrainingDetailPage(record: record),
                      ),
                    ).then((updated) {
                      if (updated == true && mounted) {
                        _loadRecords();
                        setState(() {});
                      }
                    });
                  },
                  child: _TrainingRecordPlate(
                    date: session.date.split('T').first,
                    exerciseCount: readModel.exerciseCount,
                    mainSetCount: v2 == null
                        ? readModel.setCount
                        : mainSetCount,
                    warmUpSetCount: warmUpSetCount,
                    legacySetCount: v2 == null
                        ? readModel.setCount
                        : legacySetCount,
                    equipmentNames: equipmentNames,
                    grade: v2?.sessionGrade?.displayLabel,
                    memo: session.memo,
                    cardioCount: readModel.cardioEntryCount,
                    cardioSeconds: v2?.cardioEntries.fold<int>(
                      0,
                      (sum, entry) => sum + entry.durationSeconds,
                    ),
                    readOnly: !record.isEditable,
                    onEdit:
                        appInitializationController.value.isReadOnly ||
                            !record.isEditable
                        ? null
                        : () async {
                            final updated = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TrainingEntryPage(
                                  existingRecord: readModel,
                                ),
                              ),
                            );
                            if (updated == true && mounted) {
                              _loadRecords();
                              setState(() {});
                            }
                          },
                    onDelete:
                        appInitializationController.value.isReadOnly ||
                            !record.isEditable
                        ? null
                        : () => _deleteRecord(record),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _TrainingRecordPlate extends StatelessWidget {
  const _TrainingRecordPlate({
    required this.date,
    required this.exerciseCount,
    required this.mainSetCount,
    required this.warmUpSetCount,
    required this.legacySetCount,
    required this.equipmentNames,
    required this.grade,
    required this.memo,
    required this.cardioCount,
    required this.cardioSeconds,
    required this.readOnly,
    required this.onEdit,
    required this.onDelete,
  });
  final String date;
  final int exerciseCount,
      mainSetCount,
      warmUpSetCount,
      legacySetCount,
      cardioCount;
  final List<String> equipmentNames;
  final String? grade;
  final String memo;
  final int? cardioSeconds;
  final bool readOnly;
  final VoidCallback? onEdit, onDelete;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(date, style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: onEdit,
          ).actionableFeedback(),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            tooltip: 'Delete',
            onPressed: onDelete,
          ).actionableFeedback(),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _TrainingMetric(label: 'EXERCISES', value: '$exerciseCount'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TrainingMetric(label: 'MAIN SETS', value: '$mainSetCount'),
          ),
        ],
      ),
      const SizedBox(height: 10),
      _TrainingLine('WARM-UP / LEGACY', '$warmUpSetCount / $legacySetCount'),
      if (equipmentNames.isNotEmpty)
        _TrainingLine('SESSION DETAILS', equipmentNames.join(' / ')),
      if (grade != null) _TrainingLine('SESSION GRADE', grade!),
      _TrainingLine('CARDIO', '$cardioCount'),
      if (cardioSeconds != null)
        _TrainingLine('CARDIO TIME', '$cardioSeconds sec'),
      if (memo.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          'MEMO',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(letterSpacing: 1),
        ),
        const SizedBox(height: 3),
        Text(memo, style: Theme.of(context).textTheme.bodyMedium),
      ],
      if (readOnly)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'READ ONLY',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
    ],
  );
}

class _TrainingMetric extends StatelessWidget {
  const _TrainingMetric({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    key: Key('training-record-$label'),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
      ],
    ),
  );
}

class _TrainingLine extends StatelessWidget {
  const _TrainingLine(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(letterSpacing: .7),
        ),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}
