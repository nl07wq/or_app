import 'package:flutter/material.dart';

import 'package:or_app/core/widgets/global_touch_ripple.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dashboard_glass_card.dart';
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
  static const _maximumChipWidth = 72.0;
  static const _compactWidth = 280.0;
  static const _desktopWidth = 600.0;

  int? get _selectedValue => int.tryParse(widget.controller.text);
  bool get _hasSelectedValue {
    final value = _selectedValue;
    return value != null && value >= 1 && value <= 10;
  }

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
    if (!mounted) return;

    setState(() {});
  }

  void _selectPainLevel(int value) {
    widget.controller.text = value.toString();
  }

  Widget _buildPainLevelRow(List<int> values, Key key) {
    return LayoutBuilder(
      key: key,
      builder: (context, constraints) {
        if (constraints.maxWidth >= _desktopWidth) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < values.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                SizedBox(
                  width: _maximumChipWidth,
                  child: _PainLevelChip(
                    key: Key('foot-pain-chip-${values[index]}'),
                    value: values[index],
                    selected: _selectedValue == values[index],
                    onPressed: () => _selectPainLevel(values[index]),
                  ),
                ),
              ],
            ],
          );
        }

        final horizontalInset = constraints.maxWidth < _compactWidth
            ? 1.0
            : 4.0;

        return Row(
          children: [
            for (final value in values)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalInset),
                  child: Align(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _maximumChipWidth,
                      ),
                      child: _PainLevelChip(
                        key: Key('foot-pain-chip-$value'),
                        value: value,
                        selected: _selectedValue == value,
                        onPressed: () => _selectPainLevel(value),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.accessibility_new,
            title: "FOOT HEALTH",
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 48,
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'PAIN LEVEL',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  key: const Key('foot-pain-current-value-button'),
                  onPressed: () {},
                  child: Text(
                    _hasSelectedValue ? 'LV.$_selectedValue /10' : '未選択',
                    key: _hasSelectedValue
                        ? const Key('foot-pain-current-value')
                        : null,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.lightBlueAccent,
                    ),
                  ),
                ).actionableFeedback(),
              ],
            ),
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
            '0–2 軽度   3–4 監視   5–6 保護検討   7以上 強保護候補',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PainLevelChip extends StatelessWidget {
  const _PainLevelChip({
    super.key,
    required this.value,
    required this.selected,
    required this.onPressed,
  });

  final int value;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;
    final shape = RoundedRectangleBorder(
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      side: BorderSide(
        color: selected
            ? colorScheme.primary.withValues(alpha: .82)
            : colorScheme.outlineVariant,
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: 'Pain level $value',
      onTap: onPressed,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: Material(
          key: Key('foot-pain-material-$value'),
          color: selected ? colorScheme.secondaryContainer : Colors.transparent,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('foot-pain-inkwell-$value'),
            customBorder: shape,
            excludeFromSemantics: true,
            onTap: onPressed,
            child: Center(
              child: selected
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 18, color: foregroundColor),
                        const SizedBox(width: 4),
                        Text(
                          '$value',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: foregroundColor),
                        ),
                      ],
                    )
                  : Text(
                      '$value',
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: foregroundColor),
                    ),
            ),
          ).actionableFeedback(),
        ),
      ),
    );
  }
}
