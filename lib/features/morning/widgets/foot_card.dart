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

  Widget _buildPainLevelRow(List<int> values, Key key, _FootPainLayout layout) {
    return Row(
      key: key,
      children: [
        for (var index = 0; index < values.length; index++) ...[
          if (index > 0) SizedBox(width: layout.chipSpacing),
          Expanded(
            child: SizedBox(
              height: layout.chipHeight,
              child: _SelectablePainChip(
                chipKey: Key('foot-pain-chip-${values[index]}'),
                value: values[index],
                selected: _selectedValue == values[index],
                height: layout.chipHeight,
                labelFontSize: layout.labelFontSize,
                horizontalPadding: layout.horizontalPadding,
                checkIconSize: layout.checkIconSize,
                onTap: () => _selectPainLevel(values[index]),
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

class _SelectablePainChip extends StatelessWidget {
  final Key chipKey;
  final int value;
  final bool selected;
  final double height;
  final double labelFontSize;
  final double horizontalPadding;
  final double checkIconSize;
  final VoidCallback onTap;

  const _SelectablePainChip({
    required this.chipKey,
    required this.value,
    required this.selected,
    required this.height,
    required this.labelFontSize,
    required this.horizontalPadding,
    required this.checkIconSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected
        ? colors.onSecondaryContainer
        : colors.onSurfaceVariant;
    final shape = StadiumBorder(side: BorderSide(color: colors.outlineVariant));

    return Semantics(
      key: chipKey,
      button: true,
      selected: selected,
      label: 'Pain level $value',
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Material(
          color: selected
              ? colors.secondaryContainer
              : colors.surfaceContainerLow,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: shape,
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: checkIconSize,
                      child: Opacity(
                        opacity: selected ? 1 : 0,
                        child: Icon(
                          Icons.check,
                          size: checkIconSize,
                          color: foreground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$value',
                      style: TextStyle(
                        color: foreground,
                        fontSize: labelFontSize,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
  final double checkIconSize;

  const _FootPainLayout({
    required this.chipHeight,
    required this.labelFontSize,
    required this.chipSpacing,
    required this.rowSpacing,
    required this.horizontalPadding,
    required this.checkIconSize,
  });

  factory _FootPainLayout.fromWidth(double width) {
    if (width < 300) {
      return const _FootPainLayout(
        chipHeight: 44,
        labelFontSize: 14,
        chipSpacing: 2,
        rowSpacing: 6,
        horizontalPadding: 0,
        checkIconSize: 14,
      );
    }
    if (width < 600) {
      return const _FootPainLayout(
        chipHeight: 46,
        labelFontSize: 15,
        chipSpacing: 4,
        rowSpacing: 8,
        horizontalPadding: 2,
        checkIconSize: 15,
      );
    }
    return const _FootPainLayout(
      chipHeight: 48,
      labelFontSize: 16,
      chipSpacing: 6,
      rowSpacing: 8,
      horizontalPadding: 4,
      checkIconSize: 16,
    );
  }
}
