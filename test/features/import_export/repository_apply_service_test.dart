import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/import_export/models/repository_apply_result.dart';
import 'package:or_app/features/import_export/models/repository_update_plan.dart';
import 'package:or_app/features/import_export/services/repository_apply_service.dart';

void main() {
  test('empty plan succeeds without applied or skipped sections', () {
    final result = RepositoryApplyService.apply(_plan());

    expect(result.success, isTrue);
    expect(result.appliedSections, isEmpty);
    expect(result.skippedSections, isEmpty);
    expect(result.warnings, isEmpty);
  });

  test('MorningFact-only plan applies MorningFact', () {
    final result = RepositoryApplyService.apply(
      _plan(
        targets: const [RepositoryTarget.morningFact],
        records: {
          RepositoryTarget.morningFact: const [
            {'date': '2026-07-25'},
          ],
        },
      ),
    );

    expect(result.success, isTrue);
    expect(result.appliedSections, [RepositoryTarget.morningFact]);
    expect(result.skippedSections, isEmpty);
  });

  test('Training-only plan applies Training', () {
    final result = RepositoryApplyService.apply(
      _plan(
        targets: const [RepositoryTarget.training],
        records: {
          RepositoryTarget.training: const [
            {'date': '2026-07-25'},
          ],
        },
      ),
    );

    expect(result.success, isTrue);
    expect(result.appliedSections, [RepositoryTarget.training]);
    expect(result.skippedSections, isEmpty);
  });

  test('mixed plan uses MorningFact then Training apply order', () {
    final result = RepositoryApplyService.apply(
      _plan(
        targets: const [
          RepositoryTarget.training,
          RepositoryTarget.morningFact,
        ],
        records: {
          RepositoryTarget.training: const [
            {'date': '2026-07-25'},
          ],
          RepositoryTarget.morningFact: const [
            {'date': '2026-07-25'},
          ],
        },
      ),
    );

    expect(result.success, isTrue);
    expect(result.appliedSections, [
      RepositoryTarget.morningFact,
      RepositoryTarget.training,
    ]);
    expect(result.skippedSections, isEmpty);
    expect(
      () => result.appliedSections.add(RepositoryTarget.training),
      throwsUnsupportedError,
    );
  });

  test('invalid plan skips sections with missing records', () {
    final result = RepositoryApplyService.apply(
      _plan(targets: const [RepositoryTarget.training]),
    );

    expect(result.success, isFalse);
    expect(result.appliedSections, isEmpty);
    expect(result.skippedSections, [RepositoryTarget.training]);
    expect(result.warnings, hasLength(1));
    expect(
      result.warnings.single.code,
      RepositoryApplyWarningCode.missingRecords,
    );
    expect(result.warnings.single.section, RepositoryTarget.training);
    expect(
      () => result.warnings.add(
        const RepositoryApplyWarning(
          code: RepositoryApplyWarningCode.missingRecords,
          section: RepositoryTarget.morningFact,
        ),
      ),
      throwsUnsupportedError,
    );
  });
}

RepositoryUpdatePlan _plan({
  List<RepositoryTarget> targets = const [],
  Map<RepositoryTarget, List<Map<String, Object?>>> records = const {},
}) {
  return RepositoryUpdatePlan(
    targetRepositories: targets,
    records: records,
    operationType: RepositoryOperationType.restore,
  );
}
