import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/app_clock.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/operation_local_date.dart';

/// Nixie-inspired rendering of the existing Operation Date information.
/// It deliberately consumes the same Future and one-shot transition token as
/// the mechanical FLIP renderer, without changing canonical date ownership.
class OperationDateNixieDisplay extends StatelessWidget {
  const OperationDateNixieDisplay({
    required this.operationDateFuture,
    required this.transitionToken,
    super.key,
    this.initialTransitionFrom,
  });

  static const dateTileWidth = 42.0;
  static const tileHeight = 36.0;
  static const tileGap = 6.0;

  final Future<OperationLocalDate> operationDateFuture;
  final int transitionToken;
  final OperationLocalDate? initialTransitionFrom;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Wrap(
      key: const ValueKey('operation-date-nixie-row'),
      spacing: 0,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _OperationDateNixieCalendar(
            operationDateFuture: operationDateFuture,
            transitionToken: transitionToken,
            initialTransitionFrom: initialTransitionFrom,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                height: tileHeight + 8,
                child: VerticalDivider(
                  key: const ValueKey('dashboard-nixie-date-time-divider'),
                  width: 1,
                  thickness: 1,
                  color: NixiePresentationColors.frame,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: _OperationDateNixieClock(),
            ),
          ],
        ),
      ],
    ),
  );
}

class NixiePresentationColors {
  NixiePresentationColors._();

  static const active = Color(0xFFFFA24A);
  static const innerGlow = Color(0xCCFF6A26);
  static const glow = Color(0xB3F35A24);
  static const outerGlow = Color(0x66D9431F);
  static const inactive = Color(0x05FF8A3D);
  static const frame = Color(0x66F06A32);
  static const surface = Color(0xFF17100E);

  static const activeShadows = <Shadow>[
    Shadow(color: innerGlow, blurRadius: 3),
    Shadow(color: glow, blurRadius: 7),
    Shadow(color: outerGlow, blurRadius: 11),
  ];

  /// Textual date fields use the same tube-light layers at 75% intensity so
  /// the numeric cathodes remain the brightest elements.
  static const textualShadows = <Shadow>[
    Shadow(color: Color(0x99FF6A26), blurRadius: 3),
    Shadow(color: Color(0x86F35A24), blurRadius: 7),
    Shadow(color: Color(0x4DD9431F), blurRadius: 11),
  ];
}

/// Typography for the textual month and weekday cells.  It intentionally
/// remains separate from the numeric cathode style so cell geometry and clock
/// digit hierarchy are not affected by label-only tuning.
abstract final class NixiePresentationTypography {
  static const previousTextualFontSize = 14.0;
  static const textualFontSize = 15.0;
  static const textualFontWeight = FontWeight.normal;
  static const textualLetterSpacing = 0.0;
}

class _OperationDateNixieCalendar extends StatefulWidget {
  const _OperationDateNixieCalendar({
    required this.operationDateFuture,
    required this.transitionToken,
    this.initialTransitionFrom,
  });

  final Future<OperationLocalDate> operationDateFuture;
  final int transitionToken;
  final OperationLocalDate? initialTransitionFrom;

  @override
  State<_OperationDateNixieCalendar> createState() =>
      _OperationDateNixieCalendarState();
}

class _OperationDateNixieCalendarState
    extends State<_OperationDateNixieCalendar>
    with SingleTickerProviderStateMixin {
  static const transitionDuration = Duration(milliseconds: 90);
  OperationLocalDate? _displayedDate;
  int _consumedTransitionToken = 0;
  late final AnimationController _transitionController;
  bool _dateTransitionActive = false;
  bool _showingInitialTransitionFrom = false;

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _transitionController =
        AnimationController(vsync: this, duration: transitionDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              setState(() => _dateTransitionActive = false);
            }
          });
    _showingInitialTransitionFrom = widget.initialTransitionFrom != null;
    if (_showingInitialTransitionFrom) {
      _displayedDate = widget.initialTransitionFrom;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _showingInitialTransitionFrom = false;
          _beginTransition();
        });
      });
    }
  }

  void _beginTransition() {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    _dateTransitionActive = true;
    _transitionController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<OperationLocalDate>(
    future: widget.operationDateFuture,
    builder: (context, snapshot) {
      if (!_showingInitialTransitionFrom &&
          snapshot.connectionState == ConnectionState.done &&
          snapshot.hasData) {
        final nextDate = snapshot.requireData;
        final animate =
            widget.transitionToken != _consumedTransitionToken &&
            _displayedDate != null &&
            _displayedDate != nextDate;
        _displayedDate = nextDate;
        _consumedTransitionToken = widget.transitionToken;
        if (animate) _beginTransition();
      }
      final date = _showingInitialTransitionFrom
          ? widget.initialTransitionFrom
          : _displayedDate;
      if (date == null) {
        return Text(
          'LOADING...',
          style: Theme.of(context).textTheme.titleSmall,
        );
      }
      final parsed = date.asUtcDate;
      final values = [
        _months[parsed.month - 1],
        parsed.day.toString().padLeft(2, '0'),
        _weekdays[parsed.weekday - 1],
      ];
      return Semantics(
        label: 'OPERATION DATE ${date.value}',
        child: ExcludeSemantics(
          child: Row(
            key: ValueKey(
              _dateTransitionActive
                  ? 'operation-date-nixie-transition-active'
                  : 'operation-date-nixie-calendar',
            ),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < values.length; index++) ...[
                if (index > 0)
                  const SizedBox(width: OperationDateNixieDisplay.tileGap),
                index == 1
                    ? NixieTubeCell(
                        key: ValueKey('operation-date-nixie-field-$index'),
                        value: values[index],
                        width: OperationDateNixieDisplay.dateTileWidth,
                        height: OperationDateNixieDisplay.tileHeight,
                        animate: _dateTransitionActive,
                      )
                    : _NixieTechnicalLabel(
                        key: ValueKey('operation-date-nixie-field-$index'),
                        value: values[index],
                        width: OperationDateNixieDisplay.dateTileWidth,
                        height: OperationDateNixieDisplay.tileHeight,
                        animate: _dateTransitionActive,
                      ),
              ],
            ],
          ),
        ),
      );
    },
  );

  static const _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  static const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
}

class _OperationDateNixieClock extends StatefulWidget {
  const _OperationDateNixieClock();

  @override
  State<_OperationDateNixieClock> createState() =>
      _OperationDateNixieClockState();
}

class _OperationDateNixieClockState extends State<_OperationDateNixieClock>
    with WidgetsBindingObserver {
  late DateTime _displayedTime = AppClock.now();
  Timer? _timer;
  Animation<double>? _secondaryAnimation;
  bool _routeVisible = true;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.secondaryAnimation;
    if (_secondaryAnimation != animation) {
      _secondaryAnimation?.removeStatusListener(_handleRouteStatus);
      _secondaryAnimation = animation;
      _secondaryAnimation?.addStatusListener(_handleRouteStatus);
    }
    _routeVisible =
        animation == null || animation.status == AnimationStatus.dismissed;
    _routeVisible && _appActive ? _scheduleNextTick() : _timer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _appActive && _routeVisible ? _syncAndSchedule() : _timer?.cancel();
  }

  void _handleRouteStatus(AnimationStatus status) {
    _routeVisible = status == AnimationStatus.dismissed;
    _routeVisible && _appActive ? _syncAndSchedule() : _timer?.cancel();
  }

  void _syncAndSchedule() {
    if (!mounted) return;
    final now = AppClock.now();
    if (_stamp(now) != _stamp(_displayedTime)) {
      setState(() => _displayedTime = now);
    }
    _scheduleNextTick();
  }

  void _scheduleNextTick() {
    _timer?.cancel();
    if (!_routeVisible || !_appActive) return;
    final now = AppClock.now();
    _timer = Timer(
      Duration(milliseconds: 1000 - now.millisecond),
      _syncAndSchedule,
    );
  }

  int _stamp(DateTime value) => value.millisecondsSinceEpoch ~/ 1000;

  @override
  void dispose() {
    _timer?.cancel();
    _secondaryAnimation?.removeStatusListener(_handleRouteStatus);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final values = [
      _displayedTime.hour.toString().padLeft(2, '0'),
      _displayedTime.minute.toString().padLeft(2, '0'),
      _displayedTime.second.toString().padLeft(2, '0'),
    ].expand((pair) => pair.split('')).toList(growable: false);
    return Semantics(
      label:
          'CURRENT TIME ${values[0]}${values[1]}:${values[2]}${values[3]}:${values[4]}${values[5]}',
      child: ExcludeSemantics(
        child: Row(
          key: const ValueKey('dashboard-live-nixie-clock'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < values.length; index++) ...[
              if (index > 0)
                SizedBox(
                  width: index.isOdd ? 3 : 6,
                  child: index == 2 || index == 4
                      ? const Center(
                          child: Text(
                            ':',
                            style: TextStyle(
                              color: NixiePresentationColors.active,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        )
                      : null,
                ),
              NixieTubeCell(
                key: ValueKey('dashboard-nixie-time-cell-$index'),
                value: values[index],
                width: 24,
                height: OperationDateNixieDisplay.tileHeight,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NixieTubeCell extends StatelessWidget {
  const NixieTubeCell({
    required this.value,
    required this.width,
    required this.height,
    super.key,
    this.animate = true,
  });

  final String value;
  final double width;
  final double height;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: NixiePresentationColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: NixiePresentationColors.frame),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var index = 0; index < 10; index++)
            Text(
              '$index',
              style: const TextStyle(
                fontFamily: AppTextStyles.bootTechnicalFontFamily,
                fontSize: 20,
                height: 1,
                color: NixiePresentationColors.inactive,
              ),
            ),
          AnimatedSwitcher(
            duration: disabled || !animate
                ? Duration.zero
                : const Duration(milliseconds: 80),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Text(
              value,
              key: ValueKey('nixie-active-$value'),
              style: const TextStyle(
                fontFamily: AppTextStyles.bootTechnicalFontFamily,
                fontSize: 20,
                height: 1,
                color: NixiePresentationColors.active,
                shadows: NixiePresentationColors.activeShadows,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NixieTechnicalLabel extends StatelessWidget {
  const _NixieTechnicalLabel({
    required this.value,
    required this.width,
    required this.height,
    required this.animate,
    super.key,
  });

  final String value;
  final double width;
  final double height;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: NixiePresentationColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: NixiePresentationColors.frame),
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: disabled || !animate
            ? Duration.zero
            : const Duration(milliseconds: 80),
        child: Text(
          value,
          key: ValueKey('nixie-label-$value'),
          style: const TextStyle(
            fontFamily: AppTextStyles.bootTechnicalFontFamily,
            fontSize: NixiePresentationTypography.textualFontSize,
            fontWeight: NixiePresentationTypography.textualFontWeight,
            letterSpacing: NixiePresentationTypography.textualLetterSpacing,
            height: 1,
            color: NixiePresentationColors.active,
            shadows: NixiePresentationColors.textualShadows,
          ),
        ),
      ),
    );
  }
}
