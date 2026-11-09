import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/engine/food_summary.dart';
import 'package:or_app/core/engine/operation_status.dart';
import 'package:or_app/core/engine/training_summary.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
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
                          // V2.7 keeps the supplied square scene intact.
                          // The chassis may own surplus space, but it never
                          // crops or non-uniformly scales the map image.
                          final naturalMapHeight = width + 14;
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
                                    ValueListenableBuilder<DeviceSettings>(
                                      valueListenable:
                                          DeviceSettingsController.instance,
                                      builder: (context, settings, _) =>
                                          _BaseCampLcdMode(
                                            negative:
                                                settings.baseCampLcdNegative,
                                            child: _TacticalTerminal(
                                              snapshot: snapshot,
                                              morning: morning,
                                              food: food,
                                              training: training,
                                              activity: activity,
                                              pages: _pages,
                                              page: _page,
                                              onPageChanged: (value) =>
                                                  setState(() => _page = value),
                                              onOpenDetail: (page) =>
                                                  _openDetail(
                                                    page,
                                                    snapshot,
                                                    morning,
                                                    food,
                                                    training,
                                                    activity,
                                                  ),
                                            ),
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
        // The map remains one proportional square scene; the chassis owns
        // surplus height rather than scaling or cropping image/overlays.
        child: AspectRatio(
          aspectRatio:
              baseCampMapArtworkSize.width / baseCampMapArtworkSize.height,
          child: child,
        ),
      ),
    ),
  );
}

class _TacticalTerminal extends StatelessWidget {
  static const height = 350.0;
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
      child: MediaQuery.withNoTextScaling(
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            children: [
              const _TerminalHeading(),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: Row(
                  children: [
                    const Expanded(
                      flex: 4,
                      child: _BreathingSoldierCompartment(),
                    ),
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
                height: 182,
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
                      title: 'STATUS DATA',
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
      const SizedBox(width: 5),
      _LcdPolaritySwitch(negative: _BaseCampLcdMode.of(context)),
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

class _LcdPolaritySwitch extends StatelessWidget {
  const _LcdPolaritySwitch({required this.negative});
  final bool negative;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: negative
        ? 'LCD negative mode. Switch to positive.'
        : 'LCD positive mode. Switch to negative.',
    child: InkWell(
      key: const ValueKey('base-camp-lcd-polarity-switch'),
      onTap: () {
        final settings = DeviceSettingsController.instance.value;
        DeviceSettingsController.instance.update(
          settings.copyWith(baseCampLcdNegative: !settings.baseCampLcdNegative),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: negative ? _LcdPalette.darkest : _LcdPalette.light,
          border: Border.all(color: _LcdPalette.mid),
        ),
        child: Text(
          'INV',
          style: TextStyle(
            color: negative ? _LcdPalette.light : _LcdPalette.darkest,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
      ),
    ),
  );
}

class _BreathingSoldierCompartment extends StatefulWidget {
  const _BreathingSoldierCompartment();

  @override
  State<_BreathingSoldierCompartment> createState() =>
      _BreathingSoldierCompartmentState();
}

class _BreathingSoldierCompartmentState
    extends State<_BreathingSoldierCompartment>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _breathingController;
  late final AnimationController _specialController;
  final math.Random _random = math.Random();
  Timer? _specialTimer;
  bool _active = true;
  bool _rifleFramesReady = false;
  bool _rifleFramePrecacheStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _specialController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: baseCampRifleRegripEventMs),
    )..addStatusListener(_onSpecialStatus);
    _scheduleSpecialEvent();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rifleFramePrecacheStarted) return;
    _rifleFramePrecacheStarted = true;
    _precacheRifleFrames();
  }

  Future<void> _precacheRifleFrames() async {
    var allFramesLoaded = true;
    for (final asset in baseCampRifleRegripAssets) {
      try {
        await precacheImage(AssetImage(asset), context);
      } catch (error, stackTrace) {
        allFramesLoaded = false;
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'base_camp',
            context: ErrorDescription('while preloading rifle regrip frame'),
            informationCollector: () => [
              DiagnosticsProperty<String>('asset', asset),
            ],
          ),
        );
      }
    }
    if (mounted) setState(() => _rifleFramesReady = allFramesLoaded);
  }

  void _onSpecialStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _breathingController
      ..value = 0
      ..repeat();
    _scheduleSpecialEvent();
  }

  void _scheduleSpecialEvent() {
    _specialTimer?.cancel();
    if (!_active || !mounted) return;
    _specialTimer = Timer(
      Duration(milliseconds: baseCampRifleRegripIntervalMs(_random.nextInt)),
      _startSpecialEvent,
    );
  }

  void _startSpecialEvent() {
    if (!mounted || !_active || _specialController.isAnimating) return;
    _specialTimer?.cancel();
    _breathingController
      ..stop()
      ..value = 0;
    _specialController.forward(from: 0);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) {
      if (!_specialController.isAnimating) {
        _breathingController
          ..value = 0
          ..repeat();
      }
      _scheduleSpecialEvent();
    } else {
      _specialTimer?.cancel();
      _breathingController.stop();
      _specialController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _specialTimer?.cancel();
    _breathingController.dispose();
    _specialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduced && _breathingController.isAnimating) {
      _breathingController.stop();
    }
    if (!reduced &&
        _active &&
        !_breathingController.isAnimating &&
        !_specialController.isAnimating) {
      _breathingController.repeat();
    }
    return _TerminalPanel(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: SizedBox(
              width: constraints.maxWidth - 8,
              height: constraints.maxHeight - 8,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.hardEdge,
                children: [
                  const Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.all(_soldierViewportPadding),
                      child: IgnorePointer(
                        child: CustomPaint(painter: _SoldierPanelGridPainter()),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(_soldierViewportPadding),
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _breathingController,
                          _specialController,
                        ]),
                        builder: (context, _) {
                          final elapsed =
                              (_specialController.value *
                                      baseCampRifleRegripEventMs)
                                  .floor();
                          final phase = _specialController.isAnimating
                              ? baseCampRifleRegripPhase(elapsed)
                              : BaseCampRifleRegripPhase.breathing;
                          final showRifleFrame =
                              _rifleFramesReady &&
                              (phase == BaseCampRifleRegripPhase.rifleRegrip ||
                                  phase == BaseCampRifleRegripPhase.postIdle);
                          if (showRifleFrame) {
                            final frame =
                                phase == BaseCampRifleRegripPhase.postIdle
                                ? baseCampRifleRegripAssets.length - 1
                                : baseCampRifleRegripFrameIndex(elapsed);
                            return _RifleRegripFrame(
                              asset: baseCampRifleRegripAssets[frame],
                              key: ValueKey(
                                'base-camp-rifle-regrip-frame-$frame',
                              ),
                            );
                          }
                          final dy =
                              phase == BaseCampRifleRegripPhase.preIdle ||
                                  reduced
                              ? 0.0
                              : baseCampBreathingOffset(
                                  _breathingController.value *
                                      _breathingCycleMs,
                                );
                          return _NormalSoldierComposite(dy: dy);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const breathingSoldierReferenceAsset =
    'assets/images/themes/base_camp/breathing_soldier/ChatGPT Image 2026年8月16日 21_03_48.png';
const _breathingSoldierLowerAsset =
    'assets/images/themes/base_camp/breathing_soldier/gasmask_lowerboady.png';
const baseCampBreathingSoldierUpperAsset =
    'assets/images/themes/base_camp/breathing_soldier/gasmask_upperboady.png';
const _soldierViewportPadding = 4.0;

const baseCampRifleRegripAssets = [
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_corrected_F0.png',
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_corrected_F1.png',
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_corrected_F2.png',
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_corrected_F3.png',
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_corrected_F4.png',
  'assets/images/themes/base_camp/breathing_soldier/rifle_regrip/rifle_regrip_corrected_F5.png',
];

class _NormalSoldierComposite extends StatelessWidget {
  const _NormalSoldierComposite({required this.dy});
  final double dy;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    clipBehavior: Clip.hardEdge,
    children: [
      Image.asset(
        _breathingSoldierLowerAsset,
        key: const ValueKey('base-camp-soldier-lower'),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
      ),
      Transform.translate(
        offset: Offset(0, dy),
        child: Image.asset(
          baseCampBreathingSoldierUpperAsset,
          key: const ValueKey('base-camp-soldier-upper'),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
        ),
      ),
    ],
  );
}

/// Geometry shared by all corrected rifle frames.  The special sequence is
/// calibrated against the normal two-layer composite's measured opaque bounds
/// rather than against a screenshot or an individual animation frame.
@immutable
class BaseCampRifleRegripLayout {
  const BaseCampRifleRegripLayout({
    required this.normalFootY,
    required this.normalHeadY,
    required this.specialFootY,
    required this.specialHeadY,
    required this.specialLeft,
    required this.specialTop,
    required this.specialDimension,
  });

  final double normalFootY;
  final double normalHeadY;
  final double specialFootY;
  final double specialHeadY;
  final double specialLeft;
  final double specialTop;
  final double specialDimension;
}

const _normalSoldierCanvas = Size(1312, 1199);
const _normalSoldierVisibleLeft = 81.0;
const _normalSoldierVisibleRight = 1263.0;
const _normalSoldierVisibleTop = 0.0;
const _normalSoldierVisibleHeight = 1183.0;
const _normalSoldierVisibleBottom = 1182.0;
const _rifleFrameCanvas = 512.0;
const _rifleFrameVisibleTop = 32.0;
const _rifleFrameVisibleHeight = 480.0;
const _rifleFrameVisibleBottom = 511.0;

BaseCampRifleRegripLayout baseCampRifleRegripLayout(Size viewport) {
  final normalScale = math.min(
    viewport.width / _normalSoldierCanvas.width,
    viewport.height / _normalSoldierCanvas.height,
  );
  final frameScale =
      normalScale * _normalSoldierVisibleHeight / _rifleFrameVisibleHeight;
  final normalLeft =
      (viewport.width - _normalSoldierCanvas.width * normalScale) / 2;
  final normalTop =
      (viewport.height - _normalSoldierCanvas.height * normalScale) / 2;
  final normalFoot = normalTop + _normalSoldierVisibleBottom * normalScale;
  final normalHead = normalTop + _normalSoldierVisibleTop * normalScale;
  final normalCenter =
      normalLeft +
      (_normalSoldierVisibleLeft + _normalSoldierVisibleRight) /
          2 *
          normalScale;
  final specialLeft = normalCenter - _rifleFrameCanvas / 2 * frameScale;
  final specialTop = normalFoot - _rifleFrameVisibleBottom * frameScale;
  return BaseCampRifleRegripLayout(
    normalFootY: normalFoot,
    normalHeadY: normalHead,
    specialFootY: specialTop + _rifleFrameVisibleBottom * frameScale,
    specialHeadY: specialTop + _rifleFrameVisibleTop * frameScale,
    specialLeft: specialLeft,
    specialTop: specialTop,
    specialDimension: _rifleFrameCanvas * frameScale,
  );
}

/// The approved special sequence uses a square canvas while the normal
/// composite is 1312×1199.  Corrected rifle assets share a 480px-tall,
/// foot-aligned opaque region, so every frame can use this one transform.
class _RifleRegripFrame extends StatelessWidget {
  const _RifleRegripFrame({super.key, required this.asset});
  final String asset;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final layout = baseCampRifleRegripLayout(constraints.biggest);
      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: layout.specialLeft,
            top: layout.specialTop,
            width: layout.specialDimension,
            height: layout.specialDimension,
            child: Image.asset(
              asset,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
          ),
        ],
      );
    },
  );
}

enum BaseCampRifleRegripPhase { breathing, preIdle, rifleRegrip, postIdle }

const baseCampRifleRegripPreIdleMs = 1000;
const baseCampRifleRegripAnimationMs = 1850;
const baseCampRifleRegripPostIdleMs = 1000;
const baseCampRifleRegripEventMs =
    baseCampRifleRegripPreIdleMs +
    baseCampRifleRegripAnimationMs +
    baseCampRifleRegripPostIdleMs;
const baseCampRifleRegripFrameDurations = [400, 350, 200, 350, 150, 400];

BaseCampRifleRegripPhase baseCampRifleRegripPhase(int elapsedMs) {
  if (elapsedMs < baseCampRifleRegripPreIdleMs) {
    return BaseCampRifleRegripPhase.preIdle;
  }
  if (elapsedMs <
      baseCampRifleRegripPreIdleMs + baseCampRifleRegripAnimationMs) {
    return BaseCampRifleRegripPhase.rifleRegrip;
  }
  if (elapsedMs < baseCampRifleRegripEventMs) {
    return BaseCampRifleRegripPhase.postIdle;
  }
  return BaseCampRifleRegripPhase.breathing;
}

int baseCampRifleRegripFrameIndex(int eventElapsedMs) {
  var frameElapsed = eventElapsedMs - baseCampRifleRegripPreIdleMs;
  for (
    var index = 0;
    index < baseCampRifleRegripFrameDurations.length;
    index++
  ) {
    final duration = baseCampRifleRegripFrameDurations[index];
    if (frameElapsed < duration) return index;
    frameElapsed -= duration;
  }
  return baseCampRifleRegripFrameDurations.length - 1;
}

int baseCampRifleRegripIntervalMs(int Function(int max) nextInt) =>
    60000 + nextInt(60001);

const _breathingCycleMs = 2400.0;

/// The rigid upper layer moves from neutral to one logical pixel upward. The
/// fixed lower layer never receives a transform.
double baseCampBreathingOffset(double elapsedMs) {
  final phase = (elapsedMs % _breathingCycleMs) / _breathingCycleMs;
  return -.5 * (1 - math.cos(2 * math.pi * phase));
}

/// Static two-plane tactical grid for the soldier compartment.  It has no
/// animation/listenable, so it remains completely stable while the normal or
/// special soldier animation changes above it.
class _SoldierPanelGridPainter extends CustomPainter {
  const _SoldierPanelGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final groundY = baseCampSoldierGroundY(size);
    final wallLine = Paint()
      ..color = const Color(0xff718268).withValues(alpha: .20)
      ..strokeWidth = .7;
    final boundary = Paint()
      ..color = const Color(0xff93a77d).withValues(alpha: .40)
      ..strokeWidth = 1;
    final floorLine = Paint()
      ..color = const Color(0xff718268).withValues(alpha: .25)
      ..strokeWidth = .7;
    final ray = Paint()
      ..color = const Color(0xff718268).withValues(alpha: .30)
      ..strokeWidth = .8;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Background wall: one shared origin and each line exactly once.
    for (final x in baseCampSoldierWallLinePositions(size.width)) {
      canvas.drawLine(Offset(x, 0), Offset(x, groundY), wallLine);
    }
    for (final y in baseCampSoldierWallLinePositions(groundY)) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), wallLine);
    }
    // The boundary is deliberately not a second wall-grid horizontal line.
    canvas.drawLine(Offset(0, groundY), Offset(size.width, groundY), boundary);

    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, groundY, size.width, size.height - groundY),
    );
    for (final y in baseCampSoldierFloorLinePositions(size)) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), floorLine);
    }
    // Each floor ray begins at the corresponding wall-grid vertical.  This
    // keeps one shared coordinate origin and avoids a false fan converging at
    // the horizon centre.
    for (final x in baseCampSoldierWallLinePositions(size.width)) {
      canvas.drawLine(
        Offset(x, groundY),
        baseCampSoldierPerspectiveEndpoint(size, x),
        ray,
      );
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SoldierPanelGridPainter oldDelegate) => false;
}

const baseCampSoldierWallGridSpacing = 32.0;
const baseCampSoldierGroundLineRatios = <double>[.25, .55, .85];

/// The perspective floor starts below the standing soldier.  It intentionally
/// uses a ratio of the drawable panel, not a screenshot-specific pixel value.
double baseCampSoldierGroundY(Size size) => size.height * .78;

List<double> baseCampSoldierWallLinePositions(double extent) {
  final result = <double>[];
  for (
    var value = 0.0;
    value < extent;
    value += baseCampSoldierWallGridSpacing
  ) {
    result.add(value);
  }
  return result;
}

List<double> baseCampSoldierFloorLinePositions(Size size) {
  final groundY = baseCampSoldierGroundY(size);
  final floorDepth = size.height - groundY;
  return baseCampSoldierGroundLineRatios
      .map((ratio) => groundY + floorDepth * ratio)
      .where((y) => y < size.height)
      .toList(growable: false);
}

Offset baseCampSoldierPerspectiveEndpoint(Size size, double wallX) {
  final centerX = size.width * .5;
  return Offset(centerX + (wallX - centerX) * 1.8, size.height);
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
              height: 27,
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
            SizedBox(
              height: 10,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _StatusLamps(status: status),
              ),
            ),
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
    mainAxisSize: MainAxisSize.min,
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
        width: 10,
        height: 10,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: const Color(0xff485c3f),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xffaeb894), width: .7),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 1)],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: active ? color : const Color(0xff273326),
            shape: BoxShape.circle,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: .65),
                      blurRadius: 3,
                    ),
                  ]
                : null,
          ),
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
  Set<int> _changedDigits = const <int>{};
  Timer? _dimResetTimer;
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
    if (_active) {
      _start();
    } else {
      _timer?.cancel();
      _dimResetTimer?.cancel();
      if (mounted) setState(() => _changedDigits = const <int>{});
    }
  }

  void _start() {
    _timer?.cancel();
    if (!_active) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = DateTime.now();
      final previous = baseCampClockText(_now);
      final current = baseCampClockText(next);
      if (!mounted) return;
      final changed = dotMatrixClockChangedIndexes(previous, current);
      _dimResetTimer?.cancel();
      setState(() {
        _changedDigits = changed;
        _now = next;
      });
      if (changed.isNotEmpty) {
        _dimResetTimer = Timer(const Duration(milliseconds: 100), () {
          if (mounted) setState(() => _changedDigits = const <int>{});
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _dimResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('base-camp-dot-matrix-clock'),
    height: 14,
    width: double.infinity,
    child: CustomPaint(
      painter: _DotMatrixClockPainter(
        text: baseCampClockText(_now),
        changedDigits: _changedDigits,
      ),
    ),
  );
}

String baseCampClockText(DateTime value) {
  const weekday = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  String pair(int number) => number.toString().padLeft(2, '0');
  return '${pair(value.month)}/${pair(value.day)} (${weekday[value.weekday - 1]}) ${pair(value.hour)}:${pair(value.minute)}:${pair(value.second)}';
}

/// The transition set is deliberately derived from every character, rather
/// than only the seconds digit, so minute/day rollovers cannot leave a dim
/// character behind.
Set<int> dotMatrixClockChangedIndexes(String previous, String current) => {
  for (var index = 0; index < current.length; index++)
    if (index >= previous.length || current[index] != previous[index]) index,
};

class _DotMatrixClockPainter extends CustomPainter {
  const _DotMatrixClockPainter({
    required this.text,
    required this.changedDigits,
  });
  final String text;
  final Set<int> changedDigits;

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
    'O': ['111', '101', '101', '101', '111'],
    'A': ['010', '101', '111', '101', '101'],
    'N': ['101', '111', '111', '111', '101'],
    'R': ['110', '101', '110', '101', '101'],
    'I': ['111', '010', '010', '010', '111'],
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
        ..color = const Color(
          0xffc7d6a0,
        ).withValues(alpha: changedDigits.contains(index) ? .58 : 1);
      final dim = Paint()
        ..color = const Color(0xff485c3f).withValues(alpha: .25);
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
      oldDelegate.text != text || oldDelegate.changedDigits != changedDigits;
}

class _IndustrialLcdPanel extends StatelessWidget {
  const _IndustrialLcdPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final negative = _BaseCampLcdMode.of(context);
    return DecoratedBox(
      key: const ValueKey('base-camp-industrial-lcd'),
      decoration: BoxDecoration(
        color: negative ? _LcdPalette.darkest : _LcdPalette.light,
        border: Border.all(color: _LcdPalette.mid),
        borderRadius: BorderRadius.circular(7),
      ),
      child: child,
    );
  }
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
                        style: TextStyle(
                          color: _LcdColors.ink(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .9,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.open_in_full,
                      size: 15,
                      color: _LcdColors.ink(context),
                    ),
                  ],
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _LcdColors.auxiliary(context),
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
          baseCampFoodProgressText(foodCount),
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

/// The terminal preserves the formal FOOD completion semantics while keeping
/// the display contract in one place for the compact instrument readout.
String baseCampFoodProgressText(int mealCount) {
  final count = mealCount.clamp(0, 3).toInt();
  if (count == 0) return 'NOT RECORDED';
  if (count == 3) return 'COMPLETE';
  return '$count / 3';
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
  Widget build(BuildContext context) => _SustainmentGrid(
    calories: _rangeText(food?.calories, targets?.calories),
    protein: _rangeText(food?.protein, targets?.protein, suffix: ' g'),
    water: _waterText(food, targets),
    training: training?.completed == true ? 'COMPLETE' : 'NOT RECORDED',
    activity: activity.isRecorded ? '${activity.steps} steps' : 'NOT RECORDED',
  );
}

class _SustainmentGrid extends StatelessWidget {
  const _SustainmentGrid({
    required this.calories,
    required this.protein,
    required this.water,
    required this.training,
    required this.activity,
  });
  final String calories;
  final String protein;
  final String water;
  final String training;
  final String activity;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: SizedBox(
      height: _InstrumentGeometry.gridHeight,
      child: Column(
        children: [
          SizedBox(
            height: _InstrumentGeometry.panelHeight,
            child: Row(
              children: [
                Expanded(flex: 2, child: _Metric('CALORIES', calories)),
                const SizedBox(width: 6),
                Expanded(child: _Metric('PROTEIN', protein)),
              ],
            ),
          ),
          const SizedBox(height: _InstrumentGeometry.gap),
          SizedBox(
            height: _InstrumentGeometry.panelHeight,
            child: Row(
              children: [
                Expanded(child: _Metric('WATER', water)),
                const SizedBox(width: 6),
                Expanded(child: _Metric('TRAINING', training)),
                const SizedBox(width: 6),
                Expanded(child: _Metric('ACTIVITY', activity)),
              ],
            ),
          ),
        ],
      ),
    ),
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
    final ordered = [...entries]
      ..sort(
        (left, right) =>
            _scheduleTimeLabel(left).compareTo(_scheduleTimeLabel(right)),
      );
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final nextTimedIndex = ordered.indexWhere((entry) {
      final minutes = _scheduleMinutes(entry);
      return minutes != null && minutes >= nowMinutes;
    });
    final intent =
        widget.snapshot.command?.commanderIntent ??
        'COMMANDER INTENT UNAVAILABLE';
    final visible = _expanded ? ordered : ordered.take(3).toList();
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
                key: const ValueKey('base-camp-command-intent'),
                maxLines: _expanded ? null : 2,
                overflow: _expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                // COMMAND content participates in LCD polarity exactly like
                // the other readouts.  No inherited alpha or fixed light
                // colour is allowed to wash out Japanese or English text.
                style: TextStyle(color: _LcdColors.ink(context), fontSize: 11),
              ),
              if (intent.length > 100) _expandButton(),
              const SizedBox(height: 8),
              const Divider(color: _LcdPalette.mid, height: 1),
              const SizedBox(height: 6),
              const Text('SCHEDULE', style: _lcdLabelStyle),
              const SizedBox(height: 3),
              if (ordered.isEmpty)
                const Text(
                  'NO SCHEDULED ITEMS',
                  style: TextStyle(color: _LcdPalette.mid, fontSize: 10),
                )
              else
                for (final entry in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: _TacticalScheduleRow(
                      number: ordered.indexOf(entry) + 1,
                      time: _scheduleTimeLabel(entry),
                      title: entry.record.title,
                      active: ordered.indexOf(entry) == nextTimedIndex,
                    ),
                  ),
              if (ordered.length > visible.length) _expandButton(),
              if (_expanded && ordered.length > 3)
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
      child: const Text('+ MORE'),
    ),
  );
}

class _TacticalScheduleRow extends StatelessWidget {
  const _TacticalScheduleRow({
    required this.number,
    required this.time,
    required this.title,
    required this.active,
  });
  final int number;
  final String time;
  final String title;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ink = _LcdColors.ink(context);
    return Container(
      height: 21,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: _LcdColors.field(context),
        border: Border.all(color: _LcdPalette.mid),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              // These schedule lamps are LCD navigation indicators rather
              // than an Operation Status semantic colour.  Their full-opacity
              // treatment must switch with INV.
              color: active
                  ? _LcdColors.ink(context)
                  : _LcdColors.auxiliary(context),
              shape: BoxShape.circle,
              border: Border.all(color: _LcdPalette.mid),
              boxShadow: active
                  ? [BoxShadow(color: _LcdColors.ink(context), blurRadius: 2)]
                  : null,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            number.toString().padLeft(2, '0'),
            style: _lcdLabelStyle.copyWith(fontSize: 10),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            color: _BaseCampLcdMode.of(context)
                ? _LcdPalette.darkest
                : _LcdPalette.mid,
            child: Text(
              time,
              style: TextStyle(
                color: ink,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ink,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _scheduleTimeLabel(DashboardPlanInformationEntry entry) {
  if (!entry.isTimed || entry.record.startTime == null) return 'ALL';
  final raw = entry.record.startTime!;
  final parsed = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw);
  if (parsed == null) return raw;
  return '${parsed.group(1)!.padLeft(2, '0')}:${parsed.group(2)!}';
}

int? _scheduleMinutes(DashboardPlanInformationEntry entry) {
  final match = RegExp(
    r'^(\d{1,2}):(\d{2})',
  ).firstMatch(_scheduleTimeLabel(entry));
  if (match == null) return null;
  return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
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
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: SizedBox(
      height: _InstrumentGeometry.gridHeight,
      child: GridView.count(
        crossAxisCount: columns,
        mainAxisSpacing: _InstrumentGeometry.gap,
        crossAxisSpacing: _InstrumentGeometry.gap,
        childAspectRatio: aspectRatio,
        mainAxisExtent: _InstrumentGeometry.panelHeight,
        physics: const NeverScrollableScrollPhysics(),
        children: children,
      ),
    ),
  );
}

class _LcdProgressCard extends StatelessWidget {
  const _LcdProgressCard(
    this.label,
    this.value, {
    required this.progress,
    this.onTap,
    this.compact = false,
  });

  final String label;
  final String value;
  final double progress;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Container(
        key: const ValueKey('base-camp-instrument-panel'),
        height: _InstrumentGeometry.panelHeight,
        padding: const EdgeInsets.symmetric(
          horizontal: _InstrumentGeometry.outerHorizontalPadding,
          vertical: _InstrumentGeometry.outerVerticalPadding,
        ),
        decoration: BoxDecoration(
          color: _LcdColors.panel(context),
          border: Border.all(color: _LcdPalette.mid),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 12,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _lcdLabelStyle.copyWith(
                  color: _LcdColors.auxiliary(context),
                  fontSize: compact ? 9 : _InstrumentGeometry.labelFontSize,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: _InstrumentGeometry.labelGap),
            Row(
              children: [
                _InstrumentPilotLamp(
                  active: progress >= 1,
                  partial: progress > 0 && progress < 1,
                ),
                const SizedBox(width: _InstrumentGeometry.lampGap),
                Expanded(child: _LcdReadout(value: value)),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _InstrumentPilotLamp extends StatelessWidget {
  const _InstrumentPilotLamp({required this.active, required this.partial});
  final bool active;
  final bool partial;

  @override
  Widget build(BuildContext context) => Container(
    width: _InstrumentGeometry.lampOuterDiameter,
    height: _InstrumentGeometry.lampOuterDiameter,
    padding: EdgeInsets.all(2.5),
    decoration: BoxDecoration(
      color: const Color(0xff485c3f),
      shape: BoxShape.circle,
      border: Border.all(color: _LcdPalette.mid, width: .8),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 1)],
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? const Color(0xffa7d84c)
            : partial
            ? _LcdPalette.mid
            : const Color(0xff273326),
        shape: BoxShape.circle,
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('base-camp-instrument-panel'),
    height: _InstrumentGeometry.panelHeight,
    padding: const EdgeInsets.symmetric(
      horizontal: _InstrumentGeometry.outerHorizontalPadding,
      vertical: _InstrumentGeometry.outerVerticalPadding,
    ),
    decoration: BoxDecoration(
      color: _LcdColors.panel(context),
      border: Border.all(color: _LcdPalette.mid),
      borderRadius: BorderRadius.circular(2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 12,
          child: Text(
            label,
            style: _lcdLabelStyle.copyWith(
              color: _LcdColors.auxiliary(context),
              fontSize: _InstrumentGeometry.labelFontSize,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: _InstrumentGeometry.labelGap),
        _LcdReadout(value: value),
      ],
    ),
  );
}

class _LcdReadout extends StatelessWidget {
  const _LcdReadout({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('base-camp-lcd-readout'),
    height: _InstrumentGeometry.lcdHeight,
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(
      horizontal: _InstrumentGeometry.lcdHorizontalPadding,
      vertical: _InstrumentGeometry.lcdVerticalPadding,
    ),
    decoration: BoxDecoration(
      color: _LcdColors.field(context),
      border: Border.all(color: _LcdPalette.mid),
      borderRadius: BorderRadius.circular(3),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        const base = TextStyle(
          fontSize: 12,
          height: 1.25,
          fontWeight: FontWeight.w800,
        );
        final painter = TextPainter(
          text: TextSpan(text: value, style: base),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: double.infinity);
        // The three-column progress panel is intentionally narrow on a
        // 320dp device. A measured per-readout scale keeps formal strings
        // such as NOT RECORDED intact without changing another cell's type.
        final scale =
            painter.width <= constraints.maxWidth || painter.width == 0
            ? 1.0
            : (constraints.maxWidth / painter.width).clamp(.35, 1.0);
        return Text(
          value,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          textScaler: TextScaler.linear(scale),
          style: base.copyWith(color: _LcdColors.ink(context)),
        );
      },
    ),
  );
}

abstract final class _InstrumentGeometry {
  static const panelHeight = 53.0;
  static const lcdHeight = 25.0;
  static const gap = 6.0;
  static const gridHeight = panelHeight * 2 + gap;
  static const outerHorizontalPadding = 6.0;
  static const outerVerticalPadding = 5.0;
  static const labelFontSize = 10.0;
  static const labelGap = 4.0;
  static const lcdHorizontalPadding = 6.0;
  static const lcdVerticalPadding = 4.0;
  static const lampOuterDiameter = 14.0;
  static const lampGap = 5.0;
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.index, required this.count});
  final int index;
  final int count;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var item = 0; item < count; item++) ...[
        if (item > 0) const SizedBox(width: 8),
        AnimatedContainer(
          key: ValueKey('base-camp-page-indicator-$item'),
          duration: const Duration(milliseconds: 180),
          height: 5,
          width: index == item ? 20 : 8,
          decoration: BoxDecoration(
            color: index == item
                ? _LcdColors.ink(context)
                : _LcdColors.auxiliary(context),
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
      ],
    ],
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

class _BaseCampLcdMode extends InheritedWidget {
  const _BaseCampLcdMode({required this.negative, required super.child});
  final bool negative;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_BaseCampLcdMode>()
          ?.negative ??
      false;

  @override
  bool updateShouldNotify(_BaseCampLcdMode oldWidget) =>
      oldWidget.negative != negative;
}

abstract final class _LcdColors {
  static bool _negative(BuildContext context) => _BaseCampLcdMode.of(context);
  static Color panel(BuildContext context) =>
      _negative(context) ? _LcdPalette.darkest : _LcdPalette.light;
  static Color field(BuildContext context) =>
      _negative(context) ? _LcdPalette.dark : _LcdPalette.mid;
  static Color ink(BuildContext context) =>
      _negative(context) ? _LcdPalette.light : _LcdPalette.darkest;
  static Color auxiliary(BuildContext context) =>
      _negative(context) ? _LcdPalette.mid : _LcdPalette.dark;
}

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

String _detailTitle(_TerminalPage page) => switch (page) {
  _TerminalPage.progress => 'OPERATION PROGRESS',
  _TerminalPage.morning => 'STATUS DATA',
  _TerminalPage.sustainment => 'SUSTAINMENT',
  _TerminalPage.command => 'COMMAND / SCHEDULE',
};
