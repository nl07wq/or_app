import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A maintained traversal record for interaction-feedback reviews.
///
/// This is intentionally a screen/path inventory rather than a constructor
/// count: every entry identifies the destination source inspected and the
/// feedback meanings exercised there. Add a row when a user-facing route or
/// nested editor/detail flow is introduced.
class SemanticAuditScreen {
  const SemanticAuditScreen({
    required this.path,
    required this.source,
    required this.interactions,
  });

  final String path;
  final String source;
  final List<String> interactions;
}

const semanticAuditScreens = <SemanticAuditScreen>[
  SemanticAuditScreen(
    path: 'Dashboard',
    source: 'lib/features/dashboard/dashboard_page.dart',
    interactions: ['command module entry', 'silent display state', 'passive'],
  ),
  SemanticAuditScreen(
    path: 'Status / history / fact',
    source: 'lib/features/morning/morning_page.dart',
    interactions: ['command submit', 'rejected completed entry', 'exit back'],
  ),
  SemanticAuditScreen(
    path: 'Food / entry / edit',
    source: 'lib/features/food/food_page.dart',
    interactions: ['command save', 'exit back', 'input'],
  ),
  SemanticAuditScreen(
    path: 'Food database / detail',
    source: 'lib/features/food/food_catalog_page.dart',
    interactions: [
      'silent FOOD/RECIPE/MEAL tabs',
      'command add/detail',
      'exit back',
      'input',
    ],
  ),
  SemanticAuditScreen(
    path: 'Food recipe editor',
    source: 'lib/features/food/food_recipe_page.dart',
    interactions: [
      'command add/archive',
      'deferred save command/rejected',
      'exit back',
    ],
  ),
  SemanticAuditScreen(
    path: 'Food meal editor',
    source: 'lib/features/food/food_meal_master_page.dart',
    interactions: [
      'command add/archive',
      'deferred save command/rejected',
      'exit back',
    ],
  ),
  SemanticAuditScreen(
    path: 'Food history / nutrition analysis / meal analysis',
    source: 'lib/features/food/food_history_page.dart',
    interactions: ['command record/detail', 'exit back'],
  ),
  SemanticAuditScreen(
    path: 'Training / entry / detail / plan',
    source: 'lib/features/training/training_page.dart',
    interactions: ['command record/edit/save', 'exit back', 'input'],
  ),
  SemanticAuditScreen(
    path: 'Training history / analytics',
    source: 'lib/features/training/data_center_training_history_page.dart',
    interactions: ['silent view/range/metric selectors', 'exit back'],
  ),
  SemanticAuditScreen(
    path: 'Activity / entry / history',
    source: 'lib/features/activity/activity_page.dart',
    interactions: [
      'command entry',
      'rejected completed entry',
      'exit back',
      'input',
    ],
  ),
  SemanticAuditScreen(
    path: 'Activity history',
    source: 'lib/features/activity_history/pages/activity_history_page.dart',
    interactions: ['silent range/show-more/day navigation', 'exit back'],
  ),
  SemanticAuditScreen(
    path: 'Digestive history',
    source: 'lib/features/digestive_history/pages/digestive_history_page.dart',
    interactions: ['silent range/show-more/day/disclosure', 'exit back'],
  ),
  SemanticAuditScreen(
    path: 'Command Center / periodic / brief / daily command',
    source: 'lib/features/command_center/pages/command_center_page.dart',
    interactions: [
      'silent tabs/range',
      'command finalize/archive entry',
      'rejected finalize',
      'exit back',
    ],
  ),
  SemanticAuditScreen(
    path: 'Data Center / aggregate archive/detail',
    source: 'lib/features/body_history/pages/data_center_history_page.dart',
    interactions: ['command history/detail entry', 'exit back'],
  ),
  SemanticAuditScreen(
    path: 'Body history',
    source: 'lib/features/body_history/pages/body_history_page.dart',
    interactions: ['silent range selector', 'exit back'],
  ),
  SemanticAuditScreen(
    path: 'Sleep history',
    source: 'lib/features/sleep_history/pages/sleep_history_page.dart',
    interactions: ['silent range/metric/show-more/day navigation', 'exit back'],
  ),
  SemanticAuditScreen(
    path: 'Nutrition history',
    source: 'lib/features/nutrition_history/pages/nutrition_history_page.dart',
    interactions: ['silent range selector', 'exit back'],
  ),
  SemanticAuditScreen(
    path: 'Calendar / schedule editor / weather',
    source: 'lib/features/schedule/pages/calendar_page.dart',
    interactions: [
      'command add/open',
      'silent period/weather disclosure',
      'exit back',
      'input',
    ],
  ),
  SemanticAuditScreen(
    path: 'Reminder / editor',
    source: 'lib/features/reminders/pages/reminders_page.dart',
    interactions: [
      'command add/complete/edit',
      'silent tabs',
      'exit back',
      'input',
    ],
  ),
  SemanticAuditScreen(
    path: 'Report Sync',
    source: 'lib/features/report_sync/pages/report_sync_exchange_page.dart',
    interactions: [
      'command generate/copy/paste/validate/import',
      'exit back',
      'input',
    ],
  ),
  SemanticAuditScreen(
    path: 'System / Profile / About',
    source: 'lib/features/system/pages/system_page.dart',
    interactions: ['command module entry/save', 'exit back', 'input'],
  ),
  SemanticAuditScreen(
    path: 'Device Transfer / Backup / Sync / Monitoring',
    source: 'lib/features/system/pages/device_transfer_page.dart',
    interactions: [
      'command functional destinations/import',
      'exit back',
      'input',
    ],
  ),
  SemanticAuditScreen(
    path: 'Backup and Restore',
    source: 'lib/features/import_export/backup_restore_page.dart',
    interactions: ['command export/import/restore', 'exit back', 'input'],
  ),
  SemanticAuditScreen(
    path: 'Operation Sync / historical imports',
    source: 'lib/features/system/pages/operation_sync_page.dart',
    interactions: ['command sync/import', 'exit back', 'input'],
  ),
  SemanticAuditScreen(
    path: 'System monitoring',
    source: 'lib/features/system/pages/system_monitoring_page.dart',
    interactions: [
      'command operational entry',
      'silent display state',
      'exit back',
    ],
  ),
  SemanticAuditScreen(
    path: 'Brief / Debrief archive and records',
    source: 'lib/features/command_center/widgets/brief_debrief_page.dart',
    interactions: ['command archive/record entry', 'exit back'],
  ),
];

/// These developer-facing visualization/sandbox routes are intentionally
/// excluded from the production interaction traversal. They do not form part
/// of the user operational workflow, but remain explicit exceptions so they
/// cannot be mistaken for an uninspected production destination.
const semanticAuditTechnicalExceptions = <String>[
  'lib/features/system/pages/animations_sandbox_page.dart',
];

void main() {
  test('semantic audit manifest covers reachable production screen paths', () {
    expect(semanticAuditScreens, isNotEmpty);
    for (final screen in semanticAuditScreens) {
      expect(File(screen.source).existsSync(), isTrue, reason: screen.path);
      expect(screen.interactions, isNotEmpty, reason: screen.path);
    }
    for (final source in semanticAuditTechnicalExceptions) {
      expect(File(source).existsSync(), isTrue, reason: source);
    }
  });

  test('known role-sensitive paths retain explicit role declarations', () {
    final foodCatalog = File(
      'lib/features/food/food_catalog_page.dart',
    ).readAsStringSync();
    final sleep = File(
      'lib/features/sleep_history/pages/sleep_history_page.dart',
    ).readAsStringSync();
    final activity = File(
      'lib/features/activity_history/pages/activity_history_page.dart',
    ).readAsStringSync();
    final digestive = File(
      'lib/features/digestive_history/pages/digestive_history_page.dart',
    ).readAsStringSync();

    expect(foodCatalog, contains('ActionableFeedbackRole.silent'));
    expect(foodCatalog, contains('deferFeedback: true'));
    expect(sleep, contains('ActionableFeedbackRole.silent'));
    expect(activity, contains('ActionableFeedbackRole.silent'));
    expect(digestive, contains('ActionableFeedbackRole.silent'));
  });
}
