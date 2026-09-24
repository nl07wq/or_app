import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// The command center's compact, route-aware console header.
///
/// Navigation remains owned by the enclosing [Navigator]; this widget only
/// presents the caller-provided real back action inside the HUD surface.
class CommandCenterHudSign extends StatelessWidget {
  const CommandCenterHudSign({super.key, required this.canPop, this.onBack});

  static const height = 52.0;
  static const backKey = ValueKey('command-center-hud-back');
  static const signKey = ValueKey('command-center-hud-sign');

  final bool canPop;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = colors.primary.withValues(alpha: 0.72);

    return Semantics(
      container: true,
      label: 'COMMANDER CENTER HUD',
      child: SizedBox(
        key: signKey,
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _HudFramePainter(
            lineColor: accent,
            fillColor: colors.surface.withValues(alpha: 0.34),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Row(
              children: [
                if (canPop)
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      key: backKey,
                      tooltip: 'Back',
                      onPressed: onBack,
                      icon: const Icon(Symbols.chevron_left),
                    ),
                  )
                else
                  const SizedBox(width: 12),
                SizedBox(width: canPop ? 8 : 4),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'COMMANDER CENTER',
                          maxLines: 1,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .7,
                                color: colors.onSurface,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HudFramePainter extends CustomPainter {
  const _HudFramePainter({required this.lineColor, required this.fillColor});

  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    const cut = 7.0;
    final frame = Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, cut)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..lineTo(0, cut)
      ..close();
    canvas.drawPath(frame, Paint()..color = fillColor);
    canvas.drawPath(
      frame,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final detail = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(14, 10), const Offset(42, 10), detail);
    canvas.drawLine(
      Offset(size.width - 42, size.height - 10),
      Offset(size.width - 14, size.height - 10),
      detail,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width - 18, 12, 3, 3),
      Paint()..color = lineColor,
    );
  }

  @override
  bool shouldRepaint(covariant _HudFramePainter oldDelegate) =>
      oldDelegate.lineColor != lineColor || oldDelegate.fillColor != fillColor;
}
