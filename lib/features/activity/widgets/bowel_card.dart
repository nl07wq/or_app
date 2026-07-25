import 'package:flutter/material.dart';

import '../../../core/models/bowel_amount.dart';
import '../../../core/models/bowel_shape.dart';

import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

class BowelCard extends StatefulWidget {
  final TextEditingController amountController;
  final TextEditingController shapeController;

  const BowelCard({
    super.key,
    required this.amountController,
    required this.shapeController,
  });

  @override
  State<BowelCard> createState() => _BowelCardState();
}

class _BowelCardState extends State<BowelCard> {
  late bool amountExpanded;
  late bool shapeExpanded;

  BowelAmount get amount =>
      BowelAmount.fromValue(int.tryParse(widget.amountController.text) ?? 2);

  BowelShape get shape =>
      BowelShape.fromValue(int.tryParse(widget.shapeController.text) ?? 1);

  void _selectAmount(BowelAmount value) {
    widget.amountController.text = value.value.toString();

    if (value == BowelAmount.none) {
      widget.shapeController.clear();
      shapeExpanded = false;
    } else if (widget.shapeController.text.isEmpty) {
      widget.shapeController.text = BowelShape.normal.value.toString();
    }

    setState(() {
      amountExpanded = false;
    });
  }

  @override
  void initState() {
    super.initState();

    amountExpanded = widget.amountController.text.isEmpty;
    shapeExpanded = widget.shapeController.text.isEmpty;
  }

  void _selectShape(BowelShape value) {
    widget.shapeController.text = value.value.toString();

    setState(() {
      shapeExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.monitor_heart, title: "BOWEL"),

          const SizedBox(height: 20),

          // =========================
          // Amount
          // =========================
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Amount",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              if (!amountExpanded)
                TextButton(
                  onPressed: () {
                    setState(() {
                      amountExpanded = true;
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(amount.icon, size: 18),
                      const SizedBox(width: 6),
                      Text(amount.label),
                    ],
                  ),
                ),
            ],
          ),

          if (amountExpanded) ...[
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BowelAmount.values.map((item) {
                return ChoiceChip(
                  avatar: Icon(item.icon, size: 18),
                  label: Text(item.label),
                  selected: amount == item,
                  onSelected: (_) => _selectAmount(item),
                );
              }).toList(),
            ),
          ],

          // =========================
          // Shape
          // =========================
          if (amount != BowelAmount.none) ...[
            const SizedBox(height: 24),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Shape",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                if (!shapeExpanded)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        shapeExpanded = true;
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(shape.icon, size: 18),
                        const SizedBox(width: 6),
                        Text(shape.label),
                      ],
                    ),
                  ),
              ],
            ),

            if (shapeExpanded) ...[
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BowelShape.values.map((item) {
                  return ChoiceChip(
                    avatar: Icon(item.icon, size: 18),
                    label: Text(item.label),
                    selected: shape == item,
                    onSelected: (_) => _selectShape(item),
                  );
                }).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
