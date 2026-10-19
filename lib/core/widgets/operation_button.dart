import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'dashboard_glass_card.dart';
import 'global_touch_ripple.dart';

enum OperationActionRole { primary, secondary, danger }

class OperationButton extends StatelessWidget {
  final String text;

  final VoidCallback? onPressed;

  final IconData? icon;

  final OperationActionRole role;

  /// Lets an explicitly unavailable control report a non-mutating attempted
  /// action while retaining its disabled visual and accessibility semantics.
  final bool reportUnavailableTap;

  /// Defers semantic result feedback until the callback has validated or
  /// persisted its operation. The callback resolves through the shared
  /// [ActionableFeedbackRegion] API, never by choosing a sound asset.
  final bool deferFeedback;

  /// Allows an enclosing production glass surface to remain visible while
  /// retaining the button's established size, text, and interaction contract.
  final bool transparentSurface;
  final bool dashboardGlass;

  /// TRAINING's kinetic backdrop needs local contrast without restoring its
  /// former opaque outer panels. This material is opt-in so other pages keep
  /// their established button surfaces.
  final bool frostedGlass;

  /// Applies the operation-only frosted material whose actual backdrop blur
  /// transitions continuously from strong at the left edge to weak at the
  /// right edge. It is deliberately opt-in so Dashboard Quick Access and
  /// unrelated controls retain their approved materials.
  final bool frostedGradient;

  /// Limits comparison-only controls to their requested audio route without
  /// emitting a COMMAND confirmation for the diagnostic control itself.
  final ActionableFeedbackRole feedbackRole;
  final VoidCallback? onUnavailableTap;

  const OperationButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.role = OperationActionRole.secondary,
    this.reportUnavailableTap = false,
    this.deferFeedback = false,
    this.transparentSurface = false,
    this.dashboardGlass = false,
    this.frostedGlass = false,
    this.frostedGradient = false,
    this.feedbackRole = ActionableFeedbackRole.command,
    this.onUnavailableTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = onPressed == null
        ? Theme.of(context).disabledColor
        : switch (role) {
            OperationActionRole.primary => colorScheme.primary,
            OperationActionRole.secondary => AppTextStyles.label.color!,
            OperationActionRole.danger => colorScheme.error,
          };
    final usesTransparentButtonMaterial =
        transparentSurface || dashboardGlass || frostedGlass || frostedGradient;
    final button = SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: usesTransparentButtonMaterial ? 0 : 4,
          backgroundColor: usesTransparentButtonMaterial
              ? Colors.transparent
              : null,
          shadowColor: usesTransparentButtonMaterial
              ? Colors.transparent
              : null,
          surfaceTintColor: usesTransparentButtonMaterial
              ? Colors.transparent
              : null,
          foregroundColor: foregroundColor,
          disabledForegroundColor: Theme.of(context).disabledColor,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: foregroundColor),
              SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  style: AppTextStyles.label.copyWith(color: foregroundColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final surfaced = frostedGradient || frostedGlass
        ? _OperationFrostedGradientSurface(child: button)
        : dashboardGlass
        ? Container(
            decoration: DashboardGlassCard.decoration(
              colorScheme,
              borderRadius: AppRadius.medium,
            ),
            child: button,
          )
        : button;
    if (onPressed != null) {
      return ActionableFeedbackRegion(
        deferResolution: deferFeedback,
        role: feedbackRole,
        child: surfaced,
      );
    }
    if (!reportUnavailableTap) return surfaced;
    return ActionableFeedbackRegion(
      result: ActionableFeedbackResult.unavailable,
      onPointerDown: onUnavailableTap,
      child: surfaced,
    );
  }
}

/// The weak full-surface pass keeps the right edge glass-like. Two tapered,
/// clipped backdrop layers increase the blur toward the left without using a
/// ShaderMask. This keeps the filtered backdrop separate from the foreground
/// button on Safari's web renderer.
class _OperationFrostedGradientSurface extends StatelessWidget {
  const _OperationFrostedGradientSurface({required this.child});

  final Widget child;

  static const _weakBlur = 1.4;
  static const _mediumBlur = 3.8;
  static const _strongBlur = 7.2;

  @override
  Widget build(BuildContext context) => ClipRRect(
    key: const ValueKey('operation-frosted-gradient'),
    borderRadius: AppRadius.medium,
    child: Stack(
      fit: StackFit.expand,
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _weakBlur, sigmaY: _weakBlur),
          child: const SizedBox.expand(),
        ),
        _LeftTaperedBackdropBlur(
          sigma: _mediumBlur,
          rightExtent: .78,
        ),
        _LeftTaperedBackdropBlur(
          sigma: _strongBlur,
          rightExtent: .48,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0x9c213b4d), Color(0x7c1b3345), Color(0x5415293a)],
              stops: [0, .42, 1],
            ),
            border: Border.all(color: const Color(0x8878a8b8)),
            borderRadius: AppRadius.medium,
            boxShadow: const [
              BoxShadow(
                color: Color(0x33020c16),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
        child,
      ],
    ),
  );
}

class _LeftTaperedBackdropBlur extends StatelessWidget {
  const _LeftTaperedBackdropBlur({
    required this.sigma,
    required this.rightExtent,
  });

  final double sigma;
  final double rightExtent;

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: _LeftTaperClipper(rightExtent),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: const SizedBox.expand(),
    ),
  );
}

class _LeftTaperClipper extends CustomClipper<Path> {
  const _LeftTaperClipper(this.rightExtent);

  final double rightExtent;

  @override
  Path getClip(Size size) {
    final edge = size.width * rightExtent;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(edge * .88, 0)
      ..cubicTo(edge * 1.03, size.height * .20, edge * .75, size.height * .76, edge, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _LeftTaperClipper oldClipper) =>
      oldClipper.rightExtent != rightExtent;
}
