import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/morning_data.dart';
import '../repositories/morning_repository.dart';

class MorningRecordService {
  static String export(MorningData data) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data.toRecordJson());
  }

  static void save(MorningData data) {
    MorningRepository.add(data);

    debugPrint(export(data));

    debugPrint('Records: ${MorningRepository.getAll().length}');
  }

  static List<MorningData> load() {
    return MorningRepository.getAll();
  }
}
