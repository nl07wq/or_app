import 'dart:ui';

import 'package:flutter/material.dart';

/// FOOD success feedback only. The floating SnackBar keeps the existing
/// ScaffoldMessenger lifecycle, keyboard avoidance, and route hand-off.
class FoodSavedFloatingHud {
  const FoodSavedFloatingHud._();

  static const _accent = Color(0xff33d6f2);
  static const _iceBlue = Color(0xffe2f9ff);
  static const _confirmed = Color(0xff65a5b8);

  static Widget _surface({
    String label = 'MEAL',
    bool failed = false,
    String? detail,
  }) => _FoodSavedFloatingHudSurface(
    label: label,
    failed: failed,
    detail: detail,
  );

  @visibleForTesting
  static Widget surfaceForTesting({
    String label = 'MEAL',
    bool failed = false,
    String? detail,
  }) => _surface(label: label, failed: failed, detail: detail);

  static void show(BuildContext context) {
    showFor(context, label: 'MEAL');
  }

  static void showFor(
    BuildContext context, {
    required String label,
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
          content: _surface(label: label, failed: failed, detail: detail),
        ),
      );
  }
}

class _FoodSavedFloatingHudSurface extends StatelessWidget {
  const _FoodSavedFloatingHudSurface({
    required this.label,
    required this.failed,
    this.detail,
  });
  final String label;
  final bool failed;
  final String? detail;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('food-saved-floating-hud'),
    height: detail == null ? 46 : null,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4.5, sigmaY: 4.5),
        child: DecoratedBox(
          key: const ValueKey('food-saved-floating-hud-glass'),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xbc2d4b60), Color(0x9c162b3d)],
            ),
            border: Border.all(color: const Color(0xc078a8b8)),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
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
                                      : FoodSavedFloatingHud._accent,
                                ),
                                SizedBox(width: 9),
                                Text(
                                  '$label ${failed ? 'SAVE FAILED' : 'SAVED'}',
                                  style: TextStyle(
                                    color: failed
                                        ? const Color(0xffffdce1)
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
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xffffd5dc),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
