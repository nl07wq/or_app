import '../models/repository_apply_result.dart';
import '../models/repository_update_plan.dart';

class RepositoryApplyService {
  RepositoryApplyService._();

  static const _applyOrder = [
    RepositoryTarget.morningFact,
    RepositoryTarget.training,
  ];

  static RepositoryApplyResult apply(RepositoryUpdatePlan plan) {
    final targetCounts = <RepositoryTarget, int>{};
    for (final target in plan.targetRepositories) {
      targetCounts[target] = (targetCounts[target] ?? 0) + 1;
    }

    final declaredTargets = targetCounts.keys.toSet();
    final skipped = <RepositoryTarget>{};
    final warnings = <RepositoryApplyWarning>[];

    for (final entry in targetCounts.entries) {
      if (entry.value > 1) {
        skipped.add(entry.key);
        warnings.add(
          RepositoryApplyWarning(
            code: RepositoryApplyWarningCode.duplicateTarget,
            section: entry.key,
          ),
        );
      }
    }

    for (final target in declaredTargets) {
      if (!plan.records.containsKey(target)) {
        skipped.add(target);
        warnings.add(
          RepositoryApplyWarning(
            code: RepositoryApplyWarningCode.missingRecords,
            section: target,
          ),
        );
      }
    }

    for (final target in plan.records.keys) {
      if (!declaredTargets.contains(target)) {
        skipped.add(target);
        warnings.add(
          RepositoryApplyWarning(
            code: RepositoryApplyWarningCode.untargetedRecords,
            section: target,
          ),
        );
      }
    }

    final applied = <RepositoryTarget>[
      for (final target in _applyOrder)
        if (declaredTargets.contains(target) &&
            plan.records.containsKey(target) &&
            !skipped.contains(target))
          target,
    ];
    final orderedSkipped = <RepositoryTarget>[
      for (final target in _applyOrder)
        if (skipped.contains(target)) target,
    ];

    // TODO: Add Food, Activity, Mission, and Body when snapshot support exists.
    return RepositoryApplyResult(
      success: warnings.isEmpty,
      appliedSections: applied,
      skippedSections: orderedSkipped,
      warnings: warnings,
    );
  }
}
