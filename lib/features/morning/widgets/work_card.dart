import 'package:flutter/material.dart';

import '../../../core/models/work_type.dart';
import '../../../core/widgets/inputs/time/time_input_card.dart';
import '../../../core/widgets/inputs/wheel/wheel_selector_card.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/services/work_calculator.dart';
import '../../../core/models/work_template.dart';

class WorkCard extends StatefulWidget {
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
  State<WorkCard> createState() => _WorkCardState();
}

class _WorkCardState extends State<WorkCard> {
  void _applyTemplate(WorkTemplate template) {
    widget.startController.text = template.start;
    widget.endController.text = template.end;
    widget.breakController.text = template.breakTime;

    setState(() {});
  }

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
            value: widget.workType,
            values: WorkType.values,
            labels: const {
              WorkType.work: "出勤",
              WorkType.holiday: "公休日",
              WorkType.paidLeave: "有給休暇",
              WorkType.halfDay: "半休",
              WorkType.other: "その他",
            },
            onChanged: widget.onChanged,
          ),

          if (widget.workType == WorkType.work ||
              widget.workType == WorkType.halfDay) ...[
            const SizedBox(height: 20),

            const Text("Shift", style: TextStyle(fontWeight: FontWeight.bold)),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: WorkTemplate.values.map((template) {
                return ChoiceChip(
                  label: Text(template.label),
                  selected: false,
                  onSelected: (_) => _applyTemplate(template),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            TimeInputCard(
              title: "Start Time",
              controller: widget.startController,
              minuteStep: 15,
              initialHour: 11,
              initialMinute: 0,
            ),

            const SizedBox(height: 20),

            TimeInputCard(
              title: "End Time",
              controller: widget.endController,
              minuteStep: 15,
              initialHour: 18,
              initialMinute: 0,
            ),

            const SizedBox(height: 20),

            TimeInputCard(
              title: "Break Time",
              controller: widget.breakController,
              minuteStep: 15,
              initialHour: 1,
              initialMinute: 0,
            ),

            const SizedBox(height: 20),

            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.startController,
              builder: (_, __, ___) {
                return ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.endController,
                  builder: (_, __, ___) {
                    return ValueListenableBuilder<TextEditingValue>(
                      valueListenable: widget.breakController,
                      builder: (_, __, ___) {
                        final workHours = WorkCalculator.calculate(
                          start: widget.startController.text,
                          end: widget.endController.text,
                          workBreak: widget.breakController.text,
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
