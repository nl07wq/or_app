import 'package:flutter/material.dart';

import 'package:or_app/core/widgets/global_touch_ripple.dart';

import '../../../core/models/bowel_amount.dart';
import '../../../core/models/bowel_shape.dart';

import '../../../core/widgets/dashboard_glass_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../themes/base_camp/base_camp_retro_terminal.dart';

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
    return DashboardGlassCard(
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
                _BowelDisclosureButton(
                  icon: amount.icon,
                  label: amount.label,
                  onPressed: () => setState(() => amountExpanded = true),
                ),
            ],
          ),

          if (amountExpanded) ...[
            const SizedBox(height: 12),
            if (BaseCampTerminalPaletteScope.maybeOf(context) != null)
              _BaseCampBowelChoiceRow(
                children: <Widget>[
                  for (final item in BowelAmount.values)
                    _BaseCampBowelChoiceKey(
                      selected: amount == item,
                      icon: item.icon,
                      label: item.label,
                      onPressed: () => _selectAmount(item),
                    ),
                ],
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BowelAmount.values
                    .map(
                      (item) => ChoiceChip(
                        avatar: Icon(item.icon, size: 18),
                        label: Text(item.label),
                        selected: amount == item,
                        onSelected: (_) => _selectAmount(item),
                      ).inputFeedback(),
                    )
                    .toList(),
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
                  _BowelDisclosureButton(
                    icon: shape.icon,
                    label: shape.label,
                    onPressed: () => setState(() => shapeExpanded = true),
                  ),
              ],
            ),

            if (shapeExpanded) ...[
              const SizedBox(height: 12),
              if (BaseCampTerminalPaletteScope.maybeOf(context) != null)
                _BaseCampBowelChoiceRow(
                  children: <Widget>[
                    for (final item in BowelShape.values)
                      _BaseCampBowelChoiceKey(
                        selected: shape == item,
                        icon: item.icon,
                        label: item.label,
                        onPressed: () => _selectShape(item),
                      ),
                  ],
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BowelShape.values
                      .map(
                        (item) => ChoiceChip(
                          avatar: Icon(item.icon, size: 18),
                          label: Text(item.label),
                          selected: shape == item,
                          onSelected: (_) => _selectShape(item),
                        ).inputFeedback(),
                      )
                      .toList(),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _BaseCampBowelChoiceRow extends StatelessWidget {
  const _BaseCampBowelChoiceRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: Row(
      children: <Widget>[
        for (var index = 0; index < children.length; index++) ...<Widget>[
          Expanded(child: children[index]),
          if (index != children.length - 1) const SizedBox(width: 4),
        ],
      ],
    ),
  );
}

class _BaseCampBowelChoiceKey extends StatelessWidget {
  const _BaseCampBowelChoiceKey({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => BaseCampTerminalMechanicalKey(
    selected: selected,
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 3),
    onPressed: onPressed,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontSize: 10),
          ),
        ),
      ],
    ),
  );
}

class _BowelDisclosureButton extends StatelessWidget {
  const _BowelDisclosureButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
    if (BaseCampTerminalPaletteScope.maybeOf(context) != null) {
      return BaseCampTerminalMechanicalKey(
        height: 40,
        onPressed: onPressed,
        child: child,
      );
    }
    return TextButton(onPressed: onPressed, child: child).actionableFeedback();
  }
}
