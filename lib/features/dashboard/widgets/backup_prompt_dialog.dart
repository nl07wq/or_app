import 'dart:async';

import 'package:flutter/material.dart';

import 'package:or_app/core/widgets/global_touch_ripple.dart';

import '../../import_export/services/backup_file_export_service.dart';
import '../../import_export/services/backup_file_gateway.dart';
import '../../themes/base_camp/base_camp_presentation.dart';
import '../../themes/base_camp/widgets/base_camp_communication_motion.dart';
import '../../themes/base_camp/widgets/base_camp_terminal_popup.dart';
import 'base_camp_finalize_day_dialog.dart';

class BackupPromptDialog extends StatefulWidget {
  const BackupPromptDialog({
    super.key,
    required this.exportService,
    this.successHold = baseCampTerminalSuccessHold,
  });

  final BackupFileExportService exportService;
  final Duration successHold;

  @override
  State<BackupPromptDialog> createState() => _BackupPromptDialogState();
}

class _BackupPromptDialogState extends State<BackupPromptDialog> {
  _BackupPromptState _state = _BackupPromptState.ready;
  Object? _error;
  Timer? _dismissTimer;

  bool get _busy => _state == _BackupPromptState.exporting;

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _state = _BackupPromptState.exporting);
    try {
      final result = BaseCampPresentation.isActive(context)
          ? await BaseCampCommunicationOverlay.run(
              context,
              kind: BaseCampCommunicationKind.backup,
              task: widget.exportService.export,
              isSuccess: (value) =>
                  value.delivery != BackupFileDelivery.cancelled,
            )
          : await widget.exportService.export();
      if (!mounted) return;
      setState(() {
        _state = result.delivery == BackupFileDelivery.cancelled
            ? _BackupPromptState.cancelled
            : _BackupPromptState.exported;
      });
      if (result.delivery != BackupFileDelivery.cancelled &&
          BaseCampPresentation.isActive(context)) {
        _dismissTimer = Timer(widget.successHold, () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _state = _BackupPromptState.failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (BaseCampPresentation.isActive(context)) {
      return PopScope(
        canPop: false,
        child: BaseCampTerminalPopup(
          title: 'BACKUP',
          stateLabel: switch (_state) {
            _BackupPromptState.ready => 'REQUIRED',
            _BackupPromptState.exporting => 'EXPORTING',
            _BackupPromptState.exported => 'COMPLETE',
            _BackupPromptState.cancelled => 'CANCELLED',
            _BackupPromptState.failed => 'FAILED',
          },
          message: switch (_state) {
            _BackupPromptState.ready => '最新のBACKUPを保存してください。',
            _BackupPromptState.exporting => 'BACKUPを出力しています。',
            _BackupPromptState.exported => 'BACKUPを出力しました。',
            _BackupPromptState.cancelled => 'BACKUPの保存をキャンセルしました。',
            _BackupPromptState.failed => 'BACKUPの出力に失敗しました。\n${_error ?? ''}',
          },
          busy: _busy,
          actions: _baseCampActions(),
        ),
      );
    }
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

  List<Widget> _baseCampActions() => switch (_state) {
    _BackupPromptState.ready => <Widget>[
      BaseCampTerminalPopupButton(
        label: 'NOT NOW',
        onPressed: () => Navigator.pop(context),
      ),
      BaseCampTerminalPopupButton(
        label: 'EXPORT BACKUP',
        primary: true,
        onPressed: _export,
      ),
    ],
    _BackupPromptState.exporting ||
    _BackupPromptState.exported => const <Widget>[],
    _BackupPromptState.cancelled => <Widget>[
      BaseCampTerminalPopupButton(
        label: 'CLOSE',
        primary: true,
        onPressed: () => Navigator.pop(context),
      ),
    ],
    _BackupPromptState.failed => <Widget>[
      BaseCampTerminalPopupButton(
        label: 'CLOSE',
        onPressed: () => Navigator.pop(context),
      ),
      BaseCampTerminalPopupButton(
        label: 'RETRY',
        primary: true,
        onPressed: _export,
      ),
    ],
  };

  Widget _content() {
    return switch (_state) {
      _BackupPromptState.ready => const Text(
        '本日の記録を確定しました。\n'
        'EXPORT BACKUPをタップして最新のBACKUPを保存してください。',
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
        ).actionableFeedback(),
        FilledButton(
          onPressed: _export,
          child: const Text('EXPORT BACKUP'),
        ).actionableFeedback(),
      ],
      _BackupPromptState.exporting => const [],
      _BackupPromptState.exported || _BackupPromptState.cancelled => [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CLOSE'),
        ).actionableFeedback(),
      ],
      _BackupPromptState.failed => [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CLOSE'),
        ).actionableFeedback(),
        FilledButton(
          onPressed: _export,
          child: const Text('RETRY'),
        ).actionableFeedback(),
      ],
    };
  }
}

enum _BackupPromptState { ready, exporting, exported, cancelled, failed }
