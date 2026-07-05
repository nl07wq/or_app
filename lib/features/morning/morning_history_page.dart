import 'package:flutter/material.dart';

import '../../core/models/morning_data.dart';
import '../../core/repositories/morning_repository.dart';

import '../../core/theme/app_spacing.dart';

import '../../core/widgets/history/history_delete_dialog.dart';
import '../../core/widgets/operation_card.dart';

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
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;

    return '$h時間$m分';
  }

  Future<void> _deleteRecord(MorningData data) async {
    final result = await showHistoryDeleteDialog(
      context,
      title: 'Morning Fact',
    );

    if (!result) return;

    await MorningRepository.remove(data);

    _loadRecords();

    setState(() {});
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            data.date.split('T').first,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            tooltip: 'Delete',
                            onPressed: () {
                              _deleteRecord(data);
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Text('⚖ 体重：${data.weight.toStringAsFixed(1)} kg'),
                      Text('📊 体脂肪：${data.bodyFat.toStringAsFixed(1)} %'),
                      Text('😴 睡眠：${formatTime(data.sleepHours)}'),
                      Text('💯 睡眠スコア：${data.sleepScore}'),
                      Text('🦶 足底筋膜炎：${data.footPain}'),
                      Text('🚽 排便量：${data.bowelAmount}'),
                      Text('🧻 排便形状：${data.bowelShape}'),
                      Text('💼 勤務区分：${data.workType.label}'),
                      Text('⏰ 勤務時間：${formatTime(data.workHours)}'),
                      Text('📝 メモ：${data.memo.isEmpty ? "なし" : data.memo}'),
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
