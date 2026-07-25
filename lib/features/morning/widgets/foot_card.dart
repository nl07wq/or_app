import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

class FootCard extends StatefulWidget {
  final TextEditingController controller;

  const FootCard({super.key, required this.controller});

  @override
  State<FootCard> createState() => _FootCardState();
}

class _FootCardState extends State<FootCard> {
  static const _firstRowValues = [1, 2, 3, 4, 5];
  static const _secondRowValues = [6, 7, 8, 9, 10];

  int? get _selectedValue => int.tryParse(widget.controller.text);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(FootCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;

    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  void _selectPainLevel(int value) {
    widget.controller.text = value.toString();
  }

  Widget _buildPainLevelRow(List<int> values, Key key) {
    return Row(
      key: key,
      children: [
        for (var index = 0; index < values.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: SizedBox.fromSize(
              size: const Size.fromHeight(48),
              child: ChoiceChip(
                key: Key('foot-pain-chip-${values[index]}'),
                label: Text('${values[index]}'),
                selected: _selectedValue == values[index],
                onSelected: (_) => _selectPainLevel(values[index]),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.accessibility_new,
            title: "FOOT HEALTH",
          ),

          const SizedBox(height: 20),

          const Text(
            'Pain Level',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          AppSpacing.gapMD,

          Column(
            children: [
              _buildPainLevelRow(
                _firstRowValues,
                const Key('foot-pain-levels-1-5'),
              ),
              const SizedBox(height: 8),
              _buildPainLevelRow(
                _secondRowValues,
                const Key('foot-pain-levels-6-10'),
              ),
            ],
          ),

          AppSpacing.gapMD,

          Text(
            '1–2：軽微\n'
            '3–4：軽い\n'
            '5–6：中程度\n'
            '7–8：強い\n'
            '9–10：非常に強い',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
