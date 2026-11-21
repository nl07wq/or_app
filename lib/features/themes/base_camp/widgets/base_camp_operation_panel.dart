import 'package:flutter/material.dart';

import '../base_camp_presentation.dart';
import 'base_camp_terminal_popup.dart';

enum BaseCampOperationPanelState { confirmation, processing, result }

enum BaseCampOperationPanelResult { success, failure }

/// Shared BASE CAMP presentation for an operation's caller-owned lifecycle.
///
/// This widget never starts, retries, or completes an operation. Callers keep
/// ownership of validation, persistence, and modal return values and provide
/// the actions that are valid for the current lifecycle state.
class BaseCampOperationPanel extends StatelessWidget {
  const BaseCampOperationPanel({
    super.key,
    required this.title,
    required this.state,
    required this.message,
    this.result,
    this.stateLabel,
    this.actions = const <Widget>[],
  }) : assert(
         state == BaseCampOperationPanelState.result || result == null,
         'Only RESULT panels may specify a result.',
       ),
       assert(
         state != BaseCampOperationPanelState.result || result != null,
         'RESULT panels must specify success or failure.',
       );

  final String title;
  final BaseCampOperationPanelState state;
  final BaseCampOperationPanelResult? result;
  final String message;
  final String? stateLabel;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => BaseCampTerminalPopup(
    key: const ValueKey('base-camp-operation-panel'),
    title: title,
    stateLabel: stateLabel ?? _defaultStateLabel,
    message: message,
    busy: state == BaseCampOperationPanelState.processing,
    actions: actions,
  );

  String get _defaultStateLabel => switch (state) {
    BaseCampOperationPanelState.confirmation => 'CONFIRM',
    BaseCampOperationPanelState.processing => 'PROCESSING',
    BaseCampOperationPanelState.result => switch (result!) {
      BaseCampOperationPanelResult.success => 'COMPLETE',
      BaseCampOperationPanelResult.failure => 'FAILED',
    },
  };
}

typedef BaseCampOperationPanelButton = BaseCampTerminalPopupButton;

/// Shared confirmation adapter for simple operation gates. The operation is
/// still owned and invoked by the caller after a `true` result.
Future<bool> showBaseCampOperationConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'CANCEL',
  Key? confirmKey,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
}) async {
  final baseCamp = BaseCampPresentation.isActive(context);
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
    builder: (dialogContext) => baseCamp
        ? BaseCampOperationPanel(
            title: title,
            state: BaseCampOperationPanelState.confirmation,
            message: message,
            actions: <Widget>[
              BaseCampOperationPanelButton(
                label: cancelLabel,
                onPressed: () => Navigator.pop(dialogContext, false),
              ),
              BaseCampOperationPanelButton(
                key: confirmKey,
                label: confirmLabel,
                primary: true,
                onPressed: () => Navigator.pop(dialogContext, true),
              ),
            ],
          )
        : AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(cancelLabel),
              ),
              FilledButton(
                key: confirmKey,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
  );
  return result ?? false;
}

enum BaseCampOperationNoticeResult { success, failure, information }

/// Presents operation feedback without changing the caller's blocking model.
/// BASE CAMP receives the compact terminal family; STANDARD keeps a normal
/// Material SnackBar with the same message and lifetime.
void showBaseCampOperationNotice(
  BuildContext context, {
  required String title,
  required String message,
  BaseCampOperationNoticeResult result = BaseCampOperationNoticeResult.success,
  Duration duration = const Duration(seconds: 2),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final baseCamp = BaseCampPresentation.isActive(context);
  final failure = result == BaseCampOperationNoticeResult.failure;
  final stateLabel = switch (result) {
    BaseCampOperationNoticeResult.success => 'COMPLETE',
    BaseCampOperationNoticeResult.failure => 'FAILED',
    BaseCampOperationNoticeResult.information => 'NOTICE',
  };
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: baseCamp ? SnackBarBehavior.floating : null,
        backgroundColor: baseCamp ? Colors.transparent : null,
        elevation: baseCamp ? 0 : null,
        padding: baseCamp ? EdgeInsets.zero : null,
        margin: baseCamp ? const EdgeInsets.fromLTRB(20, 0, 20, 16) : null,
        duration: duration,
        dismissDirection: DismissDirection.down,
        content: baseCamp
            ? BaseCampTerminalNotice(
                title: title,
                stateLabel: stateLabel,
                message: message,
                failure: failure,
                actionLabel: actionLabel,
                onAction: onAction,
              )
            : Text(message),
        action: !baseCamp && actionLabel != null && onAction != null
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
}
