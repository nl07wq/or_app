import 'dart:ui';

import 'package:flutter/material.dart';

import '../../themes/base_camp/base_camp_presentation.dart';

/// FOOD success feedback only. The floating SnackBar keeps the existing
/// ScaffoldMessenger lifecycle, keyboard avoidance, and route hand-off.
class FoodSavedFloatingHud {
  const FoodSavedFloatingHud._();

  static const _accent = Color(0xff33d6f2);
  static const _iceBlue = Color(0xffe2f9ff);
  static const _confirmed = Color(0xff65a5b8);

  static Widget _surface({
    String label = 'MEAL',
    String successLabel = 'SAVED',
    bool failed = false,
    String? detail,
  }) => _FoodSavedFloatingHudSurface(
    label: label,
    successLabel: successLabel,
    failed: failed,
    detail: detail,
  );

  @visibleForTesting
  static Widget surfaceForTesting({
    String label = 'MEAL',
    String successLabel = 'SAVED',
    bool failed = false,
    String? detail,
  }) => _surface(
    label: label,
    successLabel: successLabel,
    failed: failed,
    detail: detail,
  );

  static void show(BuildContext context) {
    showFor(context, label: 'MEAL');
  }

  static void showFor(
    BuildContext context, {
    required String label,
    String successLabel = 'SAVED',
    bool failed = false,
    String? detail,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.fromLTRB(32, 0, 32, 16),
          duration: Duration(seconds: detail == null ? 2 : 3),
          dismissDirection: DismissDirection.down,
          content: _surface(
            label: label,
            successLabel: successLabel,
            failed: failed,
            detail: detail,
          ),
        ),
      );
  }
}

class _FoodSavedFloatingHudSurface extends StatelessWidget {
  const _FoodSavedFloatingHudSurface({
    required this.label,
    required this.successLabel,
    required this.failed,
    this.detail,
  });
  final String label;
  final String successLabel;
  final bool failed;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final classicTerminal = BaseCampPresentation.isActive(context);
    final scheme = Theme.of(context).colorScheme;
    final content = DecoratedBox(
      key: const ValueKey('food-saved-floating-hud-glass'),
      decoration: BoxDecoration(
        color: classicTerminal ? scheme.surfaceContainerHighest : null,
        gradient: classicTerminal
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xbc2d4b60), Color(0x9c162b3d)],
              ),
        border: Border.all(
          color: classicTerminal ? scheme.outline : const Color(0xc078a8b8),
        ),
        borderRadius: BorderRadius.circular(classicTerminal ? 4 : 14),
        boxShadow: classicTerminal
            ? const <BoxShadow>[]
            : const [
                BoxShadow(
                  color: Color(0x55020c16),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: detail == null ? 0 : 8),
        child: Center(
          // Keep the row constrained to the full HUD so its center is
          // stable on mobile web. The accent belongs to the label
          // group, not to the outer bottom border.
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              failed
                                  ? Icons.error_outline_rounded
                                  : Icons.check_circle_rounded,
                              size: 19,
                              color: failed
                                  ? const Color(0xffff9ea9)
                                  : classicTerminal
                                  ? scheme.primary
                                  : FoodSavedFloatingHud._accent,
                            ),
                            SizedBox(width: 9),
                            Text(
                              '$label ${failed ? 'SAVE FAILED' : successLabel}',
                              style: TextStyle(
                                color: failed
                                    ? const Color(0xffffdce1)
                                    : classicTerminal
                                    ? scheme.onSurface
                                    : FoodSavedFloatingHud._iceBlue,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.05,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              failed ? 'REJECTED' : 'CONFIRMED',
                              style: TextStyle(
                                color: failed
                                    ? const Color(0xffe8a3b1)
                                    : classicTerminal
                                    ? scheme.onSurfaceVariant
                                    : FoodSavedFloatingHud._confirmed,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: .7,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          key: const ValueKey(
                            'food-saved-floating-hud-inner-line',
                          ),
                          height: 1,
                          width: double.infinity,
                          child: ColoredBox(
                            color: failed
                                ? const Color(0xffff9ea9)
                                : classicTerminal
                                ? scheme.primary
                                : FoodSavedFloatingHud._accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (detail != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      detail!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: classicTerminal
                            ? scheme.onSurface
                            : const Color(0xffffd5dc),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return SizedBox(
      key: const ValueKey('food-saved-floating-hud'),
      height: detail == null ? 46 : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(classicTerminal ? 4 : 14),
        child: classicTerminal
            ? content
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4.5, sigmaY: 4.5),
                child: content,
              ),
      ),
    );
  }
}
