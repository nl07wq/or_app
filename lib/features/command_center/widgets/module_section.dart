import 'package:flutter/material.dart';

import '../extensions/command_status_extension.dart';
import '../models/command_state.dart';

import 'module_status_card.dart';

class ModuleSection extends StatelessWidget {
  final List<CommandState> states;

  const ModuleSection({super.key, required this.states});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'MODULE STATUS',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ),

        ...states.map(
          (state) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ModuleStatusCard(
              module: state.module,
              message: state.message,
              color: state.status.color,
            ),
          ),
        ),
      ],
    );
  }
}
