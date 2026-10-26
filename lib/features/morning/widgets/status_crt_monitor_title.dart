import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/widgets/dashboard_glass_card.dart';

enum StatusCrtMonitorMode { normal, entry }

/// The shared STATUS AppBar monitor. All motion is presentation-only.
class StatusCrtMonitorTitle extends StatefulWidget {
  const StatusCrtMonitorTitle({
    super.key,
    this.title = 'STATUS',
    this.mode = StatusCrtMonitorMode.normal,
    this.refreshMinDelay = const Duration(seconds: 10),
    this.refreshMaxDelay = const Duration(seconds: 25),
    this.nextInt,
  });

  static const width = 128.0;
  static const height = 34.0;
  static const bootDuration = Duration(milliseconds: 820);
  static const refreshDuration = Duration(milliseconds: 460);
  static const _readoutViewportWidth = width - 12;
  static const _marqueeHold = Duration(milliseconds: 900);
  static const _marqueeSpeed = 24.0;

  final String title;
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
  late final AnimationController _marqueeController;
  final Random _random = Random();
  Timer? _refreshTimer;
  bool _bootRequested = false;
  bool _bootCompleted = false;
  bool _motionEnabled = true;
  bool _appActive = true;
  bool _reducedMotion = false;
  double _marqueeExtent = 0;

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
    _marqueeController = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reducedMotion) {
      _motionEnabled = false;
      _refreshTimer?.cancel();
      _bootCompleted = true;
      _bootController.value = 1;
      _refreshController.value = 0;
      _marqueeController.stop();
      return;
    }
    _motionEnabled = true;
    if (!_canAnimate) {
      _refreshTimer?.cancel();
      _refreshController.stop();
      _marqueeController.stop();
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
    _syncMarquee();
  }

  @override
  void didUpdateWidget(covariant StatusCrtMonitorTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _refreshTimer?.cancel();
      if (_isEntry && _bootCompleted && _canAnimate) _scheduleRefresh();
    }
    if (oldWidget.title != widget.title) {
      _marqueeController
        ..stop()
        ..value = 0;
      _marqueeExtent = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncMarquee();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_appActive == active) return;
    _appActive = active;
    if (!active) {
      _refreshTimer?.cancel();
      _refreshController.stop();
      _marqueeController.stop();
      return;
    }
    if (_canAnimate && _bootCompleted && _isEntry) _scheduleRefresh();
    _syncMarquee();
  }

  void _handleBootStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _bootCompleted = true;
    _scheduleRefresh();
    _syncMarquee();
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

  void _syncMarquee() {
    if (!_bootCompleted || !_canAnimate || _reducedMotion) {
      _marqueeController.stop();
      return;
    }
    final extent = _readoutOverflow(context);
    if (extent <= 0) {
      _marqueeController
        ..stop()
        ..value = 0;
      _marqueeExtent = 0;
      return;
    }
    if ((_marqueeExtent - extent).abs() > .01 ||
        _marqueeController.duration == null) {
      _marqueeExtent = extent;
      final travel = Duration(
        milliseconds: (extent / StatusCrtMonitorTitle._marqueeSpeed * 1000)
            .round(),
      );
      _marqueeController.duration =
          StatusCrtMonitorTitle._marqueeHold +
          travel +
          StatusCrtMonitorTitle._marqueeHold +
          travel;
      _marqueeController.value = 0;
    }
    if (!_marqueeController.isAnimating) {
      _marqueeController.repeat();
    }
  }

  double _readoutOverflow(BuildContext context) {
    final painter = TextPainter(
      text: _settledTerminalText(widget.title),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return max(
      0.0,
      painter.width - StatusCrtMonitorTitle._readoutViewportWidth,
    ).toDouble();
  }

  double _marqueeOffset() {
    final duration = _marqueeController.duration;
    if (duration == null || _marqueeExtent <= 0) return 0;
    final elapsed = _marqueeController.value * duration.inMilliseconds;
    final hold = StatusCrtMonitorTitle._marqueeHold.inMilliseconds.toDouble();
    final travel = _marqueeExtent / StatusCrtMonitorTitle._marqueeSpeed * 1000;
    if (elapsed <= hold) return 0;
    if (elapsed <= hold + travel) {
      return _marqueeExtent * ((elapsed - hold) / travel);
    }
    if (elapsed <= hold * 2 + travel) return _marqueeExtent;
    return _marqueeExtent *
        (1 - ((elapsed - hold * 2 - travel) / travel).clamp(0.0, 1.0));
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
    _marqueeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.title,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            key: const ValueKey('status-crt-monitor-title'),
            width: StatusCrtMonitorTitle.width,
            height: StatusCrtMonitorTitle.height,
            child: DecoratedBox(
              decoration: DashboardGlassCard.decoration(
                Theme.of(context).colorScheme,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: ClipRRect(
                  key: const ValueKey('status-crt-screen'),
                  borderRadius: BorderRadius.circular(4),
                  // The CRT readout is intentionally transparent so the
                  // STATUS ambient continues through the AppBar display.
                  // Scanlines and phosphor glyphs remain independently drawn.
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
                          _marqueeController,
                        ]),
                        builder: (context, _) => _CrtPhosphorContent(
                          bootValue: _bootController.value,
                          refreshValue: _refreshController.value,
                          title: widget.title,
                          marqueeOffset: _marqueeOffset(),
                          marquee: _marqueeExtent > 0 && !_reducedMotion,
                          reducedMotion: _reducedMotion,
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
}

class _CrtPhosphorContent extends StatelessWidget {
  const _CrtPhosphorContent({
    required this.bootValue,
    required this.refreshValue,
    required this.title,
    required this.marqueeOffset,
    required this.marquee,
    required this.reducedMotion,
  });

  final double bootValue;
  final double refreshValue;
  final String title;
  final double marqueeOffset;
  final bool marquee;
  final bool reducedMotion;

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
            child: Center(child: _readout()),
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
      _ => title,
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

  Widget _readout() {
    final text = Text.rich(
      _terminalText(bootValue),
      key: const ValueKey('status-crt-phosphor'),
      maxLines: 1,
      overflow: TextOverflow.clip,
      textAlign: marquee ? TextAlign.left : TextAlign.center,
    );
    if (reducedMotion) {
      return FittedBox(fit: BoxFit.scaleDown, child: text);
    }
    if (!marquee) return text;
    return ClipRect(
      key: const ValueKey('status-crt-marquee-viewport'),
      child: SizedBox(
        width: StatusCrtMonitorTitle._readoutViewportWidth,
        child: Transform.translate(
          offset: Offset(-marqueeOffset, 0),
          child: Align(alignment: Alignment.centerLeft, child: text),
        ),
      ),
    );
  }
}

TextSpan _settledTerminalText(String title) => TextSpan(
  children: [
    const TextSpan(text: '> ', style: _TerminalStyles.prompt),
    TextSpan(text: title, style: _TerminalStyles.status),
    const TextSpan(text: '_', style: _TerminalStyles.cursor),
  ],
);

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
    fontSize: 22,
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
