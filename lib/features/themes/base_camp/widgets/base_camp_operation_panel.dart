import 'package:flutter/material.dart';

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
