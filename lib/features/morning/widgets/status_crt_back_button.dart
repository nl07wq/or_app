import 'package:flutter/material.dart';

/// A standard Back affordance rendered with the STATUS CRT phosphor language.
/// System and browser navigation remain under Navigator's normal control.
class StatusCrtBackButton extends StatefulWidget {
  const StatusCrtBackButton({super.key});

  static const exitDuration = Duration(milliseconds: 180);

  @override
  State<StatusCrtBackButton> createState() => _StatusCrtBackButtonState();
}

class _StatusCrtBackButtonState extends State<StatusCrtBackButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _exitController;
  bool _popRequested = false;

  @override
  void initState() {
    super.initState();
    _exitController = AnimationController(
      vsync: this,
      duration: StatusCrtBackButton.exitDuration,
    );
  }

  void _handlePressed() {
    if (_popRequested || _exitController.isAnimating) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _popOnce();
      return;
    }
    _exitController.forward(from: 0).whenComplete(_popOnce);
  }

  void _popOnce() {
    if (!mounted || _popRequested) return;
    _popRequested = true;
    Navigator.maybePop(context);
  }

  @override
  void dispose() {
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tooltip = MaterialLocalizations.of(context).backButtonTooltip;
    return Semantics(
      button: true,
      label: tooltip,
      child: IconButton(
        key: const ValueKey('status-crt-back'),
        tooltip: tooltip,
        onPressed: _handlePressed,
        icon: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _exitController,
            builder: (context, child) {
              final progress = Curves.easeInCubic.transform(
                _exitController.value,
              );
              final scaleX = 1 - progress * .82;
              final opacity = 1 - progress * .9;
              final offset = -progress * 5;
              return Transform.translate(
                offset: Offset(offset, 0),
                child: Transform.scale(
                  key: const ValueKey('status-crt-back-exit'),
                  scaleX: scaleX,
                  alignment: Alignment.centerLeft,
                  child: Opacity(
                    opacity: opacity,
                    child: Stack(
                      alignment: Alignment.center,
                      children: const [
                        Icon(
                          Icons.arrow_back,
                          color: Color(0x423BCAB9),
                          size: 25,
                        ),
                        Icon(
                          Icons.arrow_back,
                          color: Color(0xFF6EBAAD),
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
