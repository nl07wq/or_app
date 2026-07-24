import 'repository_update_plan.dart';

enum RepositoryApplyWarningCode {
  duplicateTarget,
  missingRecords,
  untargetedRecords,
}

class RepositoryApplyWarning {
  final RepositoryApplyWarningCode code;
  final RepositoryTarget section;

  const RepositoryApplyWarning({required this.code, required this.section});
}

class RepositoryApplyResult {
  final bool success;
  final List<RepositoryTarget> appliedSections;
  final List<RepositoryTarget> skippedSections;
  final List<RepositoryApplyWarning> warnings;

  RepositoryApplyResult({
    required this.success,
    required Iterable<RepositoryTarget> appliedSections,
    required Iterable<RepositoryTarget> skippedSections,
    required Iterable<RepositoryApplyWarning> warnings,
  }) : appliedSections = List.unmodifiable(appliedSections),
       skippedSections = List.unmodifiable(skippedSections),
       warnings = List.unmodifiable(warnings);
}
