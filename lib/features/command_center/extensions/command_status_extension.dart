import 'package:flutter/material.dart';

import '../models/command_status.dart';

extension CommandStatusExtension on CommandStatus {
  String get label {
    switch (this) {
      case CommandStatus.complete:
        return 'COMPLETE';
      case CommandStatus.ready:
        return 'READY';
      case CommandStatus.caution:
        return 'CAUTION';
      case CommandStatus.warning:
        return 'WARNING';
      case CommandStatus.locked:
        return 'LOCKED';
    }
  }

  Color get color {
    switch (this) {
      case CommandStatus.complete:
        return Colors.blue;
      case CommandStatus.ready:
        return Colors.green;
      case CommandStatus.caution:
        return Colors.yellow;
      case CommandStatus.warning:
        return Colors.orange;
      case CommandStatus.locked:
        return Colors.red;
    }
  }

  String get description {
    switch (this) {
      case CommandStatus.complete:
        return 'Mission Complete';
      case CommandStatus.ready:
        return 'All Systems Operational';
      case CommandStatus.caution:
        return 'Minor Issues Detected';
      case CommandStatus.warning:
        return 'Immediate Attention Required';
      case CommandStatus.locked:
        return 'Operation Suspended';
    }
  }
}
