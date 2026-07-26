import 'package:flutter/material.dart';

import '../../core/models/activity_data.dart';
import '../../core/models/bowel_movement_record.dart';
import '../../core/widgets/history/history_delete_dialog.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/widgets/confirmed_log_message.dart';
import '../../core/state/app_initialization_state.dart';
import 'activity_entry_page.dart';
import 'models/activity_summary_state.dart';
import 'repository/activity_repository.dart';

class ActivityHistoryPage extends StatefulWidget {
  const ActivityHistoryPage({super.key});
  @override
  State<ActivityHistoryPage> createState() => _ActivityHistoryPageState();
}

class _ActivityHistoryPageState extends State<ActivityHistoryPage> {
  final _repository = const LocalActivityRepository();
  late Future<List<ActivityData>> _records;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _records = _repository.getAll();

  Future<void> _delete(ActivityData data) async {
    final confirmed = await showHistoryDeleteDialog(
      context,
      title: 'Activity Record',
    );
    if (!confirmed) return;
    try {
      await deleteActivity(data.date);
    } on ConfirmedDailyLogException catch (error) {
      if (mounted) showConfirmedLogMessage(context, error);
      return;
    }
    _reload();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ACTIVITY')),
      body: FutureBuilder<List<ActivityData>>(
        future: _records,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = snapshot.data!;
          if (records.isEmpty) {
            return const Center(child: Text('No Activity Records'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = records[index];
              final previousCarryOver = _findPreviousCarryOver(
                records,
                data.date,
              );
              final officialSteps = data.officialStepsFor(previousCarryOver);

              return OperationCard(
                child: ListTile(
                  title: Text(
                    '${data.date.year}-${data.date.month.toString().padLeft(2, '0')}-${data.date.day.toString().padLeft(2, '0')}',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Official: ${_formatSteps(officialSteps)} steps'),
                      Text(
                        'Measured: ${_formatSteps(data.measuredSteps)} steps',
                      ),
                      if (data.carryOver > 0)
                        Text(
                          'Carry Over added: +${_formatSteps(data.carryOver)} steps',
                        ),
                      if (previousCarryOver > 0)
                        Text(
                          'Previous Carry Over deducted: -${_formatSteps(previousCarryOver)} steps',
                        ),
                      Text(
                        'Bowel: ${_formatBowelMovement(data.bowelMovement)}',
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: appInitializationController.value.isReadOnly
                            ? null
                            : () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ActivityEntryPage(initialData: data),
                                  ),
                                );
                                _reload();
                                setState(() {});
                              },
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: appInitializationController.value.isReadOnly
                            ? null
                            : () => _delete(data),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatSteps(int steps) => steps.toString().replaceAllMapped(
    RegExp(r'(?<!^)(?=(\d{3})+$)'),
    (_) => ',',
  );

  int _findPreviousCarryOver(List<ActivityData> records, DateTime date) {
    final previousDate = DateTime(date.year, date.month, date.day - 1);
    for (final record in records) {
      if (record.date.year == previousDate.year &&
          record.date.month == previousDate.month &&
          record.date.day == previousDate.day) {
        return record.carryOver;
      }
    }
    return 0;
  }

  String _formatBowelMovement(BowelMovementRecord record) {
    return switch (record.status) {
      BowelMovementStatus.unconfirmed => 'Not entered',
      BowelMovementStatus.none => 'None',
      BowelMovementStatus.recorded =>
        record.amount == null
            ? 'Recorded (legacy)'
            : 'Amount ${record.amount}, shape ${record.shape ?? '-'}',
    };
  }
}
