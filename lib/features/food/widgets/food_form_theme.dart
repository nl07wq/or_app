import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

/// Route-local, immutable presentation tokens shared by FOOD ENTRY and FOOD
/// DATABASE add/edit forms. Domain data and controllers stay owned by each
/// screen; only the compact visual language is shared here.
abstract final class FoodFormMetrics {
  static const pageSurface = Color(0x990D1219);
  static const fieldSurface = Color(0xCC17212C);
  static const nutritionSurface = Color(0xCC141D27);
  static const separator = Color(0xFF273D4B);
  static const caption = Color(0xFF83A5B8);
  static const fieldLabel = Color(0xFF7898AB);
  static const fieldValue = Color(0xFFEDF6FB);
  static const protein = Color(0xFF76C4E7);
  static const fat = Color(0xFF8EADE1);
  static const carbohydrate = Color(0xFFAAA6E2);
  static const fieldContentPadding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 8,
  );
  static const labelTextStyle = TextStyle(fontSize: 12);
  static const valueFontSize = 14.0;
  static const gap = SizedBox(height: AppSpacing.sm);
  static const horizontalGap = SizedBox(width: AppSpacing.sm);
  static const barcodeButtonSize = Size(84, 44);
  static const barcodeButtonPadding = EdgeInsets.symmetric(horizontal: 10);

  static ThemeData applyTo(ThemeData theme) {
    final labelStyle = labelTextStyle.copyWith(color: fieldLabel);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: separator),
    );
    return theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        isDense: true,
        contentPadding: fieldContentPadding,
        labelStyle: labelStyle,
        floatingLabelStyle: labelStyle,
        filled: true,
        fillColor: fieldSurface,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.4),
        ),
        hintStyle: theme.inputDecorationTheme.hintStyle?.copyWith(
          color: fieldLabel.withValues(alpha: .72),
        ),
      ),
      textTheme: theme.textTheme.copyWith(
        bodyLarge: theme.textTheme.bodyLarge?.copyWith(
          fontSize: valueFontSize,
          color: fieldValue,
        ),
        bodyMedium: theme.textTheme.bodyMedium?.copyWith(
          fontSize: valueFontSize,
          color: fieldValue,
        ),
      ),
    );
  }
}

/// Keeps form presentation isolated to the current route subtree. It never
/// stores mutable configuration, so a database form cannot alter ENTRY after
/// a pop/return transition.
class FoodFormTheme extends StatelessWidget {
  const FoodFormTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme(data: FoodFormMetrics.applyTo(Theme.of(context)), child: child);
}

/// The category value is intentionally more compact than its field label and
/// menu rows.  Long Japanese values therefore remain one line without
/// changing the typography of unrelated dropdowns.
class FoodCategoryDropdown<T> extends StatelessWidget {
  const FoodCategoryDropdown({
    super.key,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final base =
        Theme.of(context).textTheme.bodyLarge ??
        const TextStyle(fontSize: FoodFormMetrics.valueFontSize);
    final selectedStyle = base.copyWith(
      fontSize: (base.fontSize ?? FoodFormMetrics.valueFontSize) * .8,
    );
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'CATEGORY'),
      style: selectedStyle,
      items: values
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(labelFor(item), style: base),
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
    );
  }
}

/// Touch-first field navigation for the compact nutrition group.  The owner
/// supplies its existing focus nodes, so changing focus never writes data or
/// invokes a save action.
class FoodNutritionFocusToolbar extends StatefulWidget {
  const FoodNutritionFocusToolbar({super.key, required this.nodes});

  final List<FocusNode> nodes;

  @override
  State<FoodNutritionFocusToolbar> createState() =>
      _FoodNutritionFocusToolbarState();
}

class _FoodNutritionFocusToolbarState extends State<FoodNutritionFocusToolbar> {
  int _activeIndex = -1;

  int get _focusedIndex => widget.nodes.indexWhere((node) => node.hasFocus);

  int get _currentIndex {
    final focused = _focusedIndex;
    return focused >= 0 ? focused : _activeIndex;
  }

  @override
  void initState() {
    super.initState();
    for (final node in widget.nodes) {
      node.addListener(_handleFocusChanged);
    }
  }

  @override
  void didUpdateWidget(covariant FoodNutritionFocusToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.nodes, widget.nodes)) return;
    for (final node in oldWidget.nodes) {
      node.removeListener(_handleFocusChanged);
    }
    for (final node in widget.nodes) {
      node.addListener(_handleFocusChanged);
    }
  }

  @override
  void dispose() {
    for (final node in widget.nodes) {
      node.removeListener(_handleFocusChanged);
    }
    super.dispose();
  }

  void _handleFocusChanged() {
    final focused = _focusedIndex;
    if (focused >= 0) _activeIndex = focused;
    if (mounted) setState(() {});
  }

  void _moveFocus(int targetIndex) {
    if (targetIndex < 0 || targetIndex >= widget.nodes.length) return;
    // A touch control must never become the browser's active element.  Keep
    // the current numeric field alive through the handoff, then request the
    // target node that is already owned by the form.
    setState(() => _activeIndex = targetIndex);
    FocusScope.of(context).requestFocus(widget.nodes[targetIndex]);
  }

  void _finishEditing() {
    setState(() => _activeIndex = -1);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIndex;
    if (current < 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: Semantics(
          container: true,
          label: 'Nutrition field navigation',
          child: Row(
            key: const ValueKey('food-nutrition-focus-toolbar'),
            mainAxisSize: MainAxisSize.min,
            children: [
              _button(
                key: const ValueKey('food-nutrition-focus-previous'),
                icon: Icons.keyboard_arrow_up,
                tooltip: 'Previous nutrition field',
                onPressed: current > 0 ? () => _moveFocus(current - 1) : null,
              ),
              _button(
                key: const ValueKey('food-nutrition-focus-next'),
                icon: Icons.keyboard_arrow_down,
                tooltip: 'Next nutrition field',
                onPressed: current < widget.nodes.length - 1
                    ? () => _moveFocus(current + 1)
                    : null,
              ),
              _button(
                key: const ValueKey('food-nutrition-focus-done'),
                icon: Icons.done,
                tooltip: 'Finish nutrition editing',
                onPressed: _finishEditing,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button({
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      enabled: onPressed != null,
      label: tooltip,
      child: SizedBox(
        key: key,
        width: 44,
        height: 44,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Center(
            child: Icon(
              icon,
              size: 19,
              color: onPressed == null
                  ? Theme.of(context).disabledColor
                  : IconTheme.of(context).color,
            ),
          ),
        ),
      ),
    ),
  );
}
