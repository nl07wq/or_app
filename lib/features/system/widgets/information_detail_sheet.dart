import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../models/information_notice.dart';

enum InformationDetailResult { closed, systemMonitoring }

class InformationDetailSheet extends StatefulWidget {
  const InformationDetailSheet({
    super.key,
    required this.notices,
    required this.onRead,
    required this.onDismiss,
  });

  final List<InformationNotice> notices;
  final Future<void> Function(String id) onRead;
  final Future<void> Function(String id) onDismiss;

  @override
  State<InformationDetailSheet> createState() => _InformationDetailSheetState();
}

class _InformationDetailSheetState extends State<InformationDetailSheet> {
  late final List<InformationNotice> _notices = [...widget.notices];
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _markRead(_notices.first);
  }

  Future<void> _markRead(InformationNotice notice) async {
    if (notice.state == InformationNoticeState.unread) {
      await widget.onRead(notice.id);
      if (mounted) {
        setState(() {
          _notices[_index] = notice.copyWith(
            state: InformationNoticeState.read,
            readAt: DateTime.now(),
          );
        });
      }
    }
  }

  Future<void> _dismiss(InformationNotice notice) async {
    await widget.onDismiss(notice.id);
    if (!mounted) return;
    setState(() {
      _notices.removeAt(_index);
      if (_index >= _notices.length) _index = _notices.length - 1;
    });
    if (_notices.isEmpty && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_notices.isEmpty) return const SizedBox.shrink();
    final notice = _notices[_index];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Symbols.breaking_news,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'INFORMATION',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: '閉じる',
                ),
              ],
            ),
            if (_notices.length > 1) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('${_index + 1} / ${_notices.length}'),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(notice.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(notice.message),
            const SizedBox(height: AppSpacing.md),
            Text('${notice.category}  •  ${notice.parameterVersion}'),
            const SizedBox(height: AppSpacing.xs),
            Text('発生: ${_format(notice.createdAt)}'),
            const SizedBox(height: AppSpacing.lg),
            if (notice.actionLabel != null)
              SizedBox(
                width: double.infinity,
                child: OperationButton(
                  text: notice.actionLabel!,
                  onPressed: () => Navigator.pop(
                    context,
                    InformationDetailResult.systemMonitoring,
                  ),
                ),
              ),
            if (notice.actionLabel != null)
              const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _dismiss(notice),
                child: const Text('表示から消す'),
              ),
            ),
            if (_notices.length > 1) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  TextButton(
                    onPressed: _index == 0
                        ? null
                        : () {
                            setState(() => _index--);
                            _markRead(_notices[_index]);
                          },
                    child: const Text('前へ'),
                  ),
                  TextButton(
                    onPressed: _index == _notices.length - 1
                        ? null
                        : () {
                            setState(() => _index++);
                            _markRead(_notices[_index]);
                          },
                    child: const Text('次へ'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _format(DateTime value) =>
      '${value.year}/${value.month}/${value.day} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
