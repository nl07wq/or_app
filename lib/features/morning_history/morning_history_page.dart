import 'package:flutter/material.dart';

import '../../core/repositories/morning_repository.dart';

class MorningHistoryPage extends StatelessWidget {
  const MorningHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final records = MorningRepository.getAll();

    return Scaffold(
      appBar: AppBar(title: const Text('Morning History')),
      body: ListView.builder(
        itemCount: records.length,
        itemBuilder: (context, index) {
          final data = records[index];

          return ListTile(
            title: Text('${data.date}'),
            subtitle: Text('${data.weight}kg / ${data.sleepHours}h'),
          );
        },
      ),
    );
  }
}
