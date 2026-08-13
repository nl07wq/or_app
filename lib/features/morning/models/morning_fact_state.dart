import 'package:flutter/foundation.dart';

import '../../../core/models/morning_data.dart';
import '../../../core/repositories/morning_repository.dart';
import '../../operation_date/services/operation_date_service.dart';
import 'morning_fact.dart';

final ValueNotifier<MorningFact?> morningFactNotifier =
    ValueNotifier<MorningFact?>(null);

Future<void> refreshMorningFact({String? localDate}) async {
  morningFactNotifier.value = await loadMorningFact(localDate: localDate);
}

Future<MorningFact?> loadMorningFact({String? localDate}) async {
  final records = await MorningRepository.getAll();
  final targetLocalDate =
      localDate ?? (await const OperationDateService().current()).value;
  MorningData? latestRecord;

  for (final record in records) {
    if (record.date.split('T').first != targetLocalDate) {
      continue;
    }

    if (latestRecord == null ||
        DateTime.parse(
          record.date,
        ).isAfter(DateTime.parse(latestRecord.date))) {
      latestRecord = record;
    }
  }

  return latestRecord == null
      ? null
      : MorningFact(
          date: DateTime.parse(latestRecord.date),
          weight: latestRecord.weight,
          bodyFat: latestRecord.bodyFat,
          sleepDuration: latestRecord.sleepHours == null
              ? null
              : Duration(minutes: (latestRecord.sleepHours! * 60).round()),
          sleepScore: latestRecord.sleepScore,
          workHours: latestRecord.workHours,
          footPain: latestRecord.footPain,
          condition: latestRecord.condition,
          previousCarryoverConfirmed: latestRecord.previousCarryoverConfirmed,
          medications: const [],
          freeNotes: latestRecord.memo.isEmpty ? null : latestRecord.memo,
        );
}
