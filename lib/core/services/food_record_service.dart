import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/food_data.dart';
import '../repositories/food_repository.dart';

class FoodRecordService {
  static void save(FoodData data) {
    FoodRepository.add(data);

    const encoder = JsonEncoder.withIndent('  ');

    debugPrint(encoder.convert(data.toRecordJson()));

    debugPrint('Food Records: ${FoodRepository.getAll().length}');
  }

  static Future<List<FoodData>> load() async {
    return FoodRepository.getAll();
  }

  static void delete(FoodData data) {
    FoodRepository.remove(data);
  }
}
