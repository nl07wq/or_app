import 'package:flutter/material.dart';

import '../../../../core/services/device_settings_controller.dart';
import '../../../../core/widgets/mixed_script_text.dart';
import '../base_camp_retro_terminal.dart';

/// Shared BASE CAMP-only dialog chrome for short, blocking terminal workflows.
///
/// The physical housing and the LCD are deliberately separate. The grid is
/// owned by [BaseCampLcdSurface], so it cannot leak into the modal barrier or
/// the action controls.
class BaseCampTerminalPopup extends StatelessWidget {
  const BaseCampTerminalPopup({
    super.key,
    required this.title,
    required this.stateLabel,
    required this.message,
    this.actions = const <Widget>[],
    this.busy = false,
  });

  final String title;
  final String stateLabel;
  final String message;
  final List<Widget> actions;
  final bool busy;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DeviceSettings>(
    valueListenable: DeviceSettingsController.instance,
    builder: (context, settings, _) {
      final palette = BaseCampTerminalPalette(
        negative: settings.baseCampLcdNegative,
      );
      return BaseCampTerminalPaletteScope(
        palette: palette,
        child: Dialog(
          key: const ValueKey('base-camp-terminal-popup'),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: BaseCampTerminalPalette.housing,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: BaseCampTerminalPalette.housingEdge,
                    width: 2,
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: BaseCampTerminalPalette.housingShadow,
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Stack(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _TerminalPopupHeader(
                            title: title,
                            stateLabel: stateLabel,
                            palette: palette,
                          ),
                          const SizedBox(height: 9),
                          BaseCampLcdSurface(
                            palette: palette,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 14,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 76),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  if (busy) ...<Widget>[
                                    SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        key: const ValueKey(
                                          'base-camp-terminal-popup-progress',
                                        ),
                                        strokeWidth: 2,
                                        color: palette.primaryText,
                                      ),
                                    ),
                                    const SizedBox(width: 11),
                                  ],
                                  Expanded(
                                    child: MixedScriptText(
                                      message,
                                      key: const ValueKey(
                                        'base-camp-terminal-popup-message',
                                      ),
                                      style: TextStyle(
                                        color: palette.primaryText,
                                        fontFamily:
                                            MixedScriptTypography.latinFamily,
                                        fontFamilyFallback: const <String>[
                                          MixedScriptTypography.japaneseFamily,
                                        ],
                                        fontSize: 12,
                                        height: 1.65,
                                        letterSpacing: -.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (actions.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 10),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 7,
                              children: actions,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Positioned(
                      left: 5,
                      top: 5,
                      child: _TerminalPopupScrew(),
                    ),
                    const Positioned(
                      right: 5,
                      top: 5,
                      child: _TerminalPopupScrew(),
                    ),
                    const Positioned(
                      left: 5,
                      bottom: 5,
                      child: _TerminalPopupScrew(),
                    ),
                    const Positioned(
                      right: 5,
                      bottom: 5,
                      child: _TerminalPopupScrew(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class BaseCampTerminalPopupButton extends StatelessWidget {
  const BaseCampTerminalPopupButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final palette = BaseCampTerminalPaletteScope.of(context);
    final background = primary ? palette.primaryText : palette.field;
    final foreground = primary ? palette.background : palette.primaryText;
    return SizedBox(
      height: 38,
      child: OutlinedButton(
        key: ValueKey<String>('base-camp-terminal-popup-action-$label'),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          backgroundColor: onPressed == null
              ? palette.auxiliaryText.withValues(alpha: .55)
              : background,
          foregroundColor: onPressed == null
              ? palette.background.withValues(alpha: .72)
              : foreground,
          disabledForegroundColor: palette.background.withValues(alpha: .72),
          side: BorderSide(color: palette.auxiliaryText),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          textStyle: const TextStyle(
            fontFamily: MixedScriptTypography.latinFamily,
            fontFamilyFallback: <String>[MixedScriptTypography.japaneseFamily],
            fontSize: 10,
            letterSpacing: -.2,
          ),
        ),
        child: Text(label, maxLines: 1),
      ),
    );
  }
}

class _TerminalPopupHeader extends StatelessWidget {
  const _TerminalPopupHeader({
    required this.title,
    required this.stateLabel,
    required this.palette,
  });

  final String title;
  final String stateLabel;
  final BaseCampTerminalPalette palette;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: BaseCampTerminalPalette.housingShadow,
      border: Border.all(color: BaseCampTerminalPalette.housingEdge),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              key: const ValueKey('base-camp-terminal-popup-title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BaseCampTerminalPalette.housingForeground,
                fontFamily: MixedScriptTypography.latinFamily,
                fontSize: 11,
                letterSpacing: -.25,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: palette.field,
              border: Border.all(color: palette.auxiliaryText),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              stateLabel,
              key: const ValueKey('base-camp-terminal-popup-state'),
              maxLines: 1,
              style: TextStyle(
                color: palette.primaryText,
                fontFamily: MixedScriptTypography.latinFamily,
                fontSize: 8,
                letterSpacing: -.2,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _TerminalPopupScrew extends StatelessWidget {
  const _TerminalPopupScrew();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: BaseCampTerminalPalette.housingEdge,
      border: Border.all(color: BaseCampTerminalPalette.housingShadow),
    ),
    child: const SizedBox.square(dimension: 5),
  );
}
