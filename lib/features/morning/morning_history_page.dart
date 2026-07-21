import 'package:flutter/material.dart';

import '../../core/models/morning_data.dart';
import '../../core/repositories/morning_repository.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/widgets/confirmed_log_message.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/history/history_delete_dialog.dart';
import '../../core/widgets/operation_card.dart';

import 'models/morning_fact_state.dart';
import 'morning_fact_page.dart';

class MorningHistoryPage extends StatefulWidget {
  const MorningHistoryPage({super.key});

  @override
  State<MorningHistoryPage> createState() => _MorningHistoryPageState();
}

class _MorningHistoryPageState extends State<MorningHistoryPage> {
  late Future<List<MorningData>> _records;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  void _loadRecords() {
    _records = MorningRepository.getAll();
  }

  String formatTime(double hours) {
    final totalMinutes = (hours * 60).round();
    final hour = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;

    return '$hour時間$minute分';
  }

  Future<void> _deleteRecord(MorningData data) async {
    final result = await showHistoryDeleteDialog(
      context,
      title: 'Morning Fact',
    );

    if (!result) return;

    try { await DailyLogMutationGuard.assertDateMutable(DateTime.parse(data.date)); await MorningRepository.remove(data); } on ConfirmedDailyLogException catch (error) { if (mounted) showConfirmedLogMessage(context, error); return; }
    await refreshMorningFact();

    _loadRecords();
    setState(() {});
  }

  Future<void> _editRecord(MorningData data) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MorningFactPage(data: data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Morning History')),
      body: Padding(
        padding: AppSpacing.cardPadding,
        child: FutureBuilder<List<MorningData>>(
          future: _records,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final records = snapshot.data!;

            if (records.isEmpty) {
              return const Center(child: Text('No Morning Records'));
            }

            return ListView.separated(
              itemCount: records.length,
              separatorBuilder: (_, __) => AppSpacing.gapMD,
              itemBuilder: (context, index) {
                final data = records[index];

                return OperationCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              data.date.split('T').first,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Edit',
                            onPressed: () => _editRecord(data),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            tooltip: 'Delete',
                            onPressed: () => _deleteRecord(data),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _HistoryDetailRow(
                        icon: Icons.monitor_weight_outlined,
                        label: '体重',
                        value: '${data.weight.toStringAsFixed(1)} kg',
                      ),
                      _HistoryDetailRow(
                        icon: Icons.percent,
                        label: '体脂肪',
                        value: '${data.bodyFat.toStringAsFixed(1)} %',
                      ),
                      _HistoryDetailRow(
                        icon: Icons.bedtime_outlined,
                        label: '睡眠',
                        value: formatTime(data.sleepHours),
                      ),
                      _HistoryDetailRow(
                        icon: Icons.speed,
                        label: '睡眠スコア',
                        value: '${data.sleepScore}',
                      ),
                      _HistoryDetailRow(
                        icon: Icons.directions_walk,
                        label: '足底筋膜炎',
                        value: '${data.footPain}',
                      ),
                      _HistoryDetailRow(
                        icon: Icons.check_circle_outline,
                        label: '排便量',
                        value: '${data.bowelAmount}',
                      ),
                      _HistoryDetailRow(
                        icon: Icons.health_and_safety_outlined,
                        label: '排便形状',
                        value: '${data.bowelShape}',
                      ),
                      _HistoryDetailRow(
                        icon: Icons.work_outline,
                        label: '勤務区分',
                        value: data.workType.label,
                      ),
                      if (data.workType.isWorking) ...[
                        _HistoryDetailRow(
                          icon: Icons.login,
                          label: '勤務開始',
                          value: data.workStart,
                        ),
                        _HistoryDetailRow(
                          icon: Icons.logout,
                          label: '勤務終了',
                          value: data.workEnd,
                        ),
                        _HistoryDetailRow(
                          icon: Icons.pause_circle_outline,
                          label: '休憩',
                          value: data.workBreak,
                        ),
                        _HistoryDetailRow(
                          icon: Icons.timer_outlined,
                          label: '勤務時間',
                          value: formatTime(data.workHours),
                        ),
                      ],
                      _HistoryDetailRow(
                        icon: Icons.note_outlined,
                        label: 'メモ',
                        value: data.memo.isEmpty ? 'なし' : data.memo,
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

class _HistoryDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HistoryDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('$label: $value')),
        ],
      ),
    );
  }
}
