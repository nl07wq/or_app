import 'package:flutter/foundation.dart';

import '../../../core/models/morning_data.dart';
import '../../../core/repositories/morning_repository.dart';
import 'morning_fact.dart';

final ValueNotifier<MorningFact?> morningFactNotifier =
    ValueNotifier<MorningFact?>(null);

Future<void> refreshMorningFact() async {
  final records = await MorningRepository.getAll();
  final today = DateTime.now().toIso8601String().split('T').first;
  MorningData? latestRecord;

  for (final record in records) {
    if (record.date.split('T').first != today) {
      continue;
    }

    if (latestRecord == null ||
        DateTime.parse(record.date).isAfter(DateTime.parse(latestRecord.date))) {
      latestRecord = record;
    }
  }

  morningFactNotifier.value = latestRecord == null
      ? null
      : MorningFact(
          date: DateTime.parse(latestRecord.date),
          weight: latestRecord.weight,
          bodyFat: latestRecord.bodyFat,
          sleepDuration:
              Duration(minutes: (latestRecord.sleepHours * 60).round()),
          workHours: latestRecord.workHours,
          bowelMovement: latestRecord.bowelAmount > 0,
          footPain: latestRecord.footPain,
          medications: const [],
          freeNotes: latestRecord.memo.isEmpty ? null : latestRecord.memo,
        );
}
