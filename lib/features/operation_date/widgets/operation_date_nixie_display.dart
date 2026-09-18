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
    this.previewTransitionToken = 0,
    super.key,
    this.initialTransitionFrom,
  });

  static const dateTileWidth = 42.0;
  static const tileHeight = 36.0;
  static const tileGap = 6.0;

  final Future<OperationLocalDate> operationDateFuture;
  final int transitionToken;
  final int previewTransitionToken;
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
            previewTransitionToken: previewTransitionToken,
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _OperationDateNixieClock(
                transitionToken: transitionToken,
                previewTransitionToken: previewTransitionToken,
              ),
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
  static const rearCathode = Color(0xFFA65A35);
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

/// Deterministic whole-display cathode sequence: all foregrounds shut down,
/// rear structures remain, then fields ignite from visual left to right.
abstract final class NixieTransitionMotion {
  static const duration = Duration(milliseconds: 360);

  static double foregroundOpacity({
    required double progress,
    required int ignitionOrder,
  }) {
    if (progress < .24) return 1 - progress / .24;
    if (progress < .42) return 0;
    final start = .42 + ignitionOrder * .055;
    const ignitionLength = .13;
    if (progress <= start) return 0;
    if (progress >= start + ignitionLength) return 1;
    return .35 + ((progress - start) / ignitionLength) * .65;
  }
}

/// Static physical-electrode treatment for the two deliberately restrained
/// rear cathodes. These are wire outlines, not dim alternate digits, so they
/// deliberately have no glow/shadow stack.
abstract final class NixieRearCathodePresentation {
  static const digits = <String>['8', '9'];
  static const monthWeekdayPattern = <String>['0', '8', '0'];
  static const dayPattern = <String>['0', '8'];
  static const eightOffset = Offset(-.5, .5);
  static const nineOffset = Offset(.75, -.6);
  static const opacity = .32;
  static const matchingActiveOpacity = .19;
  static const strokeWidth = .7;

  static double opacityFor(String activeDigit, String cathode) =>
      activeDigit == cathode ? matchingActiveOpacity : opacity;
}

/// Typography for the textual month and weekday cells.  It intentionally
/// remains separate from the numeric cathode style so cell geometry and clock
/// digit hierarchy are not affected by label-only tuning.
abstract final class NixiePresentationTypography {
  static const previousTextualFontSize = 15.0;
  static const textualFontSize = 16.0;
  static const textualFontWeight = FontWeight.normal;
  static const textualLetterSpacing = 0.0;
}

class _OperationDateNixieCalendar extends StatefulWidget {
  const _OperationDateNixieCalendar({
    required this.operationDateFuture,
    required this.transitionToken,
    required this.previewTransitionToken,
    this.initialTransitionFrom,
  });

  final Future<OperationLocalDate> operationDateFuture;
  final int transitionToken;
  final int previewTransitionToken;
  final OperationLocalDate? initialTransitionFrom;

  @override
  State<_OperationDateNixieCalendar> createState() =>
      _OperationDateNixieCalendarState();
}

class _OperationDateNixieCalendarState
    extends State<_OperationDateNixieCalendar>
    with SingleTickerProviderStateMixin {
  OperationLocalDate? _displayedDate;
  int _consumedTransitionToken = 0;
  int _consumedPreviewTransitionToken = 0;
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
    _consumedTransitionToken = widget.transitionToken;
    _consumedPreviewTransitionToken = widget.previewTransitionToken;
    _transitionController =
        AnimationController(
          vsync: this,
          duration: NixieTransitionMotion.duration,
        )..addStatusListener((status) {
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
      if (widget.previewTransitionToken != _consumedPreviewTransitionToken) {
        _consumedPreviewTransitionToken = widget.previewTransitionToken;
        _beginTransition();
      }
      return Semantics(
        label: 'OPERATION DATE ${date.value}',
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _transitionController,
            builder: (context, _) => Row(
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
                          foregroundOpacity: _foregroundOpacity(index),
                          rearCathodePattern:
                              NixieRearCathodePresentation.dayPattern,
                          rearCathodeKeyPrefix: 'day',
                        )
                      : _NixieTechnicalLabel(
                          key: ValueKey('operation-date-nixie-field-$index'),
                          value: values[index],
                          width: OperationDateNixieDisplay.dateTileWidth,
                          height: OperationDateNixieDisplay.tileHeight,
                          animate: _dateTransitionActive,
                          foregroundOpacity: _foregroundOpacity(index),
                          rearCathodeKeyPrefix: index == 0
                              ? 'month'
                              : 'weekday',
                        ),
                ],
              ],
            ),
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

  double _foregroundOpacity(int ignitionOrder) {
    if (!_dateTransitionActive) return 1;
    return NixieTransitionMotion.foregroundOpacity(
      progress: _transitionController.value,
      ignitionOrder: ignitionOrder,
    );
  }
}

class _OperationDateNixieClock extends StatefulWidget {
  const _OperationDateNixieClock({
    required this.transitionToken,
    required this.previewTransitionToken,
  });

  final int transitionToken;
  final int previewTransitionToken;

  @override
  State<_OperationDateNixieClock> createState() =>
      _OperationDateNixieClockState();
}

class _OperationDateNixieClockState extends State<_OperationDateNixieClock>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late DateTime _displayedTime = AppClock.now();
  Timer? _timer;
  Animation<double>? _secondaryAnimation;
  bool _routeVisible = true;
  bool _appActive = true;
  late final AnimationController _transitionController;
  int _consumedTransitionToken = 0;
  int _consumedPreviewTransitionToken = 0;
  bool _transitionActive = false;

  @override
  void initState() {
    super.initState();
    _consumedTransitionToken = widget.transitionToken;
    _consumedPreviewTransitionToken = widget.previewTransitionToken;
    _transitionController =
        AnimationController(
          vsync: this,
          duration: NixieTransitionMotion.duration,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _transitionActive = false);
          }
        });
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
    _transitionController.dispose();
    _secondaryAnimation?.removeStatusListener(_handleRouteStatus);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.transitionToken != _consumedTransitionToken) {
      _consumedTransitionToken = widget.transitionToken;
      _beginTransition();
    }
    if (widget.previewTransitionToken != _consumedPreviewTransitionToken) {
      _consumedPreviewTransitionToken = widget.previewTransitionToken;
      _beginTransition();
    }
    final values = [
      _displayedTime.hour.toString().padLeft(2, '0'),
      _displayedTime.minute.toString().padLeft(2, '0'),
      _displayedTime.second.toString().padLeft(2, '0'),
    ].expand((pair) => pair.split('')).toList(growable: false);
    return Semantics(
      label:
          'CURRENT TIME ${values[0]}${values[1]}:${values[2]}${values[3]}:${values[4]}${values[5]}',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _transitionController,
          builder: (context, _) => Row(
            key: ValueKey(
              _transitionActive
                  ? 'dashboard-live-nixie-clock-transition-active'
                  : 'dashboard-live-nixie-clock',
            ),
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
                  foregroundOpacity: _transitionActive
                      ? NixieTransitionMotion.foregroundOpacity(
                          progress: _transitionController.value,
                          ignitionOrder: index + 3,
                        )
                      : 1,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _beginTransition() {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    _transitionActive = true;
    _transitionController.forward(from: 0);
  }
}

class NixieTubeCell extends StatelessWidget {
  const NixieTubeCell({
    required this.value,
    required this.width,
    required this.height,
    super.key,
    this.animate = true,
    this.foregroundOpacity = 1,
    this.rearCathodePattern,
    this.rearCathodeKeyPrefix,
  });

  final String value;
  final double width;
  final double height;
  final bool animate;
  final double foregroundOpacity;
  final List<String>? rearCathodePattern;
  final String? rearCathodeKeyPrefix;

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
          rearCathodePattern == null
              ? _NixieRearCathodes(activeDigit: value)
              : _NixieDateRearCathodes(
                  activeValue: value,
                  digits: rearCathodePattern!,
                  fontSize: 20,
                  keyPrefix: rearCathodeKeyPrefix!,
                ),
          Opacity(
            opacity: foregroundOpacity,
            child: AnimatedSwitcher(
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
          ),
        ],
      ),
    );
  }
}

class _NixieRearCathodes extends StatelessWidget {
  const _NixieRearCathodes({required this.activeDigit});

  final String activeDigit;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRect(
      child: Stack(
        alignment: Alignment.center,
        children: [
          _cathode('8', NixieRearCathodePresentation.eightOffset),
          _cathode('9', NixieRearCathodePresentation.nineOffset),
        ],
      ),
    ),
  );

  Widget _cathode(String digit, Offset offset) => Transform.translate(
    offset: offset,
    child: Opacity(
      opacity: NixieRearCathodePresentation.opacityFor(activeDigit, digit),
      child: Text(
        digit,
        key: ValueKey('nixie-rear-cathode-$digit'),
        style: TextStyle(
          fontFamily: AppTextStyles.bootTechnicalFontFamily,
          fontSize: 20,
          height: 1,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = NixieRearCathodePresentation.strokeWidth
            ..color = NixiePresentationColors.rearCathode,
        ),
      ),
    ),
  );
}

/// Static inactive numeral electrodes distributed across a date field's
/// visible character positions. They deliberately reuse the time-side wire
/// treatment but never participate in the foreground glow stack.
class _NixieDateRearCathodes extends StatelessWidget {
  const _NixieDateRearCathodes({
    required this.activeValue,
    required this.digits,
    required this.fontSize,
    required this.keyPrefix,
  });

  final String activeValue;
  final List<String> digits;
  final double fontSize;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRect(
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < digits.length; index++)
              SizedBox(
                width: fontSize * .66,
                child: Center(child: _cathode(index, digits[index])),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _cathode(int index, String digit) {
    final offset = index.isEven
        ? NixieRearCathodePresentation.eightOffset
        : NixieRearCathodePresentation.nineOffset;
    final activeCharacter = index < activeValue.length
        ? activeValue[index]
        : '';
    return Transform.translate(
      offset: offset,
      child: Opacity(
        opacity: NixieRearCathodePresentation.opacityFor(
          activeCharacter,
          digit,
        ),
        child: Text(
          digit,
          key: ValueKey('nixie-date-rear-$keyPrefix-$index-$digit'),
          style: TextStyle(
            fontFamily: AppTextStyles.bootTechnicalFontFamily,
            fontSize: fontSize,
            height: 1,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = NixieRearCathodePresentation.strokeWidth
              ..color = NixiePresentationColors.rearCathode,
          ),
        ),
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
    required this.foregroundOpacity,
    required this.rearCathodeKeyPrefix,
    super.key,
  });

  final String value;
  final double width;
  final double height;
  final bool animate;
  final double foregroundOpacity;
  final String rearCathodeKeyPrefix;

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
      child: Stack(
        alignment: Alignment.center,
        children: [
          _NixieDateRearCathodes(
            activeValue: value,
            digits: NixieRearCathodePresentation.monthWeekdayPattern,
            fontSize: NixiePresentationTypography.textualFontSize,
            keyPrefix: rearCathodeKeyPrefix,
          ),
          Opacity(
            opacity: foregroundOpacity,
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
                  letterSpacing:
                      NixiePresentationTypography.textualLetterSpacing,
                  height: 1,
                  color: NixiePresentationColors.active,
                  shadows: NixiePresentationColors.textualShadows,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
