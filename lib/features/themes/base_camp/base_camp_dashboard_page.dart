import 'dart:async';

import 'package:flutter/material.dart';

import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/engine/food_summary.dart';
import 'package:or_app/core/engine/operation_status.dart';
import 'package:or_app/core/engine/training_summary.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/features/activity/models/activity_summary_state.dart';
import 'package:or_app/features/command_center/models/daily_command_read_model.dart';
import 'package:or_app/features/command_center/services/daily_command_read_model_builder.dart';
import 'package:or_app/features/dashboard/dashboard_page.dart'
    show showDashboardQuickWaterInput;
import 'package:or_app/features/dashboard/models/dynamic_daily_target.dart';
import 'package:or_app/features/dashboard/services/dashboard_plan_information_service.dart';
import 'package:or_app/features/dashboard/services/dynamic_daily_target_service.dart';
import 'package:or_app/features/dashboard/widgets/operation_ambient_animation.dart';
import 'package:or_app/features/food/models/food_summary_state.dart';
import 'package:or_app/features/morning/models/morning_fact.dart';
import 'package:or_app/features/morning/models/morning_fact_state.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/schedule/pages/calendar_page.dart';
import 'package:or_app/features/system/widgets/system_menu_button.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_map.dart';
import 'package:or_app/features/training/models/training_summary_state.dart';
import 'package:or_app/features/training/services/training_status_weight_resolver.dart';

/// BASE CAMP owns its compact command-terminal presentation. It only reads
/// the shared formal Dashboard projections; STANDARD keeps its own layout.
class BaseCampDashboardPage extends StatefulWidget {
  const BaseCampDashboardPage({super.key});

  @override
  State<BaseCampDashboardPage> createState() => _BaseCampDashboardPageState();
}

class _BaseCampDashboardPageState extends State<BaseCampDashboardPage> {
  final _pages = PageController();
  Future<_TerminalSnapshot>? _snapshot;
  int? _sourceSignature;
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<_TerminalSnapshot> _snapshotFor(
    MorningFact? morning,
    FoodSummary? food,
    TrainingSummary? training,
    ActivitySummary activity,
  ) {
    final signature = Object.hash(morning, food, training, activity);
    if (_snapshot == null || _sourceSignature != signature) {
      _sourceSignature = signature;
      _snapshot = _loadSnapshot(morning, food, training, activity);
    }
    return _snapshot!;
  }

  Future<_TerminalSnapshot> _loadSnapshot(
    MorningFact? morning,
    FoodSummary? food,
    TrainingSummary? training,
    ActivitySummary activity,
  ) async {
    try {
      final repositories = AppRepositoryRegistry.container;
      final state = await repositories.operationState.requireCurrent();
      final date = state.operationDate.value;
      final brief = await repositories.morningBriefs.readByLocalDate(date);
      final debrief = await repositories.dailyDebriefs.readByLocalDate(date);
      final burnWeight = await TrainingStatusWeightResolver(
        repository: repositories.status,
      ).resolve(date);
      final command = DailyCommandReadModelBuilder.build(
        operationState: state,
        status: morning,
        food: food,
        training: training,
        activity: activity,
        burnWeightKg: burnWeight,
        morningBrief: brief,
      );
      final values = await Future.wait<Object?>([
        DashboardPlanInformationService(
          repositories.schedules,
          reminders: repositories.reminders,
        ).loadFor(date),
        DynamicDailyTargetService(
          statusRepository: repositories.status,
          trainingRepository: repositories.training,
        ).loadForOperationDate(
          operationDate: date,
          food: food,
          activity: activity,
          training: training,
        ),
      ]);
      return _TerminalSnapshot(
        date: date,
        command: command,
        plan: values[0] as DashboardPlanInformation,
        targets: values[1] as DynamicDailyTargetResult,
        briefRecorded: brief != null,
        debriefRecorded: debrief != null,
      );
    } catch (_) {
      // A presentation read must never create, infer, or alter formal data.
      return const _TerminalSnapshot.unavailable();
    }
  }

  void _openFacility(BaseCampFacility facility) {
    final route = switch (facility.id) {
      'status' => AppRoutes.morning,
      'food' => AppRoutes.food,
      'training' => AppRoutes.training,
      'activity' => AppRoutes.activity,
      'command-center' => AppRoutes.commandCenter,
      _ => null,
    };
    if (route != null) Navigator.of(context).pushNamed(route);
  }

  Future<void> _openCalendar(String date) async {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CalendarPage(initialDate: parsed),
      ),
    );
    if (mounted) setState(() => _snapshot = null);
  }

  void _openDetail(
    _TerminalPage page,
    _TerminalSnapshot snapshot,
    MorningFact? morning,
    FoodSummary? food,
    TrainingSummary? training,
    ActivitySummary activity,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _TerminalDetailSheet(
        page: page,
        snapshot: snapshot,
        morning: morning,
        food: food,
        training: training,
        activity: activity,
        openRoute: (route) {
          Navigator.of(sheetContext).pop();
          Navigator.of(context).pushNamed(route);
        },
        openCalendar: () {
          Navigator.of(sheetContext).pop();
          _openCalendar(snapshot.date);
        },
        openWater: () => showDashboardQuickWaterInput(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<MorningFact?>(
    valueListenable: morningFactNotifier,
    builder: (context, morning, _) => ValueListenableBuilder<FoodSummary?>(
      valueListenable: foodSummaryNotifier,
      builder: (context, food, _) => ValueListenableBuilder<TrainingSummary?>(
        valueListenable: trainingSummaryNotifier,
        builder: (context, training, _) =>
            ValueListenableBuilder<ActivitySummary>(
              valueListenable: activitySummaryNotifier,
              builder: (context, activity, _) => Scaffold(
                backgroundColor: const Color(0xff11150f),
                appBar: AppBar(
                  backgroundColor: const Color(0xff1a2016),
                  foregroundColor: const Color(0xffe8e2c9),
                  surfaceTintColor: Colors.transparent,
                  titleSpacing: 16,
                  title: const Text('BASE CAMP // COMMAND TERMINAL'),
                  actions: const [SystemMenuButton()],
                ),
                body: SafeArea(
                  top: false,
                  child: FutureBuilder<_TerminalSnapshot>(
                    future: _snapshotFor(morning, food, training, activity),
                    builder: (context, async) {
                      final snapshot =
                          async.data ?? const _TerminalSnapshot.unavailable();
                      return LayoutBuilder(
                        builder: (context, viewport) {
                          final width = (viewport.maxWidth - 24).clamp(
                            0.0,
                            940.0,
                          );
                          final naturalMapHeight = width * 9 / 16 + 14;
                          final availableMapHeight =
                              viewport.maxHeight -
                              _TacticalTerminal.height -
                              12 -
                              32;
                          final mapViewportHeight =
                              naturalMapHeight > availableMapHeight
                              ? naturalMapHeight
                              : availableMapHeight;
                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 940,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _TacticalTerminal(
                                      snapshot: snapshot,
                                      morning: morning,
                                      food: food,
                                      training: training,
                                      activity: activity,
                                      pages: _pages,
                                      page: _page,
                                      onPageChanged: (value) =>
                                          setState(() => _page = value),
                                      onOpenDetail: (page) => _openDetail(
                                        page,
                                        snapshot,
                                        morning,
                                        food,
                                        training,
                                        activity,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _MapChassis(
                                      viewportHeight: mapViewportHeight,
                                      child: BaseCampMap(
                                        onFacilityPressed: _openFacility,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
      ),
    ),
  );
}

class _MapChassis extends StatelessWidget {
  const _MapChassis({required this.viewportHeight, required this.child});
  final double viewportHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('base-camp-home-map-region'),
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: const Color(0xff293022),
      border: Border.all(color: const Color(0xff888363), width: 1.4),
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
    ),
    child: SizedBox(
      key: const ValueKey('base-camp-home-map-viewport'),
      height: viewportHeight - 14,
      child: Center(
        // The map remains one proportional 16:9 scene; the chassis owns
        // surplus height rather than scaling or cropping image/overlays.
        child: AspectRatio(aspectRatio: 16 / 9, child: child),
      ),
    ),
  );
}

class _TacticalTerminal extends StatelessWidget {
  static const height = 365.0;
  const _TacticalTerminal({
    required this.snapshot,
    required this.morning,
    required this.food,
    required this.training,
    required this.activity,
    required this.pages,
    required this.page,
    required this.onPageChanged,
    required this.onOpenDetail,
  });
  final _TerminalSnapshot snapshot;
  final MorningFact? morning;
  final FoodSummary? food;
  final TrainingSummary? training;
  final ActivitySummary activity;
  final PageController pages;
  final int page;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<_TerminalPage> onOpenDetail;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('base-camp-tactical-terminal'),
    decoration: BoxDecoration(
      color: const Color(0xff2a3020),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xff8d8968), width: 1.4),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
    ),
    child: CustomPaint(
      painter: const _TerminalChassisPainter(),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          children: [
            const _TerminalHeading(),
            const SizedBox(height: 8),
            SizedBox(
              height: 106,
              child: Row(
                children: [
                  const Expanded(flex: 4, child: _SoldierPendingCompartment()),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 6,
                    child: _StatusCompartment(snapshot: snapshot),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 190,
              child: PageView(
                key: const ValueKey('base-camp-terminal-pages'),
                controller: pages,
                onPageChanged: onPageChanged,
                children: [
                  _TerminalInformationPage(
                    page: _TerminalPage.progress,
                    title: 'OPERATION PROGRESS',
                    subtitle: 'FORMAL RECORD STATE',
                    onTap: () => onOpenDetail(_TerminalPage.progress),
                    child: _ProgressPreview(
                      snapshot: snapshot,
                      food: food,
                      training: training,
                      activity: activity,
                    ),
                  ),
                  _TerminalInformationPage(
                    page: _TerminalPage.morning,
                    title: 'MORNING DATA',
                    subtitle: 'CURRENT OPERATION INPUT',
                    onTap: () => onOpenDetail(_TerminalPage.morning),
                    child: _MorningPreview(
                      morning: morning,
                      targets: snapshot.targets,
                      training: training,
                    ),
                  ),
                  _TerminalInformationPage(
                    page: _TerminalPage.sustainment,
                    title: 'SUSTAINMENT',
                    subtitle: 'NUTRITION · WATER · TRAINING · ACTIVITY',
                    onTap: () => onOpenDetail(_TerminalPage.sustainment),
                    child: _SustainmentPreview(
                      food: food,
                      training: training,
                      activity: activity,
                      targets: snapshot.targets,
                    ),
                  ),
                  _TerminalInformationPage(
                    page: _TerminalPage.command,
                    title: 'COMMAND / SCHEDULE',
                    subtitle: 'INTENT AND TODAY\'S PLAN',
                    onTap: () => onOpenDetail(_TerminalPage.command),
                    child: _CommandPreview(snapshot: snapshot),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            _PageIndicator(index: page, count: 4),
          ],
        ),
      ),
    ),
  );
}

class _TerminalHeading extends StatelessWidget {
  const _TerminalHeading();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(
        Icons.settings_input_component_outlined,
        color: Color(0xffd8d0b2),
        size: 18,
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          'TACTICAL COMMAND TERMINAL',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xfff0ead2),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.05,
          ),
        ),
      ),
      const _CornerStatus(),
    ],
  );
}

class _CornerStatus extends StatelessWidget {
  const _CornerStatus();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xff171b12),
      border: Border.all(color: const Color(0xff8d8968)),
    ),
    child: const Text(
      'LINK',
      style: TextStyle(
        color: Color(0xffa7d84c),
        fontSize: 10,
        letterSpacing: .8,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _SoldierPendingCompartment extends StatelessWidget {
  const _SoldierPendingCompartment();
  @override
  Widget build(BuildContext context) => _TerminalPanel(
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_search_outlined,
            color: Color(0xffa9a083),
            size: 31,
          ),
          SizedBox(height: 4),
          Text('SOLDIER', style: _labelStyle),
          Text(
            'ASSET PENDING',
            style: TextStyle(
              color: Color(0xffd7d1ba),
              fontSize: 9,
              letterSpacing: .7,
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatusCompartment extends StatelessWidget {
  const _StatusCompartment({required this.snapshot});
  final _TerminalSnapshot snapshot;
  @override
  Widget build(BuildContext context) {
    final status = snapshot.command?.operationStatus;
    final color = _statusColor(status);
    return _TerminalPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DotMatrixClock(),
            const SizedBox(height: 2),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'OPERATION STATUS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _labelStyle,
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      status?.name.toUpperCase() ?? 'STANDBY',
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 25,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: color.withValues(alpha: .68)),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: _SignalMonitorGridPainter(color)),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: RepaintBoundary(
                          child: OperationAmbientAnimation(
                            status: status,
                            showStatusLabel: false,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            _StatusLamps(status: status),
            const Text(
              'TACTICAL SIGNAL // DECORATIVE',
              style: TextStyle(color: Color(0xffa9a083), fontSize: 6),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLamps extends StatelessWidget {
  const _StatusLamps({required this.status});

  final OperationStatus? status;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _StatusLamp(
        'FINE',
        active: status == OperationStatus.green,
        color: const Color(0xffa7d84c),
      ),
      const SizedBox(width: 8),
      _StatusLamp(
        'CAUTION',
        active: status == OperationStatus.yellow,
        color: const Color(0xffffc857),
      ),
      const SizedBox(width: 8),
      _StatusLamp(
        'DANGER',
        active: status == OperationStatus.red,
        color: const Color(0xffff6b6b),
      ),
    ],
  );
}

class _StatusLamp extends StatelessWidget {
  const _StatusLamp(this.label, {required this.active, required this.color});
  final String label;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: active ? color : const Color(0xff182319),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: active ? .9 : .32)),
        ),
      ),
      const SizedBox(width: 3),
      Text(
        label,
        style: const TextStyle(
          color: _LcdPalette.mid,
          fontSize: 7,
          letterSpacing: .4,
        ),
      ),
    ],
  );
}

class _SignalMonitorGridPainter extends CustomPainter {
  const _SignalMonitorGridPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = color.withValues(alpha: .16)
      ..strokeWidth = .5;
    for (var x = 0.0; x <= size.width; x += 12) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y <= size.height; y += 9) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final axis = Paint()
      ..color = color.withValues(alpha: .30)
      ..strokeWidth = .8;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      axis,
    );
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      axis,
    );
  }

  @override
  bool shouldRepaint(covariant _SignalMonitorGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DotMatrixClock extends StatefulWidget {
  const _DotMatrixClock();

  @override
  State<_DotMatrixClock> createState() => _DotMatrixClockState();
}

class _DotMatrixClockState extends State<_DotMatrixClock>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime _now = DateTime.now();
  int _changedDigit = -1;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _active ? _start() : _timer?.cancel();
  }

  void _start() {
    _timer?.cancel();
    if (!_active) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = DateTime.now();
      final previous = _clockText(_now);
      final current = _clockText(next);
      if (!mounted) return;
      setState(() {
        _changedDigit = List<int>.generate(current.length, (index) => index)
            .firstWhere(
              (index) => current[index] != previous[index],
              orElse: () => -1,
            );
        _now = next;
      });
      if (_changedDigit >= 0) {
        Timer(const Duration(milliseconds: 100), () {
          if (mounted) setState(() => _changedDigit = -1);
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('base-camp-dot-matrix-clock'),
    height: 14,
    width: double.infinity,
    child: CustomPaint(
      painter: _DotMatrixClockPainter(
        text: _clockText(_now),
        changedDigit: _changedDigit,
      ),
    ),
  );
}

String _clockText(DateTime value) {
  const weekday = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  String pair(int number) => number.toString().padLeft(2, '0');
  return '${pair(value.month)}/${pair(value.day)} (${weekday[value.weekday - 1]}) ${pair(value.hour)}:${pair(value.minute)}:${pair(value.second)}';
}

class _DotMatrixClockPainter extends CustomPainter {
  const _DotMatrixClockPainter({
    required this.text,
    required this.changedDigit,
  });
  final String text;
  final int changedDigit;

  static const _glyphs = <String, List<String>>{
    '0': ['111', '101', '101', '101', '111'],
    '1': ['010', '110', '010', '010', '111'],
    '2': ['111', '001', '111', '100', '111'],
    '3': ['111', '001', '111', '001', '111'],
    '4': ['101', '101', '111', '001', '001'],
    '5': ['111', '100', '111', '001', '111'],
    '6': ['111', '100', '111', '101', '111'],
    '7': ['111', '001', '010', '010', '010'],
    '8': ['111', '101', '111', '101', '111'],
    '9': ['111', '101', '111', '001', '111'],
    ':': ['0', '1', '0', '1', '0'],
    '/': ['001', '001', '010', '100', '100'],
    '(': ['01', '10', '10', '10', '01'],
    ')': ['10', '01', '01', '01', '10'],
    'M': ['101', '111', '111', '101', '101'],
    'T': ['111', '010', '010', '010', '010'],
    'W': ['101', '101', '111', '111', '101'],
    'H': ['101', '101', '111', '101', '101'],
    'F': ['111', '100', '110', '100', '100'],
    'S': ['111', '100', '111', '001', '111'],
    'U': ['101', '101', '101', '101', '111'],
    'E': ['111', '100', '110', '100', '111'],
    'D': ['110', '101', '101', '101', '110'],
    ' ': ['0', '0', '0', '0', '0'],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final widths = text
        .split('')
        .map((character) => (_glyphs[character] ?? _glyphs[' ']!).first.length)
        .toList();
    final columns =
        widths.fold<int>(0, (sum, width) => sum + width) + text.length - 1;
    final dot = (size.width / (columns * 1.45)).clamp(1.15, 2.35);
    final totalWidth = columns * dot * 1.45;
    var x = ((size.width - totalWidth) / 2).clamp(0.0, double.infinity);
    for (var index = 0; index < text.length; index++) {
      final rows = _glyphs[text[index]] ?? _glyphs[' ']!;
      final paint = Paint()
        ..color = _LcdPalette.light.withValues(
          alpha: index == changedDigit ? .58 : .94,
        );
      final dim = Paint()..color = _LcdPalette.mid.withValues(alpha: .16);
      for (var row = 0; row < rows.length; row++) {
        for (var column = 0; column < rows[row].length; column++) {
          canvas.drawCircle(
            Offset(x + column * dot * 1.45, 3 + row * dot * 1.45),
            dot / 2,
            rows[row][column] == '1' ? paint : dim,
          );
        }
      }
      x += (rows.first.length + 1) * dot * 1.45;
    }
  }

  @override
  bool shouldRepaint(covariant _DotMatrixClockPainter oldDelegate) =>
      oldDelegate.text != text || oldDelegate.changedDigit != changedDigit;
}

class _IndustrialLcdPanel extends StatelessWidget {
  const _IndustrialLcdPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const ValueKey('base-camp-industrial-lcd'),
    decoration: BoxDecoration(
      color: _LcdPalette.darkest,
      border: Border.all(color: _LcdPalette.mid),
      borderRadius: BorderRadius.circular(7),
    ),
    child: child,
  );
}

class _TerminalInformationPage extends StatelessWidget {
  const _TerminalInformationPage({
    required this.page,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.child,
  });
  final _TerminalPage page;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$title. Tap for expanded detail.',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('base-camp-terminal-page-${page.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: _IndustrialLcdPanel(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: _LcdPalette.light,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .9,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.open_in_full,
                      size: 15,
                      color: _LcdPalette.mid,
                    ),
                  ],
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _LcdPalette.mid,
                    fontSize: 8,
                    letterSpacing: .65,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ProgressPreview extends StatelessWidget {
  const _ProgressPreview({
    required this.snapshot,
    required this.food,
    required this.training,
    required this.activity,
  });
  final _TerminalSnapshot snapshot;
  final FoodSummary? food;
  final TrainingSummary? training;
  final ActivitySummary activity;

  @override
  Widget build(BuildContext context) {
    final model = snapshot.command;
    final mealCount = food?.mealCount ?? 0;
    final foodCount = mealCount.clamp(0, 3).toInt();
    return _LcdGrid(
      key: const ValueKey('base-camp-progress-grid'),
      columns: 3,
      aspectRatio: 1.85,
      children: [
        _LcdProgressCard(
          'STATUS',
          model?.statusCompletion.displayState ?? 'NOT RECORDED',
          progress: model?.statusCompletion.isComplete == true ? 1 : 0,
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.morning),
        ),
        _LcdProgressCard(
          'FOOD',
          foodCount == 0 ? 'NOT RECORDED' : '$foodCount / 3',
          progress: foodCount / 3,
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.food),
        ),
        _LcdProgressCard(
          'TRAINING',
          training?.completed == true ? 'COMPLETE' : 'NOT RECORDED',
          progress: training?.completed == true ? 1 : 0,
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.training),
        ),
        _LcdProgressCard(
          'ACTIVITY',
          model?.activityCompletion.displayState ??
              (activity.isRecorded ? 'COMPLETE' : 'NOT RECORDED'),
          progress:
              model?.activityCompletion.isComplete == true ||
                  activity.isRecorded
              ? 1
              : 0,
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.activity),
        ),
        _LcdProgressCard(
          'BRIEF',
          snapshot.briefRecorded ? 'COMPLETE' : 'NOT RECORDED',
          progress: snapshot.briefRecorded ? 1 : 0,
          compact: true,
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.commandCenter),
        ),
        _LcdProgressCard(
          'DEBRIEF',
          snapshot.debriefRecorded ? 'COMPLETE' : 'NOT RECORDED',
          progress: snapshot.debriefRecorded ? 1 : 0,
          compact: true,
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.commandCenter),
        ),
      ],
    );
  }
}

class _MorningPreview extends StatelessWidget {
  const _MorningPreview({
    required this.morning,
    required this.targets,
    required this.training,
  });
  final MorningFact? morning;
  final DynamicDailyTargetResult? targets;
  final TrainingSummary? training;
  @override
  Widget build(BuildContext context) => _LcdGrid(
    children: [
      _Metric('WEIGHT', _weightText(morning)),
      _Metric('SLEEP', _sleepText(morning)),
      _Metric('BASE BURN', _kcalText(targets?.estimatedBaseBurnKcal)),
      _Metric('EXERCISE', _kcalText(training?.trainingEstimatedCaloriesKcal)),
      _Metric('TOTAL BURN', _kcalText(targets?.estimatedTotalBurnKcal)),
    ],
  );
}

class _SustainmentPreview extends StatelessWidget {
  const _SustainmentPreview({
    required this.food,
    required this.training,
    required this.activity,
    required this.targets,
  });
  final FoodSummary? food;
  final TrainingSummary? training;
  final ActivitySummary activity;
  final DynamicDailyTargetResult? targets;
  @override
  Widget build(BuildContext context) => _LcdGrid(
    children: [
      _Metric('MEALS', '${food?.mealCount ?? 0} / 3'),
      _Metric('CALORIES', _rangeText(food?.calories, targets?.calories)),
      _Metric(
        'PROTEIN',
        _rangeText(food?.protein, targets?.protein, suffix: ' g'),
      ),
      _Metric('WATER', _waterText(food, targets)),
      _Metric(
        'TRAINING',
        training?.completed == true ? 'COMPLETE' : 'NOT RECORDED',
      ),
      _Metric(
        'ACTIVITY',
        activity.isRecorded ? '${activity.steps} steps' : 'NOT RECORDED',
      ),
    ],
  );
}

class _CommandPreview extends StatefulWidget {
  const _CommandPreview({required this.snapshot});
  final _TerminalSnapshot snapshot;

  @override
  State<_CommandPreview> createState() => _CommandPreviewState();
}

class _CommandPreviewState extends State<_CommandPreview> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entries =
        widget.snapshot.plan?.entries ??
        const <DashboardPlanInformationEntry>[];
    final intent =
        widget.snapshot.command?.commanderIntent ??
        'COMMANDER INTENT UNAVAILABLE';
    final visible = _expanded ? entries : entries.take(2).toList();
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('COMMAND', style: _lcdLabelStyle),
              const SizedBox(height: 3),
              Text(
                intent,
                maxLines: _expanded ? null : 3,
                overflow: _expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: const TextStyle(color: _LcdPalette.light, fontSize: 12),
              ),
              if (intent.length > 100) _expandButton(),
              const SizedBox(height: 8),
              const Divider(color: _LcdPalette.mid, height: 1),
              const SizedBox(height: 6),
              const Text('SCHEDULE', style: _lcdLabelStyle),
              const SizedBox(height: 3),
              if (entries.isEmpty)
                const Text(
                  'NO SCHEDULED ITEMS',
                  style: TextStyle(color: _LcdPalette.mid, fontSize: 10),
                )
              else
                for (final entry in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '${entry.isTimed ? entry.record.startTime : 'ALL DAY'}  ${entry.record.title}',
                      maxLines: _expanded ? null : 1,
                      overflow: _expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _LcdPalette.light,
                        fontSize: 10,
                      ),
                    ),
                  ),
              if (entries.length > visible.length) _expandButton(),
              if (_expanded && entries.length > 2)
                TextButton(
                  onPressed: () => setState(() => _expanded = false),
                  child: const Text('COLLAPSE'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _expandButton() => Align(
    alignment: Alignment.centerRight,
    child: TextButton(
      onPressed: () => setState(() => _expanded = true),
      child: const Text('EXPAND'),
    ),
  );
}

class _LcdGrid extends StatelessWidget {
  const _LcdGrid({
    super.key,
    required this.children,
    this.columns = 3,
    this.aspectRatio = 1.62,
  });

  final List<Widget> children;
  final int columns;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: columns,
    mainAxisSpacing: 6,
    crossAxisSpacing: 6,
    childAspectRatio: aspectRatio,
    physics: const NeverScrollableScrollPhysics(),
    children: children,
  );
}

class _LcdProgressCard extends StatelessWidget {
  const _LcdProgressCard(
    this.label,
    this.value, {
    required this.progress,
    this.onTap,
    this.trailing,
    this.compact = false,
  });

  final String label;
  final String value;
  final double progress;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
        decoration: BoxDecoration(
          color: _LcdPalette.dark,
          border: Border.all(color: _LcdPalette.mid),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _lcdLabelStyle.copyWith(fontSize: compact ? 7 : 8),
                  ),
                ),
                if (trailing != null) ...[trailing!],
              ],
            ),
            const SizedBox(height: 1),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _LcdPalette.light,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            ClipRect(
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 3,
                color: _LcdPalette.light,
                backgroundColor: _LcdPalette.darkest,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _lcdLabelStyle),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _LcdPalette.light,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.index, required this.count});
  final int index;
  final int count;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List<Widget>.generate(
      count,
      (item) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        height: 4,
        width: index == item ? 21 : 7,
        decoration: BoxDecoration(
          color: index == item ? _LcdPalette.light : _LcdPalette.mid,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
}

class _TerminalPanel extends StatelessWidget {
  const _TerminalPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xff161b12),
      border: Border.all(color: const Color(0xff62644d)),
      borderRadius: BorderRadius.circular(7),
      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
    ),
    child: child,
  );
}

class _TerminalDetailSheet extends StatelessWidget {
  const _TerminalDetailSheet({
    required this.page,
    required this.snapshot,
    required this.morning,
    required this.food,
    required this.training,
    required this.activity,
    required this.openRoute,
    required this.openCalendar,
    required this.openWater,
  });
  final _TerminalPage page;
  final _TerminalSnapshot snapshot;
  final MorningFact? morning;
  final FoodSummary? food;
  final TrainingSummary? training;
  final ActivitySummary activity;
  final ValueChanged<String> openRoute;
  final VoidCallback openCalendar;
  final VoidCallback openWater;
  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: .72,
    minChildSize: .45,
    maxChildSize: .92,
    builder: (context, scrollController) => Container(
      decoration: const BoxDecoration(
        color: Color(0xff202619),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: Container(
              width: 46,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xffa9a083),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _detailTitle(page),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xfff0ead2),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ..._content(),
        ],
      ),
    ),
  );

  List<Widget> _content() => switch (page) {
    _TerminalPage.progress => [
      _DetailRows(
        rows: [
          _row(
            'STATUS',
            snapshot.command?.statusCompletion.displayState ?? 'NOT RECORDED',
          ),
          _row(
            'FOOD',
            snapshot.command?.foodCompletion.displayState ?? 'NOT RECORDED',
          ),
          _row(
            'TRAINING',
            snapshot.command?.trainingCompletion.displayState ?? 'NOT RECORDED',
          ),
          _row(
            'ACTIVITY',
            snapshot.command?.activityCompletion.displayState ?? 'NOT RECORDED',
          ),
          _row(
            'BRIEF / DEBRIEF',
            '${snapshot.briefRecorded ? 1 : 0} / ${snapshot.debriefRecorded ? 1 : 0}',
          ),
        ],
      ),
      const SizedBox(height: 14),
      _ActionRow(
        actions: [
          _action('STATUS', () => openRoute(AppRoutes.morning)),
          _action('COMMAND CENTER', () => openRoute(AppRoutes.commandCenter)),
        ],
      ),
    ],
    _TerminalPage.morning => [
      _DetailRows(
        rows: [
          _row('WEIGHT', _weightText(morning)),
          _row('SLEEP', _sleepText(morning)),
          _row('BASE BURN', _kcalText(snapshot.targets?.estimatedBaseBurnKcal)),
          _row('EXERCISE', _kcalText(training?.trainingEstimatedCaloriesKcal)),
          _row(
            'EST. TOTAL BURN',
            _kcalText(snapshot.targets?.estimatedTotalBurnKcal),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _ActionRow(
        actions: [_action('OPEN STATUS', () => openRoute(AppRoutes.morning))],
      ),
    ],
    _TerminalPage.sustainment => [
      _DetailRows(
        rows: [
          _row('MEALS', '${food?.mealCount ?? 0} / 3'),
          _row(
            'CALORIES',
            _rangeText(food?.calories, snapshot.targets?.calories),
          ),
          _row(
            'PROTEIN',
            _rangeText(food?.protein, snapshot.targets?.protein, suffix: ' g'),
          ),
          _row(
            'FAT',
            _rangeText(food?.fat, snapshot.targets?.fat, suffix: ' g'),
          ),
          _row(
            'CARBOHYDRATE',
            _rangeText(
              food?.carbohydrates,
              snapshot.targets?.carbohydrate,
              suffix: ' g',
            ),
          ),
          _row('WATER', _waterText(food, snapshot.targets)),
          _row(
            'TRAINING',
            training?.completed == true ? 'COMPLETE' : 'NOT RECORDED',
          ),
          _row(
            'ACTIVITY',
            activity.isRecorded ? '${activity.steps} steps' : 'NOT RECORDED',
          ),
        ],
      ),
      const SizedBox(height: 14),
      _ActionRow(
        actions: [
          _action('QUICK WATER', openWater),
          _action('FOOD', () => openRoute(AppRoutes.food)),
          _action('TRAINING', () => openRoute(AppRoutes.training)),
          _action('ACTIVITY', () => openRoute(AppRoutes.activity)),
        ],
      ),
    ],
    _TerminalPage.command => [
      Text(
        snapshot.command?.commanderIntent ?? 'COMMANDER INTENT UNAVAILABLE',
        style: const TextStyle(color: Color(0xffe8e2c9), fontSize: 16),
      ),
      const SizedBox(height: 14),
      _DetailRows(
        rows: [
          _row(
            'OPERATION DATE',
            snapshot.date.isEmpty ? 'UNAVAILABLE' : snapshot.date,
          ),
          _row('SCHEDULE ITEMS', '${snapshot.plan?.entries.length ?? 0}'),
          for (final entry
              in snapshot.plan?.entries ??
                  const <DashboardPlanInformationEntry>[])
            _row('PLAN', entry.record.title),
        ],
      ),
      const SizedBox(height: 14),
      _ActionRow(
        actions: [
          _action('OPEN CALENDAR', openCalendar),
          _action('COMMAND CENTER', () => openRoute(AppRoutes.commandCenter)),
        ],
      ),
    ],
  };
}

class _DetailRows extends StatelessWidget {
  const _DetailRows({required this.rows});
  final List<_DetailRow> rows;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xff141911),
      border: Border.all(color: const Color(0xff676b51)),
    ),
    child: Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Expanded(child: Text(row.label, style: _labelStyle)),
                Flexible(
                  child: Text(
                    row.value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Color(0xffe8e2c9)),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.actions});
  final List<_DetailAction> actions;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final action in actions)
        OutlinedButton(onPressed: action.onPressed, child: Text(action.label)),
    ],
  );
}

class _DetailRow {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;
}

class _DetailAction {
  const _DetailAction(this.label, this.onPressed);
  final String label;
  final VoidCallback onPressed;
}

_DetailRow _row(String label, String value) => _DetailRow(label, value);
_DetailAction _action(String label, VoidCallback onPressed) =>
    _DetailAction(label, onPressed);

class _TerminalChassisPainter extends CustomPainter {
  const _TerminalChassisPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xff5f624a);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset(4, 4) & Size(size.width - 8, size.height - 8),
        const Radius.circular(10),
      ),
      seam,
    );
    final fastener = Paint()..color = const Color(0xffa9a083);
    for (final point in [
      const Offset(10, 10),
      Offset(size.width - 10, 10),
      Offset(10, size.height - 10),
      Offset(size.width - 10, size.height - 10),
    ]) {
      canvas.drawCircle(point, 1.5, fastener);
    }
  }

  @override
  bool shouldRepaint(covariant _TerminalChassisPainter oldDelegate) => false;
}

class _TerminalSnapshot {
  const _TerminalSnapshot({
    required this.date,
    required this.command,
    required this.plan,
    required this.targets,
    required this.briefRecorded,
    required this.debriefRecorded,
  });
  const _TerminalSnapshot.unavailable()
    : date = '',
      command = null,
      plan = null,
      targets = null,
      briefRecorded = false,
      debriefRecorded = false;
  final String date;
  final DailyCommandReadModel? command;
  final DashboardPlanInformation? plan;
  final DynamicDailyTargetResult? targets;
  final bool briefRecorded;
  final bool debriefRecorded;
}

enum _TerminalPage { progress, morning, sustainment, command }

const _labelStyle = TextStyle(
  color: Color(0xffa9a083),
  fontSize: 9,
  fontWeight: FontWeight.w700,
  letterSpacing: .7,
);

const _lcdLabelStyle = TextStyle(
  color: _LcdPalette.mid,
  fontSize: 9,
  fontWeight: FontWeight.w700,
  letterSpacing: .7,
);

abstract final class _LcdPalette {
  static const darkest = Color(0xff273326);
  static const dark = Color(0xff485c3f);
  static const mid = Color(0xff8d9d79);
  static const light = Color(0xffaeb894);
}

Color _statusColor(OperationStatus? status) => switch (status) {
  OperationStatus.green => const Color(0xffa7d84c),
  OperationStatus.yellow => const Color(0xffffc857),
  OperationStatus.red => const Color(0xffff6b6b),
  OperationStatus.black => const Color(0xff8d9091),
  null => const Color(0xffa9a083),
};
String _weightText(MorningFact? fact) => fact?.weight == null
    ? 'NOT RECORDED'
    : '${fact!.weight!.toStringAsFixed(1)} kg';
String _sleepText(MorningFact? fact) {
  final value = fact?.sleepDuration;
  return value == null
      ? 'NOT RECORDED'
      : '${value.inHours}h ${(value.inMinutes % 60).toString().padLeft(2, '0')}m';
}

String _kcalText(double? value) =>
    value == null ? 'NOT CALCULATED' : '${value.toStringAsFixed(0)} kcal';
String _rangeText(
  double? current,
  DynamicRangeTarget? target, {
  String suffix = ' kcal',
}) {
  if (current == null) return 'NOT RECORDED';
  final targetValue = DynamicDailyTargetPresentation.caloriesTargetKcal(target);
  final shown = current.toStringAsFixed(
    current == current.roundToDouble() ? 0 : 1,
  );
  return targetValue == null ? '$shown$suffix' : '$shown / $targetValue$suffix';
}

String _waterText(FoodSummary? food, DynamicDailyTargetResult? targets) {
  if (food?.waterRecorded != true) return 'NOT RECORDED';
  final target = DynamicDailyTargetPresentation.waterTargetMl(targets?.water);
  return target == null
      ? '${food!.hydrationMl.toStringAsFixed(0)} ml'
      : '${food!.hydrationMl.toStringAsFixed(0)} / $target ml';
}

String _progressRange(
  double? current,
  DynamicRangeTarget? target, {
  String unit = 'kcal',
}) {
  if (current == null) return 'NOT RECORDED';
  final targetValue = unit == 'kcal'
      ? DynamicDailyTargetPresentation.caloriesTargetKcal(target)
      : DynamicDailyTargetPresentation.proteinTargetG(target);
  final shown = current.toStringAsFixed(
    current == current.roundToDouble() ? 0 : 1,
  );
  return targetValue == null ? '$shown $unit' : '$shown / $targetValue $unit';
}

double _rangeProgress(DynamicRangeTarget? target) {
  final current = target?.current;
  final low = target?.low;
  if (current == null || low == null || low <= 0) return 0;
  return (current / low).clamp(0, 1).toDouble();
}

double _waterProgress(DynamicWaterTarget? target) {
  final current = target?.current;
  final goal = target?.finalTargetMl;
  if (current == null || goal == null || goal <= 0) return 0;
  return (current / goal).clamp(0, 1).toDouble();
}

String _detailTitle(_TerminalPage page) => switch (page) {
  _TerminalPage.progress => 'OPERATION PROGRESS',
  _TerminalPage.morning => 'MORNING DATA',
  _TerminalPage.sustainment => 'SUSTAINMENT',
  _TerminalPage.command => 'COMMAND / SCHEDULE',
};
