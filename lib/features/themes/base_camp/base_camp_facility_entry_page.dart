import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/core/theme/app_spacing.dart';
import 'package:or_app/core/widgets/operation_card.dart';
import 'package:or_app/features/themes/base_camp/base_camp_dashboard_page.dart'
    show BaseCampLcdGrainPainter;

const baseCampStatusEntryAsset =
    'assets/images/themes/base_camp/entry/status.jpg';
const baseCampActivityEntryAsset =
    'assets/images/themes/base_camp/entry/activity.jpg';
const baseCampFoodEntryAsset = 'assets/images/themes/base_camp/entry/food.jpg';
const baseCampTrainingEntryAsset =
    'assets/images/themes/base_camp/entry/training.jpg';
const baseCampCommandCenterEntryAsset =
    'assets/images/themes/base_camp/entry/command_center.jpg';

/// Static BASE CAMP facility entrance used only by the five map modules.
/// Business actions are supplied by the existing feature pages so this layer
/// never owns or copies formal records.
class BaseCampFacilityEntryPage extends StatelessWidget {
  const BaseCampFacilityEntryPage({
    super.key,
    required this.title,
    required this.imageAsset,
    required this.actions,
  });

  final String title;
  final String imageAsset;
  final List<BaseCampFacilityEntryAction> actions;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final cacheWidth = math
        .max(512, mediaQuery.size.width * mediaQuery.devicePixelRatio)
        .round()
        .clamp(512, 1536);
    return Scaffold(
      key: ValueKey('base-camp-${title.toLowerCase()}-facility-entry'),
      backgroundColor: const Color(0xff11150f),
      appBar: AppBar(
        backgroundColor: const Color(0xff1a2016),
        foregroundColor: const Color(0xffe8e2c9),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Text(title),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final imageHeight = math.min(
            constraints.maxWidth * 9 / 16,
            constraints.maxHeight * .27,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: imageHeight,
                    constraints: const BoxConstraints(minHeight: 132),
                    foregroundDecoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xff77745b),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.asset(
                      imageAsset,
                      key: ValueKey('base-camp-facility-image-$title'),
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      cacheWidth: cacheWidth,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(
                            color: Color(0xff20251b),
                            child: Center(
                              child: Text(
                                'FACILITY IMAGE UNAVAILABLE',
                                style: TextStyle(color: Color(0xffc8c2a6)),
                              ),
                            ),
                          ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: ValueKey(
                    'base-camp-${title.toLowerCase()}-facility-menu-scroll',
                  ),
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    mediaQuery.padding.bottom + AppSpacing.lg,
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(
                      'base-camp-${title.toLowerCase()}-facility-menu',
                    ),
                    child: ValueListenableBuilder<DeviceSettings>(
                      valueListenable: DeviceSettingsController.instance,
                      builder: (context, settings, _) =>
                          _BaseCampModuleTerminal(
                            negative: settings.baseCampLcdNegative,
                            actions: actions,
                          ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BaseCampModuleTerminal extends StatelessWidget {
  const _BaseCampModuleTerminal({
    required this.negative,
    required this.actions,
  });

  final bool negative;
  final List<BaseCampFacilityEntryAction> actions;

  @override
  Widget build(BuildContext context) {
    final palette = _BaseCampEntryLcdPalette(negative);
    return Container(
      key: const ValueKey('base-camp-module-terminal-housing'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xff1c2318),
        border: Border.all(color: const Color(0xff77745b), width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xff252d20),
              border: Border.all(color: const Color(0xff4f5943)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'MODULE TERMINAL',
                        key: const ValueKey('base-camp-module-terminal-title'),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: const Color(0xffd5d0b5),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      key: const ValueKey('base-camp-module-terminal-link'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xff182015),
                        border: Border.all(color: const Color(0xff697451)),
                      ),
                      child: const Text(
                        'LINK',
                        style: TextStyle(
                          color: Color(0xffb7d66b),
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Stack(
                    children: [
                      ColoredBox(
                        key: const ValueKey(
                          'base-camp-module-terminal-lcd-interior',
                        ),
                        color: palette.base,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: _BaseCampEntryTerminalMode(
                            palette: palette,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (
                                  var index = 0;
                                  index < actions.length;
                                  index++
                                ) ...[
                                  actions[index],
                                  if (index != actions.length - 1) ...[
                                    const SizedBox(height: 5),
                                    Divider(
                                      key: ValueKey(
                                        'base-camp-module-terminal-separator-$index',
                                      ),
                                      height: 1,
                                      thickness: 1,
                                      color: palette.auxiliary.withValues(
                                        alpha: .45,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            key: const ValueKey(
                              'base-camp-module-terminal-lcd-grain',
                            ),
                            painter: BaseCampLcdGrainPainter(
                              negative: negative,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TerminalDecorationIndicator(),
                    SizedBox(width: 7),
                    _TerminalDecorationIndicator(),
                    SizedBox(width: 7),
                    _TerminalDecorationIndicator(),
                  ],
                ),
              ],
            ),
          ),
          const Positioned(left: 5, top: 5, child: _TerminalScrew()),
          const Positioned(right: 5, top: 5, child: _TerminalScrew()),
          const Positioned(left: 5, bottom: 5, child: _TerminalScrew()),
          const Positioned(right: 5, bottom: 5, child: _TerminalScrew()),
        ],
      ),
    );
  }
}

class _TerminalScrew extends StatelessWidget {
  const _TerminalScrew();

  @override
  Widget build(BuildContext context) => Container(
    width: 4,
    height: 4,
    decoration: const BoxDecoration(
      color: Color(0xffa09b7b),
      shape: BoxShape.circle,
    ),
  );
}

class _TerminalDecorationIndicator extends StatelessWidget {
  const _TerminalDecorationIndicator();

  @override
  Widget build(BuildContext context) => Container(
    width: 16,
    height: 4,
    decoration: BoxDecoration(
      color: const Color(0xff11170f),
      borderRadius: BorderRadius.circular(2),
      border: Border.all(color: const Color(0xff4f5943)),
    ),
  );
}

class BaseCampFacilityEntryAction extends StatefulWidget {
  const BaseCampFacilityEntryAction({
    super.key,
    required this.description,
    required this.child,
    this.supplementary,
  });

  final String description;
  final Widget child;
  final Widget? supplementary;

  @override
  State<BaseCampFacilityEntryAction> createState() =>
      _BaseCampFacilityEntryActionState();
}

class _BaseCampFacilityEntryActionState
    extends State<BaseCampFacilityEntryAction> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _BaseCampEntryTerminalMode.of(context);
    final baseTheme = Theme.of(context);
    final extensions = <ThemeExtension<dynamic>>[
      OperationSurfaceTheme(
        flattenSurface: true,
        buttonForegroundColor: palette.primary,
        buttonDisabledForegroundColor: palette.auxiliary,
        buttonHeight: 56,
      ),
    ];
    return Column(
      key: const ValueKey('base-camp-module-terminal-action'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.description,
          key: const ValueKey('base-camp-module-terminal-description'),
          style: baseTheme.textTheme.bodyMedium?.copyWith(
            color: palette.auxiliary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        Listener(
          onPointerDown: (_) => _setPressed(true),
          onPointerUp: (_) => _setPressed(false),
          onPointerCancel: (_) => _setPressed(false),
          child: Container(
            key: const ValueKey('base-camp-module-terminal-action-surface'),
            height: 56,
            decoration: BoxDecoration(
              color: palette.field,
              border: Border.all(
                color: palette.auxiliary.withValues(alpha: .65),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: Theme(
                      data: baseTheme.copyWith(extensions: extensions),
                      child: widget.child,
                    ),
                  ),
                ),
                Positioned(
                  left: 9,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: AnimatedContainer(
                      key: const ValueKey(
                        'base-camp-module-terminal-action-indicator',
                      ),
                      duration: const Duration(milliseconds: 80),
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: _pressed
                            ? const Color(0xffb7e34d)
                            : const Color(0xff253020),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _pressed
                              ? const Color(0xffddff78)
                              : const Color(0xff526047),
                        ),
                        boxShadow: _pressed
                            ? const [
                                BoxShadow(
                                  color: Color(0x99b7e34d),
                                  blurRadius: 5,
                                ),
                              ]
                            : const [],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.supplementary case final supplementary?) ...[
          const SizedBox(height: 8),
          DefaultTextStyle.merge(
            style: baseTheme.textTheme.bodySmall?.copyWith(
              color: palette.auxiliary,
              height: 1.35,
            ),
            child: supplementary,
          ),
        ],
      ],
    );
  }
}

class _BaseCampEntryTerminalMode extends InheritedWidget {
  const _BaseCampEntryTerminalMode({
    required this.palette,
    required super.child,
  });

  final _BaseCampEntryLcdPalette palette;

  static _BaseCampEntryLcdPalette of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_BaseCampEntryTerminalMode>()!
      .palette;

  @override
  bool updateShouldNotify(_BaseCampEntryTerminalMode oldWidget) =>
      oldWidget.palette.negative != palette.negative;
}

class _BaseCampEntryLcdPalette {
  const _BaseCampEntryLcdPalette(this.negative);

  final bool negative;

  Color get base =>
      negative ? const Color(0xff273326) : const Color(0xffaeb894);
  Color get field =>
      negative ? const Color(0xff485c3f) : const Color(0xff8d9d79);
  Color get primary =>
      negative ? const Color(0xffaeb894) : const Color(0xff273326);
  Color get auxiliary =>
      negative ? const Color(0xff8d9d79) : const Color(0xff485c3f);
}
