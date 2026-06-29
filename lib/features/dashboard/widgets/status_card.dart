import 'package:flutter/material.dart';

import '../../../core/models/morning_data.dart';
import '../../../core/services/morning_record_service.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_title.dart';

class StatusCard extends StatefulWidget {
  const StatusCard({super.key});

  @override
  State<StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<StatusCard> {
  MorningData? morningData;

  @override
  void initState() {
    super.initState();
    loadMorningData();
  }

  Future<void> loadMorningData() async {
    final records = await MorningRecordService.load();

    if (records.isNotEmpty) {
      setState(() {
        morningData = records.last;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: "Today's Status"),
          const SizedBox(height: 16),

          Text(
            "⚖ Weight : ${morningData?.weight.toStringAsFixed(1) ?? "--.-"} kg",
          ),
          const SizedBox(height: 8),

          Text(
            "😴 Sleep : ${morningData?.sleepHours.toStringAsFixed(1) ?? "--.-"} h",
          ),
          const SizedBox(height: 8),

          const Text("🏋 Training : ---"),
          const SizedBox(height: 8),

          const Text("🔥 Calories : ---- kcal"),
        ],
      ),
    );
  }
}
