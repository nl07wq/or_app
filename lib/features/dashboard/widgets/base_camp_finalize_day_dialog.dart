import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../operation_date/models/daily_finalize_result.dart';
import '../../themes/base_camp/widgets/base_camp_operation_panel.dart';

const baseCampTerminalSuccessHold = Duration(milliseconds: 1500);

class BaseCampFinalizeDayDialog extends StatefulWidget {
  const BaseCampFinalizeDayDialog({
    super.key,
    required this.onFinalize,
    this.successHold = baseCampTerminalSuccessHold,
  });

  final Future<void> Function() onFinalize;
  final Duration successHold;

  @override
  State<BaseCampFinalizeDayDialog> createState() =>
      _BaseCampFinalizeDayDialogState();
}

class _BaseCampFinalizeDayDialogState extends State<BaseCampFinalizeDayDialog> {
  _FinalizePopupState _state = _FinalizePopupState.confirm;
  Object? _error;
  Timer? _dismissTimer;

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  Future<void> _finalize() async {
    if (_state != _FinalizePopupState.confirm) return;
    setState(() => _state = _FinalizePopupState.processing);
    try {
      await widget.onFinalize();
      if (!mounted) return;
      setState(() => _state = _FinalizePopupState.complete);
      _dismissTimer = Timer(widget.successHold, () {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _state = _FinalizePopupState.failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: BaseCampOperationPanel(
      title: 'FINALIZE DAY',
      state: switch (_state) {
        _FinalizePopupState.confirm => BaseCampOperationPanelState.confirmation,
        _FinalizePopupState.processing =>
          BaseCampOperationPanelState.processing,
        _FinalizePopupState.complete ||
        _FinalizePopupState.failed => BaseCampOperationPanelState.result,
      },
      result: switch (_state) {
        _FinalizePopupState.complete => BaseCampOperationPanelResult.success,
        _FinalizePopupState.failed => BaseCampOperationPanelResult.failure,
        _ => null,
      },
      message: switch (_state) {
        _FinalizePopupState.confirm => '本日の記録を確定します。',
        _FinalizePopupState.processing => '本日の記録を確定しています。',
        _FinalizePopupState.complete => '本日の記録を確定しました。',
        _FinalizePopupState.failed => 'FINALIZE DAYに失敗しました。\n${_error ?? ''}',
      },
      actions: _actions(),
    ),
  );

  List<Widget> _actions() => switch (_state) {
    _FinalizePopupState.confirm => <Widget>[
      BaseCampOperationPanelButton(
        label: 'CANCEL',
        onPressed: () => Navigator.pop(context, false),
      ),
      BaseCampOperationPanelButton(
        label: 'FINALIZE',
        primary: true,
        onPressed: _finalize,
      ),
    ],
    _FinalizePopupState.processing ||
    _FinalizePopupState.complete => const <Widget>[],
    _FinalizePopupState.failed => <Widget>[
      if (_error case DailyFinalizeException(:final diagnostics?))
        BaseCampOperationPanelButton(
          label: 'COPY DIAGNOSTICS',
          onPressed: () =>
              Clipboard.setData(ClipboardData(text: diagnostics.toCopyText())),
        ),
      BaseCampOperationPanelButton(
        label: 'CLOSE',
        primary: true,
        onPressed: () => Navigator.pop(context, false),
      ),
    ],
  };
}

enum _FinalizePopupState { confirm, processing, complete, failed }
