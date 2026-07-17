import 'package:flutter/material.dart';

import '../../../core/models/work_type.dart';
import '../../../core/widgets/inputs/time/time_input_card.dart';
import '../../../core/widgets/inputs/wheel/wheel_selector_card.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/services/work_calculator.dart';

class WorkCard extends StatelessWidget {
  final WorkType workType;

  final ValueChanged<WorkType> onChanged;

  final TextEditingController startController;
  final TextEditingController endController;
  final TextEditingController breakController;

  const WorkCard({
    super.key,
    required this.workType,
    required this.onChanged,
    required this.startController,
    required this.endController,
    required this.breakController,
  });

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.work, title: "WORK"),

          const SizedBox(height: 20),

          WheelSelectorCard<WorkType>(
            title: "Work Type",
            value: workType,
            values: WorkType.values,
            labels: const {
              WorkType.work: "出勤",
              WorkType.holiday: "公休日",
              WorkType.paidLeave: "有給休暇",
              WorkType.halfDay: "半休",
              WorkType.other: "その他",
            },
            onChanged: onChanged,
          ),

          if (workType == WorkType.work || workType == WorkType.halfDay) ...[
            const SizedBox(height: 20),

            TimeInputCard(
              title: "Start Time",
              controller: startController,
              minuteStep: 15,
            ),

            const SizedBox(height: 20),

            TimeInputCard(
              title: "End Time",
              controller: endController,
              minuteStep: 15,
            ),

            const SizedBox(height: 20),

            TimeInputCard(
              title: "Break Time",
              controller: breakController,
              minuteStep: 15,
            ),

            const SizedBox(height: 20),

            ValueListenableBuilder<TextEditingValue>(
              valueListenable: startController,
              builder: (_, __, ___) {
                return ValueListenableBuilder<TextEditingValue>(
                  valueListenable: endController,
                  builder: (_, __, ___) {
                    return ValueListenableBuilder<TextEditingValue>(
                      valueListenable: breakController,
                      builder: (_, __, ___) {
                        final workHours = WorkCalculator.calculate(
                          start: startController.text,
                          end: endController.text,
                          workBreak: breakController.text,
                        );

                        return Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                "WORK HOURS",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                WorkCalculator.format(workHours),
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
