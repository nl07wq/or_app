import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../models/activity_draft.dart';

class ActivityDraftRecoveryItem {
  final ActivityDraft draft;
  final bool hasFormalRecord;
  final bool isDailyLogConfirmed;

  const ActivityDraftRecoveryItem({
    required this.draft,
    required this.hasFormalRecord,
    required this.isDailyLogConfirmed,
  });
}

class ActivityDraftRecoveryDialog extends StatefulWidget {
  final List<ActivityDraftRecoveryItem> items;
  final Future<void> Function(ActivityDraft draft) onResume;
  final Future<String?> Function(ActivityDraft draft) onFinalize;
  final Future<String?> Function(ActivityDraft draft) onDiscard;

  const ActivityDraftRecoveryDialog({
    super.key,
    required this.items,
    required this.onResume,
    required this.onFinalize,
    required this.onDiscard,
  });

  @override
  State<ActivityDraftRecoveryDialog> createState() =>
      _ActivityDraftRecoveryDialogState();
}

class _ActivityDraftRecoveryDialogState
    extends State<ActivityDraftRecoveryDialog> {
  late List<ActivityDraftRecoveryItem> _items;
  String? _busyDraftId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _items = widget.items.toList()
      ..sort(
        (first, second) =>
            second.draft.localDate.compareTo(first.draft.localDate),
      );
  }

  Future<void> _resume(ActivityDraft draft) async {
    Navigator.pop(context);
    await widget.onResume(draft);
  }

  Future<void> _finalize(ActivityDraft draft) async {
    if (_busyDraftId != null) return;
    setState(() {
      _busyDraftId = draft.id;
      _errorMessage = null;
    });
    final error = await widget.onFinalize(draft);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busyDraftId = null;
        _errorMessage = error;
      });
      return;
    }
    _removeCompleted(draft, '${draft.localDate}のActivity記録を確定しました');
  }

  Future<void> _confirmDiscard(ActivityDraft draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${draft.localDate}の未確定Activityデータを破棄しますか？'),
        content: const Text('この操作は元に戻せません'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('破棄'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busyDraftId != null) return;

    setState(() {
      _busyDraftId = draft.id;
      _errorMessage = null;
    });
    final error = await widget.onDiscard(draft);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busyDraftId = null;
        _errorMessage = error;
      });
      return;
    }
    _removeCompleted(draft, '${draft.localDate}の未確定データを破棄しました');
  }

  void _removeCompleted(ActivityDraft draft, String message) {
    final messenger = ScaffoldMessenger.of(context);
    _items.removeWhere((item) => item.draft.id == draft.id);
    if (_items.isEmpty) {
      Navigator.pop(context);
    } else {
      setState(() => _busyDraftId = null);
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final single = _items.length == 1;
    return Semantics(
      container: true,
      label: '前日の未確定Activityデータ',
      child: AlertDialog(
        title: Text(single ? '前日の未確定データがあります' : '未確定のActivity Draftがあります'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 460),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  single
                      ? '対象日：${_items.single.draft.localDate}'
                      : '未確定のActivity Draftが${_items.length}件あります',
                ),
                AppSpacing.gapSM,
                const Text('自動確定・自動削除は行いません。'),
                AppSpacing.gapMD,
                for (final item in _items) ...[
                  _DraftRecoveryRow(
                    item: item,
                    single: single,
                    busy: _busyDraftId != null,
                    onResume: () => _resume(item.draft),
                    onFinalize: () => _finalize(item.draft),
                    onDiscard: () => _confirmDiscard(item.draft),
                  ),
                  if (item != _items.last) AppSpacing.gapMD,
                ],
                if (_errorMessage != null) ...[
                  AppSpacing.gapMD,
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busyDraftId == null
                ? () => Navigator.pop(context)
                : null,
            child: const Text('あとで'),
          ),
        ],
      ),
    );
  }
}

class _DraftRecoveryRow extends StatelessWidget {
  final ActivityDraftRecoveryItem item;
  final bool single;
  final bool busy;
  final VoidCallback onResume;
  final VoidCallback onFinalize;
  final VoidCallback onDiscard;

  const _DraftRecoveryRow({
    required this.item,
    required this.single,
    required this.busy,
    required this.onResume,
    required this.onFinalize,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final date = item.draft.localDate;
    return Semantics(
      container: true,
      label: '$dateの未確定Activityデータ',
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date, style: Theme.of(context).textTheme.titleMedium),
              if (item.hasFormalRecord)
                Text(
                  '正式Activity Recordがあります',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (item.isDailyLogConfirmed)
                Text(
                  'Daily Log確定済みです。訂正処理を開始してください。',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              AppSpacing.gapSM,
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  Semantics(
                    label: '$dateの入力を再開',
                    button: true,
                    child: OutlinedButton(
                      onPressed: busy ? null : onResume,
                      child: Text(
                        item.hasFormalRecord
                            ? '正式Recordを表示'
                            : single
                            ? '前日入力を再開'
                            : '再開',
                      ),
                    ),
                  ),
                  Semantics(
                    label: '$dateのActivity記録を確定',
                    button: true,
                    child: OutlinedButton(
                      onPressed: busy ? null : onFinalize,
                      child: Text(single ? '前日分を確定' : '確定'),
                    ),
                  ),
                  Semantics(
                    label: '$dateの未確定データを破棄',
                    button: true,
                    child: OutlinedButton(
                      onPressed: busy ? null : onDiscard,
                      child: const Text('破棄'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
