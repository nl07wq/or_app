import 'package:flutter/material.dart';

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
              separatorBuilder: (_, __) => AppSpacing.gapMD,
              itemBuilder: (context, index) {
                final record = sessions[index];
                final session = record.session;

                final setCount = session.exercises.fold<int>(
                  0,
                  (sum, exercise) => sum + exercise.sets.length,
                );

                return OperationCard(
                  selectable: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TrainingDetailPage(session: session),
                      ),
                    );
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
                              '${session.exercises.length} Ex   ${setCount} Sets',
                              style: Theme.of(context).textTheme.bodyMedium,
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
                            if (session.cardioEntries.isNotEmpty) ...[
                              AppSpacing.gapMD,
                              Text(
                                'Cardio: ${session.cardioEntries.length}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                'Cardio Time: ${session.cardioEntries.fold<int>(0, (sum, entry) => sum + entry.durationMinutes)} min',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ],
                        ),
                      ),

                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit',
                        onPressed: appInitializationController.value.isReadOnly
                            ? null
                            : () async {
                                final updated = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TrainingEntryPage(
                                      existingSession: session,
                                      recordId: record.id,
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
                        onPressed: appInitializationController.value.isReadOnly
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
