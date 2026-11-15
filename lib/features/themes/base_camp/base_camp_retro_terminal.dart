import 'package:flutter/material.dart';

import '../../../core/services/device_settings_controller.dart';
import '../../../core/widgets/operation_card.dart';
import 'base_camp_dashboard_page.dart' show BaseCampLcdGrainPainter;
import 'base_camp_presentation.dart';

/// Dashboard-synchronised LCD colours for BASE CAMP field-terminal pages.
@immutable
class BaseCampTerminalPalette {
  const BaseCampTerminalPalette({required this.negative});

  final bool negative;

  static const Color housing = Color(0xff1a2016);
  static const Color housingEdge = Color(0xff77745b);
  static const Color housingShadow = Color(0xff0b0f09);

  Color get background =>
      negative ? const Color(0xff273326) : const Color(0xffaeb894);
  Color get field =>
      negative ? const Color(0xff485c3f) : const Color(0xff788a66);
  Color get primaryText =>
      negative ? const Color(0xffaeb894) : const Color(0xff273326);
  Color get auxiliaryText =>
      negative ? const Color(0xff788a66) : const Color(0xff485c3f);
}

class BaseCampTerminalPaletteScope extends InheritedWidget {
  const BaseCampTerminalPaletteScope({
    super.key,
    required this.palette,
    required super.child,
  });

  final BaseCampTerminalPalette palette;

  static BaseCampTerminalPalette of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<BaseCampTerminalPaletteScope>()!
      .palette;

  static BaseCampTerminalPalette? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<BaseCampTerminalPaletteScope>()
      ?.palette;

  @override
  bool updateShouldNotify(BaseCampTerminalPaletteScope oldWidget) =>
      oldWidget.palette.negative != palette.negative;
}

/// Presentation-only wrapper used by approved BASE CAMP routes and their
/// descendants.
/// STANDARD receives the original child without a Theme or layout mutation.
class BaseCampRetroTerminalScreen extends StatelessWidget {
  const BaseCampRetroTerminalScreen({
    super.key,
    required this.child,
    this.screenKey,
  });

  final Widget child;
  final String? screenKey;

  @override
  Widget build(BuildContext context) {
    if (!BaseCampPresentation.isActive(context)) return child;
    if (BaseCampTerminalPaletteScope.maybeOf(context) != null) return child;
    return ValueListenableBuilder<DeviceSettings>(
      valueListenable: DeviceSettingsController.instance,
      builder: (context, settings, _) {
        final palette = BaseCampTerminalPalette(
          negative: settings.baseCampLcdNegative,
        );
        return BaseCampTerminalPaletteScope(
          palette: palette,
          child: BaseCampRetroTerminalPanel(
            key: ValueKey<String>(
              'base-camp-retro-terminal-${screenKey ?? 'screen'}',
            ),
            palette: palette,
            child: Theme(
              data: _terminalTheme(Theme.of(context), palette),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// The shared olive housing. Its foreground decoration never receives input.
class BaseCampRetroTerminalPanel extends StatelessWidget {
  const BaseCampRetroTerminalPanel({
    super.key,
    required this.palette,
    required this.child,
  });

  final BaseCampTerminalPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      BaseCampLcdSurface(palette: palette),
      child,
      IgnorePointer(
        child: CustomPaint(
          key: const ValueKey('base-camp-terminal-frame-decoration'),
          painter: const _BaseCampTerminalFramePainter(),
        ),
      ),
    ],
  );
}

/// Static 4px LCD field shared by every approved screen.
class BaseCampLcdSurface extends StatelessWidget {
  const BaseCampLcdSurface({super.key, required this.palette});

  final BaseCampTerminalPalette palette;

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('base-camp-terminal-lcd-surface'),
    color: BaseCampTerminalPalette.housing,
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ColoredBox(
          color: palette.background,
          child: CustomPaint(
            key: const ValueKey('base-camp-terminal-lcd-grid'),
            painter: BaseCampLcdGrainPainter(
              negative: palette.negative,
              alpha: .08,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Shared section-header styling for terminal-specific modules.
class BaseCampTerminalSectionHeader extends StatelessWidget {
  const BaseCampTerminalSectionHeader({
    super.key,
    required this.child,
    this.indicator = true,
  });

  final Widget child;
  final bool indicator;

  @override
  Widget build(BuildContext context) {
    final palette = BaseCampTerminalPaletteScope.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.field,
        border: Border(bottom: BorderSide(color: palette.auxiliaryText)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: <Widget>[
            if (indicator) ...[
              const BaseCampTerminalIndicator(),
              const SizedBox(width: 7),
            ],
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Reusable field boundary that preserves the wrapped control's geometry.
class BaseCampLcdField extends StatelessWidget {
  const BaseCampLcdField({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = BaseCampTerminalPaletteScope.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.field,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.auxiliaryText),
      ),
      child: child,
    );
  }
}

/// Opaque content surface for legacy feature widgets that previously painted
/// their own translucent/glass material. It changes presentation only; the
/// wrapped widget retains its layout, semantics and input behavior.
/// Small non-semantic field-terminal lamp.
class BaseCampTerminalIndicator extends StatelessWidget {
  const BaseCampTerminalIndicator({super.key, this.active = false});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = BaseCampTerminalPaletteScope.of(context);
    return ExcludeSemantics(
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? palette.primaryText : palette.auxiliaryText,
          border: Border.all(color: palette.primaryText, width: .7),
        ),
      ),
    );
  }
}

ThemeData _terminalTheme(ThemeData base, BaseCampTerminalPalette palette) {
  final extensions = base.extensions.values.toList(growable: true)
    ..removeWhere((extension) => extension is OperationSurfaceTheme)
    ..add(
      OperationSurfaceTheme(
        useClassicTerminal: true,
        buttonForegroundColor: palette.primaryText,
        buttonDisabledForegroundColor: palette.background.withValues(
          alpha: .65,
        ),
      ),
    );
  final scheme = base.colorScheme.copyWith(
    primary: palette.primaryText,
    onPrimary: palette.background,
    secondary: palette.auxiliaryText,
    onSecondary: palette.background,
    surface: palette.background,
    onSurface: palette.primaryText,
    surfaceContainerLowest: palette.background,
    surfaceContainerLow: palette.field,
    surfaceContainer: palette.field,
    surfaceContainerHigh: palette.field,
    surfaceContainerHighest: palette.field,
    outline: palette.auxiliaryText,
    outlineVariant: palette.auxiliaryText.withValues(alpha: .72),
  );
  final textTheme = base.textTheme.apply(
    bodyColor: palette.primaryText,
    displayColor: palette.primaryText,
  );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: palette.background,
    cardColor: palette.field,
    dividerColor: palette.auxiliaryText,
    textTheme: textTheme,
    primaryTextTheme: base.primaryTextTheme.apply(
      bodyColor: palette.primaryText,
      displayColor: palette.primaryText,
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: BaseCampTerminalPalette.housing,
      foregroundColor: palette.background,
      surfaceTintColor: Colors.transparent,
      shadowColor: BaseCampTerminalPalette.housingShadow,
    ),
    cardTheme: base.cardTheme.copyWith(
      color: palette.field,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: BorderSide(color: palette.auxiliaryText),
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: palette.field,
      labelStyle: TextStyle(color: palette.primaryText),
      hintStyle: TextStyle(color: palette.auxiliaryText),
      enabledBorder: _fieldBorder(palette.auxiliaryText),
      focusedBorder: _fieldBorder(palette.primaryText, width: 1.4),
      disabledBorder: _fieldBorder(
        palette.auxiliaryText.withValues(alpha: .55),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: (base.elevatedButtonTheme.style ?? const ButtonStyle()).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return palette.auxiliaryText;
          }
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.selected)) {
            return palette.primaryText;
          }
          return palette.field;
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.selected)) {
            return palette.background;
          }
          return states.contains(WidgetState.disabled)
              ? palette.background.withValues(alpha: .65)
              : palette.primaryText;
        }),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: palette.auxiliaryText),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: (base.outlinedButtonTheme.style ?? const ButtonStyle()).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return palette.auxiliaryText;
          }
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.selected)) {
            return palette.primaryText;
          }
          return palette.field;
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.selected)) {
            return palette.background;
          }
          return states.contains(WidgetState.disabled)
              ? palette.background.withValues(alpha: .65)
              : palette.primaryText;
        }),
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: palette.auxiliaryText),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: (base.textButtonTheme.style ?? const ButtonStyle()).copyWith(
        foregroundColor: WidgetStatePropertyAll<Color>(palette.primaryText),
        overlayColor: WidgetStatePropertyAll<Color>(
          palette.primaryText.withValues(alpha: .10),
        ),
      ),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: palette.background,
      surfaceTintColor: Colors.transparent,
      shadowColor: BaseCampTerminalPalette.housingShadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: BorderSide(color: palette.auxiliaryText),
      ),
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: palette.background,
      modalBackgroundColor: palette.background,
      surfaceTintColor: Colors.transparent,
      shadowColor: BaseCampTerminalPalette.housingShadow,
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      color: palette.background,
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(color: palette.primaryText),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: palette.auxiliaryText),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: TextStyle(color: palette.primaryText),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.field,
        enabledBorder: _fieldBorder(palette.auxiliaryText),
        focusedBorder: _fieldBorder(palette.primaryText, width: 1.4),
      ),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(palette.background),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: palette.auxiliaryText),
        ),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(palette.background),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: palette.auxiliaryText),
        ),
      ),
    ),
    listTileTheme: base.listTileTheme.copyWith(
      textColor: palette.primaryText,
      iconColor: palette.primaryText,
      selectedColor: palette.background,
      selectedTileColor: palette.primaryText,
    ),
    dividerTheme: base.dividerTheme.copyWith(
      color: palette.auxiliaryText,
      space: 1,
      thickness: 1,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: palette.field,
      selectedColor: palette.primaryText,
      disabledColor: palette.auxiliaryText,
      labelStyle: TextStyle(color: palette.primaryText),
      secondaryLabelStyle: TextStyle(color: palette.background),
      side: BorderSide(color: palette.auxiliaryText),
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    iconTheme: base.iconTheme.copyWith(color: palette.primaryText),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: palette.primaryText,
      inactiveTrackColor: palette.auxiliaryText,
      thumbColor: palette.primaryText,
      overlayColor: palette.primaryText.withValues(alpha: .12),
    ),
    switchTheme: base.switchTheme.copyWith(
      thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) return palette.background;
        return palette.auxiliaryText;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) return palette.primaryText;
        return palette.field;
      }),
      trackOutlineColor: WidgetStatePropertyAll<Color>(palette.auxiliaryText),
    ),
    checkboxTheme: base.checkboxTheme.copyWith(
      fillColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) return palette.primaryText;
        return palette.field;
      }),
      checkColor: WidgetStatePropertyAll<Color>(palette.background),
      side: BorderSide(color: palette.auxiliaryText),
    ),
    radioTheme: base.radioTheme.copyWith(
      fillColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) return palette.primaryText;
        return palette.auxiliaryText;
      }),
    ),
    floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
      backgroundColor: palette.field,
      foregroundColor: palette.primaryText,
      focusColor: palette.primaryText.withValues(alpha: .12),
      hoverColor: palette.primaryText.withValues(alpha: .08),
      splashColor: palette.primaryText.withValues(alpha: .12),
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: palette.auxiliaryText),
      ),
    ),
    datePickerTheme: base.datePickerTheme.copyWith(
      backgroundColor: palette.background,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: palette.field,
      headerForegroundColor: palette.primaryText,
      dayForegroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) return palette.background;
        return palette.primaryText;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) return palette.primaryText;
        return null;
      }),
      todayForegroundColor: WidgetStatePropertyAll<Color>(palette.primaryText),
      todayBorder: BorderSide(color: palette.primaryText),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: palette.auxiliaryText),
      ),
    ),
    timePickerTheme: base.timePickerTheme.copyWith(
      backgroundColor: palette.background,
      dialBackgroundColor: palette.field,
      dialHandColor: palette.primaryText,
      dialTextColor: palette.primaryText,
      hourMinuteColor: palette.field,
      hourMinuteTextColor: palette.primaryText,
      entryModeIconColor: palette.primaryText,
      dayPeriodColor: palette.field,
      dayPeriodTextColor: palette.primaryText,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: palette.auxiliaryText),
      ),
    ),
    extensions: extensions,
  );
}

OutlineInputBorder _fieldBorder(Color color, {double width = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: color, width: width),
    );

class _BaseCampTerminalFramePainter extends CustomPainter {
  const _BaseCampTerminalFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final outer = Paint()
      ..color = BaseCampTerminalPalette.housingEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final inner = Paint()
      ..color = BaseCampTerminalPalette.housingShadow.withValues(alpha: .8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
        const Radius.circular(10),
      ),
      outer,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(5, 5, size.width - 10, size.height - 10),
        const Radius.circular(7),
      ),
      inner,
    );
    final screw = Paint()..color = BaseCampTerminalPalette.housingEdge;
    for (final point in <Offset>[
      const Offset(8, 8),
      Offset(size.width - 8, 8),
      Offset(8, size.height - 8),
      Offset(size.width - 8, size.height - 8),
    ]) {
      canvas.drawCircle(point, 1.7, screw);
    }
  }

  @override
  bool shouldRepaint(covariant _BaseCampTerminalFramePainter oldDelegate) =>
      false;
}
