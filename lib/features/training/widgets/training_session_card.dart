import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/operation_text_field.dart';
import '../../../core/widgets/section_header.dart';

class TrainingSessionCard extends StatelessWidget {
  final TextEditingController memoController;

  const TrainingSessionCard({super.key, required this.memoController});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.event_note, title: 'SESSION'),

          AppSpacing.gapMD,

          OperationTextField(
            controller: memoController,
            label: 'Session Memo',
            hint: "Today's training...",
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}
