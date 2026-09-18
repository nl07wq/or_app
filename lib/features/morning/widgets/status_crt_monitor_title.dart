import 'package:flutter/material.dart';

/// The shared STATUS AppBar monitor. Its boot sequence is presentation-only.
class StatusCrtMonitorTitle extends StatefulWidget {
  const StatusCrtMonitorTitle({super.key});

  static const width = 128.0;
  static const height = 34.0;
  static const bootDuration = Duration(milliseconds: 820);

  @override
  State<StatusCrtMonitorTitle> createState() => _StatusCrtMonitorTitleState();
}

class _StatusCrtMonitorTitleState extends State<StatusCrtMonitorTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bootController;
  bool _bootRequested = false;

  @override
  void initState() {
    super.initState();
    _bootController = AnimationController(
      vsync: this,
      duration: StatusCrtMonitorTitle.bootDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _bootController.value = 1;
      return;
    }
    if (_bootRequested || !TickerMode.valuesOf(context).enabled) return;
    _bootRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && TickerMode.valuesOf(context).enabled) {
        _bootController.forward();
      }
    });
  }

  @override
  void dispose() {
    _bootController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'STATUS',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            key: const ValueKey('status-crt-monitor-title'),
            width: StatusCrtMonitorTitle.width,
            height: StatusCrtMonitorTitle.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF111719),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0xFF536165), width: .8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: ClipRRect(
                  key: const ValueKey('status-crt-screen'),
                  borderRadius: BorderRadius.circular(4),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, -.1),
                        radius: 1.15,
                        colors: [
                          Color(0xFF122B2D),
                          Color(0xFF081415),
                          Color(0xFF050B0C),
                        ],
                        stops: [0, .62, 1],
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const CustomPaint(
                          key: ValueKey('status-crt-scanlines'),
                          painter: _CrtScanlinesPainter(),
                        ),
                        AnimatedBuilder(
                          animation: _bootController,
                          builder: (context, _) {
                            final value = _bootController.value;
                            final screenOpacity = Curves.easeOut.transform(
                              (value / .24).clamp(0.0, 1.0),
                            );
                            final wakeOpacity =
                                1 -
                                Curves.easeOut.transform(
                                  ((value - .05) / .2).clamp(0.0, 1.0),
                                );
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                if (wakeOpacity > 0)
                                  Opacity(
                                    opacity: wakeOpacity * .34,
                                    child: const Align(
                                      key: ValueKey('status-crt-boot-wake'),
                                      alignment: Alignment.center,
                                      child: SizedBox(
                                        height: 1.2,
                                        child: ColoredBox(
                                          color: Color(0xFF78D7C8),
                                        ),
                                      ),
                                    ),
                                  ),
                                Opacity(
                                  opacity: screenOpacity,
                                  child: Center(
                                    child: Text(
                                      _terminalText(value),
                                      key: const ValueKey(
                                        'status-crt-phosphor',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.clip,
                                      style: const TextStyle(
                                        color: Color(0xFF91E3D1),
                                        fontFamily: 'ShareTechMono',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                        height: 1,
                                        letterSpacing: .2,
                                        shadows: [
                                          Shadow(
                                            color: Color(0x7A3BCAB9),
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _terminalText(double value) {
    if (value < .24) return '';
    if (value < .38) return '>';
    if (value < .54) return '> STA';
    if (value < .7) return '> STATUS';
    return '> STATUS_';
  }
}

class _CrtScanlinesPainter extends CustomPainter {
  const _CrtScanlinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0x18000000)
      ..strokeWidth = .6;
    for (var y = 1.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant _CrtScanlinesPainter oldDelegate) => false;
}
