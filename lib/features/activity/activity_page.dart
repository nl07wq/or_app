import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/services/app_clock.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/services/persistence_access.dart';
import '../../core/state/app_initialization_state.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_description.dart';
import '../../core/widgets/section_header.dart';
import '../repositories/app_repository_container.dart';
import '../repositories/repository_exception.dart';
import 'activity_entry_page.dart';
import 'activity_history_page.dart';
import 'models/activity_draft.dart';
import 'repository/activity_repository.dart';
import 'services/activity_draft_finalize_service.dart';
import 'widgets/activity_draft_recovery_dialog.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  bool _draftNoticeShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPastDraftsOnce();
    });
  }

  Future<void> _openEntry([DateTime? date]) async {
    final targetDate = date ?? AppClock.today();
    final existing = await const LocalActivityRepository().findByDate(
      targetDate,
    );
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ActivityEntryPage(initialData: existing, targetDate: targetDate),
      ),
    );
  }

  Future<void> _showPastDraftsOnce() async {
    if (_draftNoticeShown || !AppRepositoryRegistry.hasContainer) return;
    _draftNoticeShown = true;

    try {
      final today = _dateOnly(AppClock.today());
      final drafts =
          (await AppRepositoryRegistry.container.activityDrafts.findAll())
              .where((draft) => DateTime.parse(draft.localDate).isBefore(today))
              .toList();
      if (drafts.isEmpty || !mounted) return;

      final items = <ActivityDraftRecoveryItem>[];
      for (final draft in drafts) {
        final date = DateTime.parse(draft.localDate);
        items.add(
          ActivityDraftRecoveryItem(
            draft: draft,
            hasFormalRecord:
                await const LocalActivityRepository().findByDate(date) != null,
            isDailyLogConfirmed: await DailyLogMutationGuard.isDateConfirmed(
              date,
            ),
          ),
        );
      }
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ActivityDraftRecoveryDialog(
          items: items,
          onResume: (draft) => _openEntry(DateTime.parse(draft.localDate)),
          onFinalize: _finalizePastDraft,
          onDiscard: _discardPastDraft,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('未確定Activityデータを読み込めませんでした');
    }
  }

  Future<String?> _finalizePastDraft(ActivityDraft draft) async {
    final date = DateTime.parse(draft.localDate);
    try {
      if (await DailyLogMutationGuard.isDateConfirmed(date)) {
        return '${draft.localDate}のDaily Logは確定済みです。訂正処理を開始してください。';
      }
      if (await const LocalActivityRepository().findByDate(date) != null) {
        return '${draft.localDate}には正式Activity Recordがあります。Draftから上書きできません。';
      }
      await ActivityDraftFinalizeService(
        AppRepositoryRegistry.container.database,
      ).finalize(draft: draft);
      return null;
    } on ConfirmedDailyLogException {
      return '${draft.localDate}のDaily Logは確定済みです。訂正処理を開始してください。';
    } on RepositoryException catch (error) {
      final cause = error.cause;
      if (cause is FormatException) {
        return '${draft.localDate}の${cause.message}';
      }
      return '${draft.localDate}のActivity記録を確定できませんでした';
    } catch (_) {
      return '${draft.localDate}のActivity記録を確定できませんでした';
    }
  }

  Future<String?> _discardPastDraft(ActivityDraft draft) async {
    try {
      PersistenceAccess.requireWrite('activityDraft.discard');
      final repository = AppRepositoryRegistry.container.activityDrafts;
      await repository.deleteById(draft.id);
      if (await repository.findById(draft.id) != null) {
        throw StateError('ACTIVITY Draft was not deleted.');
      }
      return null;
    } catch (_) {
      return '${draft.localDate}の未確定データを破棄できませんでした';
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ACTIVITY')),
    body: SingleChildScrollView(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(icon: Icons.sync, title: 'REPORT SYNC'),

          AppSpacing.gapSM,

          const OperationDescription(
            text:
                'Operation Reboot Reportから\n'
                '本日の活動記録を同期します。',
          ),

          AppSpacing.gapMD,

          OperationButton(
            icon: Icons.sync,
            text: 'SYNC ACTIVITY',
            onPressed: appInitializationController.value.isReadOnly
                ? null
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming Soon')),
                    );
                  },
          ),

          AppSpacing.gapXL,

          const SectionHeader(
            icon: Icons.directions_walk_outlined,
            title: 'MANUAL ENTRY',
          ),

          AppSpacing.gapSM,

          const OperationDescription(
            text:
                '本日の歩数・排便など\n'
                '本日の活動を記録します。',
          ),

          AppSpacing.gapMD,

          OperationButton(
            icon: Icons.edit_outlined,
            text: 'ACTIVITY ENTRY',
            onPressed: appInitializationController.value.isReadOnly
                ? null
                : _openEntry,
          ),

          AppSpacing.gapXL,

          const SectionHeader(icon: Icons.history, title: 'RECORD'),

          AppSpacing.gapSM,

          const OperationDescription(
            text:
                '過去の活動履歴を\n'
                '確認・編集できます。',
          ),

          AppSpacing.gapMD,

          OperationButton(
            icon: Icons.history_outlined,
            text: 'RECORD',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ActivityHistoryPage()),
            ),
          ),
        ],
      ),
    ),
  );

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
