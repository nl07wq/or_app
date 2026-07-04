import 'package:flutter/material.dart';

import '../../../core/models/work_type.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/operation_dropdown.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/operation_text_field.dart';

class WorkCard extends StatelessWidget {
  final WorkType workType;
  final ValueChanged<WorkType?> onChanged;
  final TextEditingController workController;

  const WorkCard({
    super.key,
    required this.workType,
    required this.onChanged,
    required this.workController,
  });

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.work, title: "WORK"),

          const SizedBox(height: 20),

          OperationDropdown<WorkType>(
            label: "勤務区分",
            value: workType,
            onChanged: onChanged,
            items: const [
              DropdownMenuItem(value: WorkType.work, child: Text("出勤")),
              DropdownMenuItem(value: WorkType.holiday, child: Text("公休日")),
              DropdownMenuItem(value: WorkType.paidLeave, child: Text("有給休暇")),
              DropdownMenuItem(value: WorkType.halfDay, child: Text("半休")),
              DropdownMenuItem(value: WorkType.other, child: Text("その他")),
            ],
          ),

          const SizedBox(height: 20),

          if (workType == WorkType.work || workType == WorkType.halfDay)
            OperationTextField(
              controller: workController,
              label: "勤務時間",
              hint: "例）8:00",
            ),
        ],
      ),
    );
  }
}
