import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../models/daily_assessment.dart';
import 'daily_assessment_label_mapper.dart';
import 'semantic_help_popover.dart';

@visibleForTesting
String dailyAssessmentLevelHelp(DailyAssessmentLevel level) => switch (level) {
  DailyAssessmentLevel.support => '今日の運用を積極的に支える要因です。運用上の修正は必要ありません。',
  DailyAssessmentLevel.stable => '通常運用が可能な範囲です。現在の運用を継続します。',
  DailyAssessmentLevel.watch => '監視する段階です。直ちに変更する段階ではありませんが、推移を確認します。',
  DailyAssessmentLevel.adjust => '負荷や運用内容の具体的な調整が必要な段階です。',
  DailyAssessmentLevel.limit => '明確な制約がある段階です。判定内容に従って運用を制限します。',
};

class DailyAssessmentView extends StatelessWidget {
  const DailyAssessmentView({super.key, required this.assessment});

  final DailyAssessment assessment;

  @override
  Widget build(BuildContext context) {
    const rows = [
      (DailyAssessmentModule.body, DailyAssessmentModule.recovery),
      (DailyAssessmentModule.condition, DailyAssessmentModule.workLoad),
      (DailyAssessmentModule.calorieBalance, DailyAssessmentModule.nutrition),
      (DailyAssessmentModule.hydration, DailyAssessmentModule.recentLoad),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _module(row.$1)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _module(row.$2)),
            ],
          ),
          AppSpacing.gapSM,
        ],
        _module(DailyAssessmentModule.training),
        AppSpacing.gapSM,
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

  Widget _module(DailyAssessmentModule module) => _ModuleAssessmentCard(
    module: module,
    currentWeightReference: assessment.currentWeightReference,
    currentBodyFatPercent: assessment.currentBodyFatPercent,
    previousFormalBodyFatPercent: assessment.previousFormalBodyFatPercent,
    workDisplayValue: assessment.workDisplayValue,
    items: assessment.assessments
        .where((item) => item.module == module)
        .toList(growable: false),
  );
}

class _ModuleAssessmentCard extends StatelessWidget {
  const _ModuleAssessmentCard({
    required this.module,
    required this.items,
    required this.currentWeightReference,
    required this.currentBodyFatPercent,
    required this.previousFormalBodyFatPercent,
    required this.workDisplayValue,
  });

  final DailyAssessmentModule module;
  final List<DailyAssessmentItem> items;
  final DailyWeightReference currentWeightReference;
  final double? currentBodyFatPercent;
  final double? previousFormalBodyFatPercent;
  final String? workDisplayValue;

  @override
  Widget build(BuildContext context) {
    final level = _moduleLevel(items);
    return OperationCard(
      key: ValueKey('daily-assessment-card-${module.name}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  module.label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (level != null) ...[
                AppSpacing.gapXS,
                KeyedSubtree(
                  key: ValueKey('daily-assessment-badge-${module.name}'),
                  child: _LevelBadge(level: level),
                ),
              ],
            ],
          ),
          AppSpacing.gapMD,
          for (var index = 0; index < items.length; index++) ...[
            _AssessmentItem(
              item: items[index],
              currentWeightReference: currentWeightReference,
              workDisplayValue: workDisplayValue,
              showMetricLabel:
                  items[index].metric != DailyAssessmentMetric.calorieBalance,
            ),
            if (index != items.length - 1) const Divider(height: 24),
          ],
          if (module == DailyAssessmentModule.body) ...[
            if (items.isNotEmpty) const Divider(height: 24),
            _BodyFatFact(
              current: currentBodyFatPercent,
              previous: previousFormalBodyFatPercent,
            ),
          ],
        ],
      ),
    );
  }
}

class _AssessmentItem extends StatelessWidget {
  const _AssessmentItem({
    required this.item,
    required this.currentWeightReference,
    required this.workDisplayValue,
    required this.showMetricLabel,
  });

  final DailyAssessmentItem item;
  final DailyWeightReference currentWeightReference;
  final String? workDisplayValue;
  final bool showMetricLabel;

  @override
  Widget build(BuildContext context) {
    final readiness = item.rawValue is TrainingReadinessFacts
        ? item.rawValue! as TrainingReadinessFacts
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showMetricLabel) ...[
          Text(
            item.metric.label,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          AppSpacing.gapXS,
        ],
        if (item.metric == DailyAssessmentMetric.weightTrend)
          _WeightFactValue(reference: currentWeightReference),
        if (readiness == null)
          if (item.metric != DailyAssessmentMetric.weightTrend)
            Text(
              item.metric == DailyAssessmentMetric.work &&
                      workDisplayValue != null
                  ? workDisplayValue!
                  : _valueLabel(item, currentWeightReference),
            )
          else ...[
            AppSpacing.gapXS,
            Text(_valueLabel(item, currentWeightReference)),
          ]
        else
          _TrainingReadinessDetails(facts: readiness),
        AppSpacing.gapXS,
        Text(dailyAssessmentSpecificLabel(item)),
      ],
    );
  }
}

class _WeightFactValue extends StatelessWidget {
  const _WeightFactValue({required this.reference});

  final DailyWeightReference reference;

  @override
  Widget build(BuildContext context) {
    final sourceLabel = switch (reference.source) {
      DailyWeightReferenceSource.sevenDayMean => 'WEEK AVERAGE',
      DailyWeightReferenceSource.fourteenDayMean => '14-DAY AVERAGE',
      _ => null,
    };
    final value = reference.valueKg;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sourceLabel != null) ...[
          Text(sourceLabel, style: Theme.of(context).textTheme.labelSmall),
          AppSpacing.gapXS,
        ],
        Text(
          value != null &&
                  reference.source != DailyWeightReferenceSource.notAvailable
              ? '${value.toStringAsFixed(1)} kg'
              : 'NOT AVAILABLE',
        ),
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
        label: 'TRAINING INTERVALS',
        value: facts.recentIntervals.isEmpty
            ? 'NOT AVAILABLE'
            : facts.recentIntervals
                  .map((interval) => interval.compactLabel)
                  .join(' / '),
      ),
    ],
  );
}

class _BodyFatFact extends StatelessWidget {
  const _BodyFatFact({required this.current, required this.previous});

  final double? current;
  final double? previous;

  @override
  Widget build(BuildContext context) {
    final validCurrent = current != null && current!.isFinite && current! > 0;
    final validPrevious =
        previous != null && previous!.isFinite && previous! > 0;
    final delta = validCurrent && validPrevious ? current! - previous! : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BODY FAT', style: Theme.of(context).textTheme.labelLarge),
        AppSpacing.gapXS,
        Text(
          validCurrent ? '${current!.toStringAsFixed(1)} %' : 'NOT AVAILABLE',
        ),
        AppSpacing.gapXS,
        Text(
          delta == null
              ? 'NOT AVAILABLE'
              : '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} %',
        ),
        AppSpacing.gapXS,
        Text(
          delta == null
              ? '前回計測値を確認できません。'
              : delta < 0
              ? '前回計測値から減少しています。'
              : delta > 0
              ? '前回計測値から増加しています。'
              : '前回計測値から変化はありません。',
        ),
      ],
    );
  }
}

DailyAssessmentLevel? _moduleLevel(List<DailyAssessmentItem> items) {
  final levels = [
    for (final item in items)
      if (item.level != null) item.level!,
  ];
  if (levels.isEmpty) return null;
  return levels.reduce(
    (first, second) => first.index >= second.index ? first : second,
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
    return SemanticHelpPopover(
      id: 'assessment-${level.name}',
      title: level.label,
      description: dailyAssessmentLevelHelp(level),
      child: Container(
        key: ValueKey('daily-assessment-level-${level.name}'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          level.label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
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

String _valueLabel(
  DailyAssessmentItem item,
  DailyWeightReference currentWeightReference,
) {
  final value = item.rawValue;
  if (value == null) return '—';
  return switch (item.metric) {
    DailyAssessmentMetric.sleepTime => _duration(value as int),
    DailyAssessmentMetric.weightTrend =>
      currentWeightReference.source == DailyWeightReferenceSource.measuredToday
          ? '${(value as double) > 0 ? '+' : ''}${value.toStringAsFixed(1)} kg'
          : '${(value as double) >= 0 ? '+' : ''}${value.toStringAsFixed(2)} kg/week',
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
