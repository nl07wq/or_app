import 'package:flutter/material.dart';

import '../../core/repositories/morning_repository.dart';

class MorningHistoryPage extends StatelessWidget {
  const MorningHistoryPage({super.key});

  String formatTime(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;

    return '$h時間$m分';
  }

  @override
  Widget build(BuildContext context) {
    final records = MorningRepository.getAll();

    return Scaffold(
      appBar: AppBar(title: const Text('Morning History')),
      body: ListView.builder(
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
      ),
    );
  }
}
