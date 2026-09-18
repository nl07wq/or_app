import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

enum StatusCrtMonitorMode { normal, entry }

/// The shared STATUS AppBar monitor. All motion is presentation-only.
class StatusCrtMonitorTitle extends StatefulWidget {
  const StatusCrtMonitorTitle({
    super.key,
    this.mode = StatusCrtMonitorMode.normal,
    this.refreshMinDelay = const Duration(seconds: 10),
    this.refreshMaxDelay = const Duration(seconds: 25),
    this.nextInt,
  });

  static const width = 128.0;
  static const height = 34.0;
  static const bootDuration = Duration(milliseconds: 820);
  static const refreshDuration = Duration(milliseconds: 460);

  final StatusCrtMonitorMode mode;
  final Duration refreshMinDelay;
  final Duration refreshMaxDelay;
  final int Function(int max)? nextInt;

  @override
  State<StatusCrtMonitorTitle> createState() => _StatusCrtMonitorTitleState();
}

class _StatusCrtMonitorTitleState extends State<StatusCrtMonitorTitle>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _bootController;
  late final AnimationController _refreshController;
  final Random _random = Random();
  Timer? _refreshTimer;
  bool _bootRequested = false;
  bool _bootCompleted = false;
  bool _motionEnabled = true;
  bool _appActive = true;

  bool get _isEntry => widget.mode == StatusCrtMonitorMode.entry;
  bool get _canAnimate =>
      _motionEnabled && _appActive && TickerMode.valuesOf(context).enabled;
  int _nextInt(int max) => widget.nextInt?.call(max) ?? _random.nextInt(max);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootController = AnimationController(
      vsync: this,
      duration: StatusCrtMonitorTitle.bootDuration,
    )..addStatusListener(_handleBootStatus);
    _refreshController = AnimationController(
      vsync: this,
      duration: StatusCrtMonitorTitle.refreshDuration,
    )..addStatusListener(_handleRefreshStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _motionEnabled = false;
      _refreshTimer?.cancel();
      _bootCompleted = true;
      _bootController.value = 1;
      _refreshController.value = 0;
      return;
    }
    _motionEnabled = true;
    if (!_canAnimate) {
      _refreshTimer?.cancel();
      _refreshController.stop();
      return;
    }
    if (!_bootRequested) {
      _bootRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _canAnimate) _bootController.forward();
      });
    } else if (_bootCompleted &&
        _isEntry &&
        !_refreshController.isAnimating &&
        _refreshTimer == null) {
      _scheduleRefresh();
    }
  }

  @override
  void didUpdateWidget(covariant StatusCrtMonitorTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode == widget.mode) return;
    _refreshTimer?.cancel();
    if (_isEntry && _bootCompleted && _canAnimate) _scheduleRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_appActive == active) return;
    _appActive = active;
    if (!active) {
      _refreshTimer?.cancel();
      _refreshController.stop();
      return;
    }
    if (_canAnimate && _bootCompleted && _isEntry) _scheduleRefresh();
  }

  void _handleBootStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _bootCompleted = true;
    _scheduleRefresh();
  }

  void _handleRefreshStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _refreshController.value = 0;
    _scheduleRefresh();
  }

  void _scheduleRefresh() {
    if (!_isEntry || !_bootCompleted || !_motionEnabled || !_appActive) return;
    _refreshTimer?.cancel();
    final minimum = widget.refreshMinDelay.inMilliseconds;
    final maximum = widget.refreshMaxDelay.inMilliseconds;
    final delay = minimum + _nextInt(maximum - minimum + 1);
    _refreshTimer = Timer(Duration(milliseconds: delay), _beginRefresh);
  }

  void _beginRefresh() {
    _refreshTimer = null;
    if (!mounted || !_isEntry || !_canAnimate) return;
    _refreshController.forward(from: 0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _bootController
      ..removeStatusListener(_handleBootStatus)
      ..dispose();
    _refreshController
      ..removeStatusListener(_handleRefreshStatus)
      ..dispose();
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
                          animation: Listenable.merge([
                            _bootController,
                            _refreshController,
                          ]),
                          builder: (context, _) => _CrtPhosphorContent(
                            bootValue: _bootController.value,
                            refreshValue: _refreshController.value,
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
      ),
    );
  }
}

class _CrtPhosphorContent extends StatelessWidget {
  const _CrtPhosphorContent({
    required this.bootValue,
    required this.refreshValue,
  });

  final double bootValue;
  final double refreshValue;

  @override
  Widget build(BuildContext context) {
    final screenOpacity = Curves.easeOut.transform(
      (bootValue / .24).clamp(0.0, 1.0),
    );
    final wakeOpacity =
        1 - Curves.easeOut.transform(((bootValue - .05) / .2).clamp(0.0, 1.0));
    final retrace = _RetraceGeometry.from(refreshValue);
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
                child: ColoredBox(color: Color(0xFF78D7C8)),
              ),
            ),
          ),
        if (retrace.lineOpacity > 0)
          Opacity(
            opacity: retrace.lineOpacity,
            child: const Align(
              key: ValueKey('status-crt-retrace-line'),
              alignment: Alignment.center,
              child: SizedBox(
                height: 1.1,
                child: ColoredBox(color: Color(0xFF78D7C8)),
              ),
            ),
          ),
        Opacity(
          opacity: screenOpacity * retrace.imageOpacity,
          child: Transform.scale(
            scaleY: retrace.imageScaleY,
            alignment: Alignment.center,
            child: Center(
              child: Text.rich(
                _terminalText(bootValue),
                key: const ValueKey('status-crt-phosphor'),
                maxLines: 1,
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  TextSpan _terminalText(double value) {
    final status = switch (value) {
      < .24 => '',
      < .38 => '',
      < .54 => 'STA',
      _ => 'STATUS',
    };
    final showPrompt = value >= .38;
    final showCursor = value >= .7;
    return TextSpan(
      children: [
        if (showPrompt)
          const TextSpan(text: '> ', style: _TerminalStyles.prompt),
        TextSpan(text: status, style: _TerminalStyles.status),
        if (showCursor)
          const TextSpan(text: '_', style: _TerminalStyles.cursor),
      ],
    );
  }
}

abstract final class _TerminalStyles {
  static const prompt = TextStyle(
    color: Color(0xFF6EBAAD),
    fontFamily: 'ShareTechMono',
    fontWeight: FontWeight.w400,
    height: 1,
    fontSize: 12,
    shadows: [Shadow(color: Color(0x7A3BCAB9), blurRadius: 2)],
  );
  static const status = TextStyle(
    color: Color(0xFF91E3D1),
    fontFamily: 'ShareTechMono',
    fontWeight: FontWeight.w400,
    height: 1,
    fontSize: 18,
    letterSpacing: .1,
    shadows: [Shadow(color: Color(0x7A3BCAB9), blurRadius: 2)],
  );
  static const cursor = TextStyle(
    color: Color(0xFF72C6B8),
    fontFamily: 'ShareTechMono',
    fontWeight: FontWeight.w400,
    height: 1,
    fontSize: 12,
    shadows: [Shadow(color: Color(0x7A3BCAB9), blurRadius: 2)],
  );
}

class _RetraceGeometry {
  const _RetraceGeometry({
    required this.imageOpacity,
    required this.imageScaleY,
    required this.lineOpacity,
  });

  factory _RetraceGeometry.from(double value) {
    if (value <= .32) {
      final progress = Curves.easeInCubic.transform(value / .32);
      return _RetraceGeometry(
        imageOpacity: 1 - progress * .72,
        imageScaleY: 1 - progress * .93,
        lineOpacity: progress * .58,
      );
    }
    if (value <= .5) {
      return const _RetraceGeometry(
        imageOpacity: .06,
        imageScaleY: .07,
        lineOpacity: .58,
      );
    }
    final progress = Curves.easeOutCubic.transform((value - .5) / .5);
    return _RetraceGeometry(
      imageOpacity: .06 + progress * .94,
      imageScaleY: .07 + progress * .93,
      lineOpacity: .58 * (1 - progress),
    );
  }

  final double imageOpacity;
  final double imageScaleY;
  final double lineOpacity;
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
