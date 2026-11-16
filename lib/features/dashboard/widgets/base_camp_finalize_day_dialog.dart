import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../operation_date/models/daily_finalize_result.dart';
import '../../themes/base_camp/widgets/base_camp_terminal_popup.dart';

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
    child: BaseCampTerminalPopup(
      title: 'FINALIZE DAY',
      stateLabel: switch (_state) {
        _FinalizePopupState.confirm => 'CONFIRM',
        _FinalizePopupState.processing => 'PROCESSING',
        _FinalizePopupState.complete => 'COMPLETE',
        _FinalizePopupState.failed => 'FAILED',
      },
      message: switch (_state) {
        _FinalizePopupState.confirm => '本日の記録を確定します。',
        _FinalizePopupState.processing => '本日の記録を確定しています。',
        _FinalizePopupState.complete => '本日の記録を確定しました。',
        _FinalizePopupState.failed => 'FINALIZE DAYに失敗しました。\n${_error ?? ''}',
      },
      busy: _state == _FinalizePopupState.processing,
      actions: _actions(),
    ),
  );

  List<Widget> _actions() => switch (_state) {
    _FinalizePopupState.confirm => <Widget>[
      BaseCampTerminalPopupButton(
        label: 'CANCEL',
        onPressed: () => Navigator.pop(context, false),
      ),
      BaseCampTerminalPopupButton(
        label: 'FINALIZE',
        primary: true,
        onPressed: _finalize,
      ),
    ],
    _FinalizePopupState.processing ||
    _FinalizePopupState.complete => const <Widget>[],
    _FinalizePopupState.failed => <Widget>[
      if (_error case DailyFinalizeException(:final diagnostics?))
        BaseCampTerminalPopupButton(
          label: 'COPY DIAGNOSTICS',
          onPressed: () =>
              Clipboard.setData(ClipboardData(text: diagnostics.toCopyText())),
        ),
      BaseCampTerminalPopupButton(
        label: 'CLOSE',
        primary: true,
        onPressed: () => Navigator.pop(context, false),
      ),
    ],
  };
}

enum _FinalizePopupState { confirm, processing, complete, failed }
