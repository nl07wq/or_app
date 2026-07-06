import 'package:flutter/material.dart';

import '../../core/models/training_session.dart';
import '../../core/repositories/training_repository.dart';
import '../../core/theme/app_spacing.dart';

import '../../core/widgets/history/history_delete_dialog.dart';
import '../../core/widgets/operation_card.dart';
import 'training_detail_page.dart';

class TrainingHistoryPage extends StatefulWidget {
  const TrainingHistoryPage({super.key});

  @override
  State<TrainingHistoryPage> createState() => _TrainingHistoryPageState();
}

class _TrainingHistoryPageState extends State<TrainingHistoryPage> {
  late Future<List<TrainingSession>> _records;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  void _loadRecords() {
    _records = TrainingRepository.getAll();
  }

  Future<void> _deleteRecord(TrainingSession session) async {
    final result = await showHistoryDeleteDialog(
      context,
      title: 'Training Session',
    );

    if (!result) return;

    await TrainingRepository.remove(session);

    _loadRecords();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Training History')),
      body: Padding(
        padding: AppSpacing.cardPadding,
        child: FutureBuilder<List<TrainingSession>>(
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
                final session = sessions[index];

                final exerciseCount = session.exercises.length;

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
                          ],
                        ),
                      ),

                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        tooltip: 'Delete',
                        onPressed: () {
                          _deleteRecord(session);
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
