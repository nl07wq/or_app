import 'package:flutter/material.dart';

import '../../core/models/morning_data.dart';
import '../../core/repositories/morning_repository.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Morning History')),
      body: FutureBuilder<List<MorningData>>(
        future: _records,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = snapshot.data!;

          if (records.isEmpty) {
            return const Center(child: Text('No Morning Records'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final data = records[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.date,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),

                      const SizedBox(height: 12),

                      Text('⚖ 体重：${data.weight.toStringAsFixed(1)} kg'),

                      Text('😴 睡眠：${formatTime(data.sleepHours)}'),

                      Text('💼 勤務：${formatTime(data.workHours)}'),

                      Text('📝 メモ：${data.memo.isEmpty ? "なし" : data.memo}'),
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
}
