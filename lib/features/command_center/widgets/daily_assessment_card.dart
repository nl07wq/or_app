import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../models/daily_assessment.dart';
import 'daily_assessment_label_mapper.dart';

class DailyAssessmentView extends StatelessWidget {
  const DailyAssessmentView({super.key, required this.assessment});

  final DailyAssessment assessment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final module in DailyAssessmentModule.values) ...[
          _ModuleAssessmentCard(
            module: module,
            currentWeightReference: assessment.currentWeightReference,
            items: assessment.assessments
                .where((item) => item.module == module)
                .toList(growable: false),
          ),
          AppSpacing.gapSM,
        ],
        _StringListCard(
          title: 'PRIMARY CONSTRAINT',
          values: assessment.primaryConstraints
              .map(dailyAssessmentConstraintLabel)
              .toList(growable: false),
        ),
        AppSpacing.gapSM,
        _StringListCard(
          title: 'AVAILABLE RESOURCE',
          values: assessment.availableResources
              .map(dailyAssessmentResourceLabel)
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _ModuleAssessmentCard extends StatelessWidget {
  const _ModuleAssessmentCard({
    required this.module,
    required this.items,
    required this.currentWeightReference,
  });

  final DailyAssessmentModule module;
  final List<DailyAssessmentItem> items;
  final DailyWeightReference currentWeightReference;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(module.label, style: Theme.of(context).textTheme.titleSmall),
        AppSpacing.gapMD,
        for (var index = 0; index < items.length; index++) ...[
          _AssessmentItem(
            item: items[index],
            currentWeightReference: currentWeightReference,
          ),
          if (index != items.length - 1) const Divider(height: 24),
        ],
      ],
    ),
  );
}

class _AssessmentItem extends StatelessWidget {
  const _AssessmentItem({
    required this.item,
    required this.currentWeightReference,
  });

  final DailyAssessmentItem item;
  final DailyWeightReference currentWeightReference;

  @override
  Widget build(BuildContext context) {
    final readiness = item.rawValue is TrainingReadinessFacts
        ? item.rawValue! as TrainingReadinessFacts
        : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.metric.label,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              AppSpacing.gapXS,
              if (item.metric == DailyAssessmentMetric.weightTrend) ...[
                _ReadinessFactRow(
                  label: _weightReferenceLabel(currentWeightReference.source),
                  value: currentWeightReference.valueKg == null
                      ? 'NOT AVAILABLE'
                      : '${currentWeightReference.valueKg!.toStringAsFixed(1)} kg',
                ),
                AppSpacing.gapXS,
              ],
              if (readiness == null)
                Text(_valueLabel(item))
              else
                _TrainingReadinessDetails(facts: readiness),
              AppSpacing.gapXS,
              Text(dailyAssessmentSpecificLabel(item)),
            ],
          ),
        ),
        if (item.level != null) ...[
          AppSpacing.gapSM,
          _LevelBadge(level: item.level!),
        ],
      ],
    );
  }
}

class _TrainingReadinessDetails extends StatelessWidget {
  const _TrainingReadinessDetails({required this.facts});

  final TrainingReadinessFacts facts;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ReadinessFactRow(
        label: 'LAST TRAINING',
        value: '${facts.lastTraining.compactLabel} ago',
      ),
      _ReadinessFactRow(
        label: 'LAST 7 DAYS',
        value: '${facts.last7DaysSessionCount} sessions',
      ),
      _ReadinessFactRow(
        label: 'THIS WEEK',
        value: '${facts.currentWeekSessionCount} sessions',
      ),
      _ReadinessFactRow(
        label: 'RECENT INTERVALS',
        value: facts.recentIntervals.isEmpty
            ? 'NOT AVAILABLE'
            : facts.recentIntervals
                  .map((interval) => interval.compactLabel)
                  .join(' / '),
      ),
      _ReadinessFactRow(
        label: 'CONSECUTIVE DAYS',
        value: facts.consecutiveTrainingDays >= 2
            ? 'YES · ${facts.consecutiveTrainingDays} days'
            : 'NO',
      ),
    ],
  );
}

class _ReadinessFactRow extends StatelessWidget {
  const _ReadinessFactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        AppSpacing.gapSM,
        Flexible(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final DailyAssessmentLevel level;

  @override
  Widget build(BuildContext context) {
    final color = dailyAssessmentLevelColor(level);
    return Container(
      key: ValueKey('daily-assessment-level-${level.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        level.label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _StringListCard extends StatelessWidget {
  const _StringListCard({required this.title, required this.values});

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        AppSpacing.gapSM,
        if (values.isEmpty)
          const Text('NOT AVAILABLE')
        else
          for (final value in values) Text(value),
      ],
    ),
  );
}

Color dailyAssessmentLevelColor(DailyAssessmentLevel level) => switch (level) {
  DailyAssessmentLevel.support => Colors.green,
  DailyAssessmentLevel.stable => Colors.blue,
  DailyAssessmentLevel.watch => Colors.orange,
  DailyAssessmentLevel.adjust => Colors.yellow,
  DailyAssessmentLevel.limit => Colors.red,
};

String _weightReferenceLabel(DailyWeightReferenceSource source) =>
    switch (source) {
      DailyWeightReferenceSource.measuredToday => 'CURRENT WEIGHT',
      DailyWeightReferenceSource.sevenDayMean => 'WEEK AVERAGE',
      DailyWeightReferenceSource.fourteenDayMean => '14-DAY AVERAGE',
      DailyWeightReferenceSource.notAvailable => 'NOT AVAILABLE',
    };

String _valueLabel(DailyAssessmentItem item) {
  final value = item.rawValue;
  if (value == null) return '—';
  return switch (item.metric) {
    DailyAssessmentMetric.sleepTime => _duration(value as int),
    DailyAssessmentMetric.weightTrend =>
      '${(value as double) >= 0 ? '+' : ''}${value.toStringAsFixed(2)} kg/week',
    DailyAssessmentMetric.work =>
      value is num ? '${value.toStringAsFixed(1)} h' : value.toString(),
    DailyAssessmentMetric.calorieBalance =>
      '${(value as num).toStringAsFixed(0)} kcal',
    DailyAssessmentMetric.protein => '${(value as num).toStringAsFixed(1)} g',
    DailyAssessmentMetric.hydration =>
      '${(value as num).toStringAsFixed(0)} mL',
    DailyAssessmentMetric.steps => '${value as int}',
    _ => value.toString(),
  };
}

String _duration(int minutes) =>
    '${minutes ~/ 60}h ${minutes.remainder(60).toString().padLeft(2, '0')}m';
