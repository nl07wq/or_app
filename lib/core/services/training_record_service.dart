import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/training_data.dart';
import '../repositories/training_repository.dart';

class TrainingRecordService {
  static void save(TrainingData data) {
    TrainingRepository.add(data);

    const encoder = JsonEncoder.withIndent('  ');

    debugPrint(encoder.convert(data.toRecordJson()));

    debugPrint('Training Records: ${TrainingRepository.getAll().length}');
  }
}
