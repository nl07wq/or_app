import 'package:flutter/material.dart';

import '../models/morning_brief.dart';

import 'brief_section.dart';
import 'module_section.dart';
import 'argo_comment_card.dart';

class CommanderPanel extends StatelessWidget {
  final MorningBrief brief;

  const CommanderPanel({super.key, required this.brief});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BriefSection(brief: brief),

        const SizedBox(height: 16),

        ModuleSection(states: brief.states),

        const SizedBox(height: 16),

        ArgoCommentCard(commanderMessage: brief.commanderMessage),
      ],
    );
  }
}
