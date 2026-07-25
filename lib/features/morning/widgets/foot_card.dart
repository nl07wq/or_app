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
    if (widget.controller.text.isEmpty) {
      widget.controller.text = '3';
    }
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(FootCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;

    oldWidget.controller.removeListener(_handleControllerChanged);
    if (widget.controller.text.isEmpty) {
      widget.controller.text = '3';
    }
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

  Widget _buildPainLevelRow(List<int> values, Key key, _FootPainLayout layout) {
    return Row(
      key: key,
      children: [
        for (var index = 0; index < values.length; index++) ...[
          if (index > 0) SizedBox(width: layout.chipSpacing),
          Expanded(
            child: SizedBox(
              height: layout.chipHeight,
              child: ChoiceChip(
                key: Key('foot-pain-chip-${values[index]}'),
                label: Text(
                  '${values[index]}',
                  style: TextStyle(fontSize: layout.labelFontSize),
                ),
                labelPadding: EdgeInsets.symmetric(
                  horizontal: layout.labelPadding,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: layout.horizontalPadding,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

          LayoutBuilder(
            builder: (context, constraints) {
              final layout = _FootPainLayout.fromWidth(constraints.maxWidth);
              return Column(
                children: [
                  _buildPainLevelRow(
                    _firstRowValues,
                    const Key('foot-pain-levels-1-5'),
                    layout,
                  ),
                  SizedBox(height: layout.rowSpacing),
                  _buildPainLevelRow(
                    _secondRowValues,
                    const Key('foot-pain-levels-6-10'),
                    layout,
                  ),
                ],
              );
            },
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

class _FootPainLayout {
  final double chipHeight;
  final double labelFontSize;
  final double chipSpacing;
  final double rowSpacing;
  final double horizontalPadding;
  final double labelPadding;

  const _FootPainLayout({
    required this.chipHeight,
    required this.labelFontSize,
    required this.chipSpacing,
    required this.rowSpacing,
    required this.horizontalPadding,
    required this.labelPadding,
  });

  factory _FootPainLayout.fromWidth(double width) {
    if (width < 300) {
      return const _FootPainLayout(
        chipHeight: 46,
        labelFontSize: 16,
        chipSpacing: 4,
        rowSpacing: 8,
        horizontalPadding: 2,
        labelPadding: 0,
      );
    }
    if (width < 600) {
      return const _FootPainLayout(
        chipHeight: 56,
        labelFontSize: 19,
        chipSpacing: 8,
        rowSpacing: 10,
        horizontalPadding: 6,
        labelPadding: 2,
      );
    }
    return const _FootPainLayout(
      chipHeight: 68,
      labelFontSize: 24,
      chipSpacing: 12,
      rowSpacing: 12,
      horizontalPadding: 12,
      labelPadding: 4,
    );
  }
}
