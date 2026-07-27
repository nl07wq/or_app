import 'package:flutter/material.dart';

import '../../import_export/services/backup_file_export_service.dart';
import '../../import_export/services/backup_file_gateway.dart';

class BackupPromptDialog extends StatefulWidget {
  const BackupPromptDialog({super.key, required this.exportService});

  final BackupFileExportService exportService;

  @override
  State<BackupPromptDialog> createState() => _BackupPromptDialogState();
}

class _BackupPromptDialogState extends State<BackupPromptDialog> {
  _BackupPromptState _state = _BackupPromptState.ready;

  bool get _busy => _state == _BackupPromptState.exporting;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _state = _BackupPromptState.exporting);
    try {
      final result = await widget.exportService.export();
      if (!mounted) return;
      setState(() {
        _state = result.delivery == BackupFileDelivery.cancelled
            ? _BackupPromptState.cancelled
            : _BackupPromptState.exported;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _BackupPromptState.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('BACKUP'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: _content(),
        ),
        actions: _actions(),
      ),
    );
  }

  Widget _content() {
    return switch (_state) {
      _BackupPromptState.ready => const Text(
        '本日の記録を確定しました。\n'
        '最新のBACKUPを出力しますか？',
      ),
      _BackupPromptState.exporting => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Flexible(child: Text('BACKUPを出力しています。')),
        ],
      ),
      _BackupPromptState.exported => const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Backup exported'),
          SizedBox(height: 8),
          Text(
            'BACKUPファイルを共有画面へ出力しました。\n'
            '保存先は端末側で確認してください。',
          ),
        ],
      ),
      _BackupPromptState.cancelled => const Text('BACKUPの保存をキャンセルしました。'),
      _BackupPromptState.failed => const Text('BACKUPの出力に失敗しました。'),
    };
  }

  List<Widget> _actions() {
    return switch (_state) {
      _BackupPromptState.ready => [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('NOT NOW'),
        ),
        FilledButton(onPressed: _export, child: const Text('EXPORT BACKUP')),
      ],
      _BackupPromptState.exporting => const [],
      _BackupPromptState.exported || _BackupPromptState.cancelled => [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CLOSE'),
        ),
      ],
      _BackupPromptState.failed => [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CLOSE'),
        ),
        FilledButton(onPressed: _export, child: const Text('RETRY')),
      ],
    };
  }
}

enum _BackupPromptState { ready, exporting, exported, cancelled, failed }
