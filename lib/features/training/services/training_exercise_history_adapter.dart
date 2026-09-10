import 'package:flutter/material.dart';

import 'exercise_name_localization.dart';
import 'equipment_catalog.dart';
import 'training_exercise_identity.dart';
import 'training_history_domain_service.dart';
import 'training_history_overview_adapter.dart';
import '../models/training_record_read_model.dart';

class TrainingExerciseHistoryAdapter {
  const TrainingExerciseHistoryAdapter({
    this.domain = const TrainingHistoryDomainService(),
    this.periods = const TrainingHistoryOverviewAdapter(),
  });

  final TrainingHistoryDomainService domain;
  final TrainingHistoryOverviewAdapter periods;

  List<ExerciseHistoryPoint> points(
    Iterable<TrainingRecordReadModel> records, {
    required TrainingHistoryOverviewPeriod period,
    DateTime? referenceDate,
    DateTimeRange? customRange,
  }) => [
    for (final point in domain.exerciseHistory(records))
      if (periods.includesOperationDate(
        point.operationDate,
        period: period,
        referenceDate: referenceDate,
        customRange: customRange,
      ))
        point,
  ];

  List<TrainingExerciseCategory> categories(
    Iterable<ExerciseHistoryPoint> points,
  ) {
    final latest = <String, ExerciseHistoryPoint>{};
    for (final point in points) {
      final current = latest[point.identity.exerciseKey];
      if (current == null || _dateOf(point).isAfter(_dateOf(current))) {
        latest[point.identity.exerciseKey] = point;
      }
    }
    final values = latest.entries.toList()
      ..sort((a, b) => _dateOf(b.value).compareTo(_dateOf(a.value)));
    return [
      for (final entry in values)
        TrainingExerciseCategory(
          key: entry.key,
          label: exerciseDisplayName(entry.key),
        ),
    ];
  }

  List<TrainingExerciseEquipmentVariant> equipmentVariants(
    Iterable<ExerciseHistoryPoint> points,
    String categoryKey,
  ) {
    final latest = <TrainingExerciseIdentity, ExerciseHistoryPoint>{};
    for (final point in points) {
      if (point.identity.exerciseKey != categoryKey) continue;
      final current = latest[point.identity];
      if (current == null || _dateOf(point).isAfter(_dateOf(current))) {
        latest[point.identity] = point;
      }
    }
    final values = latest.values.toList()
      ..sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));
    return [
      for (final point in values)
        TrainingExerciseEquipmentVariant(
          identity: point.identity,
          label:
              _equipmentLabel(point.identity.equipmentKey) ??
              'EQUIPMENT NOT RECORDED',
        ),
    ];
  }

  List<ExerciseHistoryPoint> forIdentity(
    Iterable<ExerciseHistoryPoint> points,
    TrainingExerciseIdentity identity,
  ) => [
    for (final point in points)
      if (point.identity == identity) point,
  ]..sort((a, b) => _dateOf(a).compareTo(_dateOf(b)));

  TrainingExerciseSelectorPresentation selectorPresentation(
    TrainingExerciseIdentity identity,
  ) => TrainingExerciseSelectorPresentation(
    exerciseLabel: exerciseDisplayName(identity.exerciseKey),
    equipmentLabel: _equipmentLabel(identity.equipmentKey),
  );

  String? _equipmentLabel(String equipmentKey) {
    if (equipmentKey == 'none') return null;
    if (equipmentKey.startsWith('catalog:')) {
      final catalogId = equipmentKey.substring('catalog:'.length);
      final equipment =
          equipmentById(catalogId) ??
          equipmentById(catalogId.replaceAll('-', '_'));
      if (equipment != null) return equipmentDisplayNameJa(equipment);
      return _readableFallback(catalogId);
    }
    if (equipmentKey.startsWith('name:')) {
      final name = equipmentKey.substring('name:'.length);
      return equipmentDisplayNameJaForRecordedName(name) ??
          _readableFallback(name);
    }
    return _readableFallback(equipmentKey);
  }

  DateTime _dateOf(ExerciseHistoryPoint point) =>
      point.startTime ?? DateTime.parse(point.operationDate);
}

class TrainingExerciseCategory {
  const TrainingExerciseCategory({required this.key, required this.label});

  final String key;
  final String label;
}

class TrainingExerciseEquipmentVariant {
  const TrainingExerciseEquipmentVariant({
    required this.identity,
    required this.label,
  });

  final TrainingExerciseIdentity identity;
  final String label;
}

class TrainingExerciseSelectorPresentation {
  const TrainingExerciseSelectorPresentation({
    required this.exerciseLabel,
    required this.equipmentLabel,
  });

  final String exerciseLabel;
  final String? equipmentLabel;
}

String? _readableFallback(String value) {
  final cleaned = value
      .replaceFirst(RegExp(r'^name:'), '')
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned.isEmpty ? null : cleaned.toUpperCase();
}
