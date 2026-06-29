import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/morning_data.dart';
import '../repositories/morning_repository.dart';

class MorningRecordService {
  static String export(MorningData data) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data.toRecordJson());
  }

  static Future<void> save(MorningData data) async {
    await MorningRepository.add(data);

    debugPrint(export(data));
    debugPrint('Records: ${MorningRepository.getAll().length}');
  }

  static Future<List<MorningData>> load() async {
    await MorningRepository.load();
    return MorningRepository.getAll();
  }

  static Future<void> clear() async {
    await MorningRepository.clear();
  }
}
