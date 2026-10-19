import 'dart:ui';

import 'package:flutter/material.dart';

/// FOOD success feedback only. The floating SnackBar keeps the existing
/// ScaffoldMessenger lifecycle, keyboard avoidance, and route hand-off.
class FoodSavedFloatingHud {
  const FoodSavedFloatingHud._();

  static const _accent = Color(0xff33d6f2);
  static const _iceBlue = Color(0xffe2f9ff);
  static const _confirmed = Color(0xff65a5b8);

  static Widget _surface() => const _FoodSavedFloatingHudSurface();

  @visibleForTesting
  static Widget surfaceForTesting() => _surface();

  static void show(BuildContext context) {
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
          duration: const Duration(seconds: 2),
          dismissDirection: DismissDirection.down,
          content: _surface(),
        ),
      );
  }
}

class _FoodSavedFloatingHudSurface extends StatelessWidget {
  const _FoodSavedFloatingHudSurface();

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('food-saved-floating-hud'),
    height: 46,
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
          child: Stack(
            children: [
              const Positioned.fill(
                // Keep the row constrained to the full HUD so its center is
                // stable on mobile web. The accent belongs to the label
                // group, not to the outer bottom border.
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 19,
                            color: FoodSavedFloatingHud._accent,
                          ),
                          SizedBox(width: 9),
                          Text(
                            'MEAL SAVED',
                            style: TextStyle(
                              color: FoodSavedFloatingHud._iceBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.05,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'CONFIRMED',
                            style: TextStyle(
                              color: FoodSavedFloatingHud._confirmed,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .7,
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        key: ValueKey('food-saved-floating-hud-inner-line'),
                        left: 28,
                        right: 0,
                        top: 19,
                        child: SizedBox(
                          height: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: FoodSavedFloatingHud._accent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
