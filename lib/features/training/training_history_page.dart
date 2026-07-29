import 'package:flutter/material.dart';

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
import 'models/persisted_training_record.dart';
import 'services/training_v2_statistics_service.dart';

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
    final result = await showHistoryDeleteDialog(
      context,
      title: 'Training Session',
    );

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
    return Scaffold(
      appBar: AppBar(title: const Text('TRAINING')),
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
                        .map((exercise) => exercise.equipment?.name)
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
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.date.split('T').first,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),

                            AppSpacing.gapSM,

                            Text(
                              v2 == null
                                  ? '${readModel.exerciseCount} Ex   '
                                        '${readModel.setCount} Legacy Sets'
                                  : '${readModel.exerciseCount} Ex   '
                                        '$mainSetCount Main Sets',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (v2 != null &&
                                (warmUpSetCount > 0 || legacySetCount > 0))
                              Text(
                                '$warmUpSetCount Warm-up   '
                                '$legacySetCount Legacy',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            if (equipmentNames.isNotEmpty) ...[
                              AppSpacing.gapSM,
                              Text(
                                equipmentNames.join(' / '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            if (v2?.sessionGrade != null)
                              Text(
                                'Grade ${v2!.sessionGrade!.displayLabel}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),

                            if (session.memo.isNotEmpty) ...[
                              AppSpacing.gapSM,
                              Text(
                                session.memo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            if (readModel.cardioEntryCount > 0) ...[
                              AppSpacing.gapMD,
                              Text(
                                'Cardio: ${readModel.cardioEntryCount}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (v2 != null)
                                Text(
                                  'Cardio Time: '
                                  '${v2.cardioEntries.fold<int>(0, (sum, entry) => sum + entry.durationSeconds)} sec',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                            ],
                            if (!record.isEditable) ...[
                              AppSpacing.gapSM,
                              Text(
                                'READ ONLY',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ],
                          ],
                        ),
                      ),

                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit',
                        onPressed:
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
                      ),

                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        tooltip: 'Delete',
                        onPressed:
                            appInitializationController.value.isReadOnly ||
                                !record.isEditable
                            ? null
                            : () {
                                _deleteRecord(record);
                              },
                      ),
                    ],
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
