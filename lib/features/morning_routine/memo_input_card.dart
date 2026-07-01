import 'package:flutter/material.dart';

import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/operation_text_field.dart';

class MemoInputCard extends StatelessWidget {
  final TextEditingController controller;

  const MemoInputCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.edit_note, title: "MEMO"),
          const SizedBox(height: 12),

          OperationTextField(controller: controller, label: "メモ", maxLines: 4),
        ],
      ),
    );
  }
}
