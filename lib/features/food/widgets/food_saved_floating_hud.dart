import 'dart:ui';

import 'package:flutter/material.dart';

/// FOOD success feedback only. The floating SnackBar keeps the existing
/// ScaffoldMessenger lifecycle, keyboard avoidance, and route hand-off.
class FoodSavedFloatingHud {
  const FoodSavedFloatingHud._();

  static const _accent = Color(0xff33d6f2);
  static const _iceBlue = Color(0xffe2f9ff);
  static const _confirmed = Color(0xff65a5b8);

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
          content: const _FoodSavedFloatingHudSurface(),
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
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xd62d4b60), Color(0xbf162b3d)],
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Row(
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
                    Spacer(),
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
              ),
              const Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: 1,
                  width: double.infinity,
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
    ),
  );
}
