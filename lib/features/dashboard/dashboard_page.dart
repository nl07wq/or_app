import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/engine/activity_summary.dart';
import '../../core/engine/food_summary.dart';
import '../../core/engine/operation_status.dart';
import '../../core/engine/operation_engine.dart';
import '../../core/engine/operation_input.dart';
import '../../core/engine/training_summary.dart';
import '../../core/models/meal_data.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';
import '../system/widgets/system_menu_button.dart';
import '../system/models/information_notice.dart';
import '../system/services/information_notice_service.dart';
import '../system/widgets/dashboard_information_strip.dart';
import '../system/widgets/information_detail_sheet.dart';
import '../../core/widgets/operation_text_field.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/widgets/confirmed_log_message.dart';
import '../../core/state/app_initialization_state.dart';

import '../food/services/food_submit_service.dart';
import '../food/data/water_quick_presets.dart';
import '../morning/models/morning_fact.dart';
import '../morning/models/morning_fact_state.dart';

import '../food/models/food_summary_state.dart';
import '../activity/models/activity_summary_state.dart';

import '../training/models/training_summary_state.dart';
import '../training/services/training_status_weight_resolver.dart';
import '../command_center/models/daily_command_read_model.dart';
import '../command_center/services/daily_command_read_model_builder.dart';
import '../command_center/widgets/daily_command_item.dart';
import '../command_center/widgets/semantic_help_popover.dart';
import '../command_center/pages/command_center_page.dart'
    show cycleStateHelp, cycleStateIconFor, cycleStateShortLabelFor;
import '../repositories/app_repository_container.dart';
import '../operation_date/models/operation_local_date.dart';
import '../operation_date/models/operation_state.dart';
import '../operation_date/services/daily_finalize_coordinator_factory.dart';
import '../operation_date/services/operation_date_service.dart';
import '../operation_date/state/finalize_date_transition.dart';
import '../operation_date/widgets/operation_date_presentation_switcher.dart';
import '../report_sync/models/daily_debrief_record.dart';
import '../report_sync/models/morning_brief_state.dart';

import 'models/dynamic_daily_target.dart';
import 'services/dynamic_daily_target_service.dart';
import 'widgets/operation_ambient_animation.dart';

/// A single, pre-planned electrical phase for the Dashboard brand sign.
///
/// The phases are intentionally data rather than frame-time randomness: an
/// event chooses one plan once, then plays it deterministically to recovery.
@immutable
class DashboardNeonFaultPhase {
  const DashboardNeonFaultPhase({
    required this.duration,
    required this.coreIntensity,
    required this.innerGlowIntensity,
    required this.outerGlowIntensity,
    required this.logoIntensity,
    required this.frameTubeIntensity,
    required this.frameReflectionIntensity,
  });

  final Duration duration;
  final double coreIntensity;
  final double innerGlowIntensity;
  final double outerGlowIntensity;
  final double logoIntensity;
  final double frameTubeIntensity;
  final double frameReflectionIntensity;

  bool get isFullyIlluminated =>
      coreIntensity == 1 &&
      innerGlowIntensity == 1 &&
      outerGlowIntensity == 1 &&
      logoIntensity == 1 &&
      frameTubeIntensity == 1 &&
      frameReflectionIntensity == 1;
}

/// A named, weighted electrical fault plan for the physical Dashboard sign.
@immutable
class DashboardNeonFaultFamily {
  const DashboardNeonFaultFamily({
    required this.name,
    required this.weight,
    required this.phases,
  });

  final String name;
  final int weight;
  final List<DashboardNeonFaultPhase> phases;
}

/// Pre-planned, irregular old-neon fault plans used by the header.
class DashboardNeonFaultPatterns {
  DashboardNeonFaultPatterns._();

  static const minimumInterval = Duration(seconds: 20);
  static const maximumInterval = Duration(seconds: 60);

  static const stable = DashboardNeonFaultPhase(
    duration: Duration.zero,
    coreIntensity: 1,
    innerGlowIntensity: 1,
    outerGlowIntensity: 1,
    logoIntensity: 1,
    frameTubeIntensity: 1,
    frameReflectionIntensity: 1,
  );

  static const _sharedDip = DashboardNeonFaultPhase(
    duration: Duration(milliseconds: 85),
    coreIntensity: .4,
    innerGlowIntensity: .2,
    outerGlowIntensity: .05,
    logoIntensity: .35,
    frameTubeIntensity: .2,
    frameReflectionIntensity: .16,
  );
  static const _sharedDark = DashboardNeonFaultPhase(
    duration: Duration(milliseconds: 92),
    coreIntensity: 0,
    innerGlowIntensity: .02,
    outerGlowIntensity: 0,
    logoIntensity: .03,
    frameTubeIntensity: .02,
    frameReflectionIntensity: .05,
  );
  static const _weakRestrike = DashboardNeonFaultPhase(
    duration: Duration(milliseconds: 65),
    coreIntensity: .55,
    innerGlowIntensity: .18,
    outerGlowIntensity: .07,
    logoIntensity: .45,
    frameTubeIntensity: .18,
    frameReflectionIntensity: .18,
  );
  static const _sharedRecovery = DashboardNeonFaultPhase(
    duration: Duration(milliseconds: 110),
    coreIntensity: 1,
    innerGlowIntensity: .72,
    outerGlowIntensity: .5,
    logoIntensity: .72,
    frameTubeIntensity: .55,
    frameReflectionIntensity: .46,
  );
  static const _wordmarkWeak = DashboardNeonFaultPhase(
    duration: Duration(milliseconds: 78),
    coreIntensity: .2,
    innerGlowIntensity: .06,
    outerGlowIntensity: .01,
    logoIntensity: .56,
    frameTubeIntensity: .74,
    frameReflectionIntensity: .2,
  );
  static const _wordmarkDark = DashboardNeonFaultPhase(
    duration: Duration(milliseconds: 58),
    coreIntensity: 0,
    innerGlowIntensity: 0,
    outerGlowIntensity: 0,
    logoIntensity: .42,
    frameTubeIntensity: .66,
    frameReflectionIntensity: .12,
  );
  static const _logoContact = DashboardNeonFaultPhase(
    duration: Duration(milliseconds: 120),
    coreIntensity: .9,
    innerGlowIntensity: .6,
    outerGlowIntensity: .38,
    logoIntensity: .05,
    frameTubeIntensity: .86,
    frameReflectionIntensity: .32,
  );
  static const _logoReturn = DashboardNeonFaultPhase(
    duration: Duration(milliseconds: 78),
    coreIntensity: 1,
    innerGlowIntensity: .82,
    outerGlowIntensity: .62,
    logoIntensity: .46,
    frameTubeIntensity: .92,
    frameReflectionIntensity: .55,
  );
  static const _logoFirst = DashboardNeonFaultPhase(
    duration: Duration(milliseconds: 96),
    coreIntensity: .12,
    innerGlowIntensity: .03,
    outerGlowIntensity: 0,
    logoIntensity: .62,
    frameTubeIntensity: .34,
    frameReflectionIntensity: .26,
  );
  static const _nearRecovery = DashboardNeonFaultPhase(
    duration: Duration(milliseconds: 140),
    coreIntensity: 1,
    innerGlowIntensity: .65,
    outerGlowIntensity: .42,
    logoIntensity: .8,
    frameTubeIntensity: .62,
    frameReflectionIntensity: .4,
  );

  /// Each plan is 350--900ms, begins stable, and settles in its stable state.
  static const families = <DashboardNeonFaultFamily>[
    DashboardNeonFaultFamily(
      name: 'shared_transformer_dip',
      weight: 34,
      phases: [
        stable,
        _sharedDip,
        _sharedDark,
        _weakRestrike,
        _sharedRecovery,
        stable,
      ],
    ),
    DashboardNeonFaultFamily(
      name: 'failed_shared_restrike',
      weight: 28,
      phases: [
        stable,
        _sharedDark,
        _weakRestrike,
        DashboardNeonFaultPhase(
          duration: Duration(milliseconds: 70),
          coreIntensity: 0,
          innerGlowIntensity: 0,
          outerGlowIntensity: 0,
          logoIntensity: .02,
          frameTubeIntensity: .04,
          frameReflectionIntensity: .05,
        ),
        DashboardNeonFaultPhase(
          duration: Duration(milliseconds: 60),
          coreIntensity: .7,
          innerGlowIntensity: .25,
          outerGlowIntensity: .1,
          logoIntensity: .55,
          frameTubeIntensity: .26,
          frameReflectionIntensity: .22,
        ),
        DashboardNeonFaultPhase(
          duration: Duration(milliseconds: 45),
          coreIntensity: .12,
          innerGlowIntensity: .03,
          outerGlowIntensity: 0,
          logoIntensity: .1,
          frameTubeIntensity: .08,
          frameReflectionIntensity: .08,
        ),
        _nearRecovery,
        stable,
      ],
    ),
    DashboardNeonFaultFamily(
      name: 'wordmark_tube_instability',
      weight: 20,
      phases: [
        stable,
        _wordmarkWeak,
        _wordmarkDark,
        DashboardNeonFaultPhase(
          duration: Duration(milliseconds: 55),
          coreIntensity: .64,
          innerGlowIntensity: .14,
          outerGlowIntensity: .04,
          logoIntensity: .64,
          frameTubeIntensity: .76,
          frameReflectionIntensity: .22,
        ),
        _wordmarkWeak,
        _sharedRecovery,
        stable,
      ],
    ),
    DashboardNeonFaultFamily(
      name: 'logo_emblem_contact',
      weight: 8,
      phases: [
        stable,
        _logoContact,
        DashboardNeonFaultPhase(
          duration: Duration(milliseconds: 48),
          coreIntensity: .94,
          innerGlowIntensity: .7,
          outerGlowIntensity: .45,
          logoIntensity: .32,
          frameTubeIntensity: .9,
          frameReflectionIntensity: .42,
        ),
        _logoContact,
        _logoReturn,
        stable,
      ],
    ),
    DashboardNeonFaultFamily(
      name: 'staged_logo_first_recovery',
      weight: 10,
      phases: [
        stable,
        _sharedDip,
        _sharedDark,
        _logoFirst,
        DashboardNeonFaultPhase(
          duration: Duration(milliseconds: 62),
          coreIntensity: .62,
          innerGlowIntensity: .13,
          outerGlowIntensity: .03,
          logoIntensity: .72,
          frameTubeIntensity: .38,
          frameReflectionIntensity: .28,
        ),
        _wordmarkWeak,
        DashboardNeonFaultPhase(
          duration: Duration(milliseconds: 110),
          coreIntensity: 1,
          innerGlowIntensity: .78,
          outerGlowIntensity: .54,
          logoIntensity: .85,
          frameTubeIntensity: .7,
          frameReflectionIntensity: .52,
        ),
        stable,
      ],
    ),
    DashboardNeonFaultFamily(
      name: 'frame_perimeter_contact',
      weight: 7,
      phases: [
        stable,
        DashboardNeonFaultPhase(
          duration: Duration(milliseconds: 74),
          coreIntensity: .92,
          innerGlowIntensity: .72,
          outerGlowIntensity: .48,
          logoIntensity: .76,
          frameTubeIntensity: .18,
          frameReflectionIntensity: .22,
        ),
        DashboardNeonFaultPhase(
          duration: Duration(milliseconds: 49),
          coreIntensity: .88,
          innerGlowIntensity: .68,
          outerGlowIntensity: .45,
          logoIntensity: .72,
          frameTubeIntensity: .48,
          frameReflectionIntensity: .34,
        ),
        DashboardNeonFaultPhase(
          duration: Duration(milliseconds: 67),
          coreIntensity: .94,
          innerGlowIntensity: .74,
          outerGlowIntensity: .52,
          logoIntensity: .78,
          frameTubeIntensity: .04,
          frameReflectionIntensity: .14,
        ),
        DashboardNeonFaultPhase(
          duration: Duration(milliseconds: 165),
          coreIntensity: 1,
          innerGlowIntensity: .84,
          outerGlowIntensity: .62,
          logoIntensity: .84,
          frameTubeIntensity: .58,
          frameReflectionIntensity: .44,
        ),
        stable,
      ],
    ),
  ];

  static List<List<DashboardNeonFaultPhase>> get patterns =>
      families.map((family) => family.phases).toList(growable: false);

  static DashboardNeonFaultFamily choose(math.Random random) {
    final totalWeight = families.fold<int>(
      0,
      (total, family) => total + family.weight,
    );
    var selection = random.nextInt(totalWeight);
    for (final family in families) {
      selection -= family.weight;
      if (selection < 0) return family;
    }
    return families.last;
  }

  static Duration intervalFor(math.Random random) {
    final span =
        maximumInterval.inMilliseconds - minimumInterval.inMilliseconds;
    return Duration(
      milliseconds: minimumInterval.inMilliseconds + random.nextInt(span + 1),
    );
  }
}

/// Fixed, device-independent geometry for the compact physical neon sign.
/// Keeping it data-backed lets the visual contract be tested without relying
/// on blur-fringe pixels.
abstract final class DashboardNeonTubeGeometry {
  static const signWidth = 118.0;
  static const signHeight = 42.0;
  static const physicalFrameRadius = 6.0;
  static const perimeterInset = 2.0;
  static const perimeterRadius = 4.0;
  static const signHorizontalPadding = 7.0;
  static const logoSize = 28.0;
  static const logoWordmarkGap = 3.0;
  static const lockupOffsetX = 1.0;

  static const wordmarkWidth = 63.0;
  static const wordmarkHeight = 22.0;
  static const glyphTop = 2.0;
  static const glyphBottom = 20.0;
  static const glyphHeight = glyphBottom - glyphTop;
  static const wordmarkPaintLeft = 2.0;
  static const wordmarkPaintRight = 61.0;
  static const ovalWidth = 12.0;
  static const rWidth = 12.0;
  static const lFootWidth = 9.0;
  static const tubeWidth = 2.1;
  static const hotCoreWidth = .75;
  static const periodRadius = .45;
  static const periodBaselineY = 18.4;
  static const periodCenters = <Offset>[
    Offset(15.8, periodBaselineY),
    Offset(32.5, periodBaselineY),
    Offset(46.5, periodBaselineY),
  ];
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<OperationLocalDate> _operationDateFuture;
  late final InformationNoticeService _informationService =
      InformationNoticeService();
  late Future<List<InformationNotice>> _informationNoticesFuture;
  late final FinalizeDateTransition? _dashboardFinalizeTransition;
  int _operationDateTransitionToken = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final finalizeTransition = FinalizeDateTransitionStore.take();
    _dashboardFinalizeTransition = finalizeTransition;
    _operationDateFuture = finalizeTransition == null
        ? const OperationDateService().current()
        : Future.value(finalizeTransition.fromDate);
    _informationNoticesFuture = _informationService.activeNotices();
    informationNoticeRevision.addListener(_refreshInformation);
    morningBriefRevisionNotifier.addListener(_refreshInformation);
    if (finalizeTransition != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _playFinalizeDateTransition(finalizeTransition);
      });
    }
  }

  @override
  void dispose() {
    informationNoticeRevision.removeListener(_refreshInformation);
    morningBriefRevisionNotifier.removeListener(_refreshInformation);
    _scrollController.dispose();
    super.dispose();
  }

  void _refreshInformation() {
    if (!mounted) return;
    setState(() {
      _informationNoticesFuture = _informationService.activeNotices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isReadOnly = appInitializationController.value.isReadOnly;
    return Builder(
      builder: (context) {
        return ValueListenableBuilder<MorningFact?>(
          valueListenable: morningFactNotifier,
          builder: (context, morningFact, _) {
            return ValueListenableBuilder<FoodSummary?>(
              valueListenable: foodSummaryNotifier,
              builder: (context, foodSummary, _) {
                return ValueListenableBuilder<TrainingSummary?>(
                  valueListenable: trainingSummaryNotifier,
                  builder: (context, trainingSummary, _) {
                    return ValueListenableBuilder<ActivitySummary>(
                      valueListenable: activitySummaryNotifier,
                      builder: (context, activitySummary, _) {
                        final input = morningFact == null
                            ? null
                            : OperationInput(
                                morning: morningFact,
                                food: foodSummary,
                                training: trainingSummary,
                                activity: activitySummary,
                              );
                        final engine = const OperationEngine();
                        final estimatedTDEE = input == null
                            ? null
                            : engine.estimateTDEE(input);

                        return Scaffold(
                          appBar: AppBar(
                            title: const _DashboardNeonBrandMark(),
                            actions: const [SystemMenuButton()],
                          ),
                          body: LayoutBuilder(
                            builder: (context, dashboardConstraints) {
                              final useLargeLayout =
                                  dashboardConstraints.maxWidth >= 900;
                              return ListView(
                                key: const ValueKey('dashboard-scroll-view'),
                                controller: _scrollController,
                                padding: AppSpacing.cardPadding,
                                children: [
                                  Center(
                                    child: ConstrainedBox(
                                      key: const ValueKey(
                                        'dashboard-main-content',
                                      ),
                                      constraints: const BoxConstraints(
                                        maxWidth: 1280,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _OperationDateCard(
                                            operationDateFuture:
                                                _operationDateFuture,
                                            transitionToken:
                                                _operationDateTransitionToken,
                                            finalizeTransition:
                                                _dashboardFinalizeTransition,
                                          ),
                                          FutureBuilder<
                                            List<InformationNotice>
                                          >(
                                            future: _informationNoticesFuture,
                                            builder: (context, snapshot) {
                                              final notices =
                                                  snapshot.data ?? const [];
                                              if (notices.isEmpty) {
                                                return const SizedBox.shrink();
                                              }
                                              return Column(
                                                children: [
                                                  AppSpacing.gapSM,
                                                  DashboardInformationStrip(
                                                    notices: notices,
                                                    onTap: () =>
                                                        _showInformation(
                                                          notices,
                                                        ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                          AppSpacing.gapLG,
                                          ValueListenableBuilder<int>(
                                            valueListenable:
                                                morningBriefRevisionNotifier,
                                            builder: (context, revision, _) =>
                                                _DashboardOperationOverview(
                                                  morningFact: morningFact,
                                                  estimatedTDEE: estimatedTDEE,
                                                  foodSummary: foodSummary,
                                                  trainingSummary:
                                                      trainingSummary,
                                                  activitySummary:
                                                      activitySummary,
                                                  refreshToken:
                                                      _operationDateTransitionToken,
                                                  morningBriefRevision:
                                                      revision,
                                                  useLargeLayout:
                                                      useLargeLayout,
                                                  onWaterTap: isReadOnly
                                                      ? null
                                                      : () =>
                                                            _showQuickWaterInput(
                                                              context,
                                                            ),
                                                ),
                                          ),
                                          AppSpacing.gapXL,
                                          SectionHeader(
                                            icon: Icons.bolt_outlined,
                                            title: 'QUICK ACCESS',
                                          ),
                                          AppSpacing.gapSM,
                                          _MorningButton(),
                                          AppSpacing.gapMD,
                                          _FoodButton(),
                                          AppSpacing.gapMD,
                                          _TrainingButton(),
                                          AppSpacing.gapMD,
                                          _ActivityButton(),
                                          AppSpacing.gapMD,
                                          _CommandCenterButton(),
                                          AppSpacing.gapMD,
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _playFinalizeDateTransition(
    FinalizeDateTransition transition,
  ) async {
    if (!mounted) return;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    await _waitUntilDashboardIsVisible();
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() {
      _operationDateFuture = Future.value(transition.toDate);
      _operationDateTransitionToken++;
    });
  }

  Future<void> _waitUntilDashboardIsVisible() async {
    final routeAnimation = ModalRoute.of(context)?.animation;
    if (routeAnimation == null ||
        routeAnimation.status == AnimationStatus.completed) {
      return;
    }
    final completer = Completer<void>();
    void listener(AnimationStatus status) {
      if (status == AnimationStatus.completed && !completer.isCompleted) {
        routeAnimation.removeStatusListener(listener);
        completer.complete();
      }
    }

    routeAnimation.addStatusListener(listener);
    listener(routeAnimation.status);
    await completer.future;
  }

  void _showQuickWaterInput(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _QuickWaterSheet(dashboardContext: context),
    );
  }

  Future<void> _showInformation(List<InformationNotice> notices) async {
    final result = await showModalBottomSheet<InformationDetailResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => InformationDetailSheet(
        notices: notices,
        onRead: _informationService.markRead,
        onDismiss: _informationService.dismiss,
      ),
    );
    if (!mounted) return;
    _refreshInformation();
    if (result == InformationDetailResult.systemMonitoring) {
      await Navigator.of(context).pushNamed(AppRoutes.systemMonitoring);
    }
  }
}

class _OperationDateCard extends StatelessWidget {
  const _OperationDateCard({
    required this.operationDateFuture,
    required this.transitionToken,
    required this.finalizeTransition,
  });

  final Future<OperationLocalDate> operationDateFuture;
  final int transitionToken;
  final FinalizeDateTransition? finalizeTransition;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            AppSpacing.gapSM,
            Text(
              'OPERATION DATE',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
        AppSpacing.gapSM,
        OperationDatePresentationSwitcher(
          operationDateFuture: operationDateFuture,
          transitionToken: transitionToken,
          finalizeTransition: finalizeTransition,
        ),
      ],
    ),
  );
}

class _DashboardOperationOverview extends StatefulWidget {
  const _DashboardOperationOverview({
    required this.morningFact,
    required this.estimatedTDEE,
    required this.foodSummary,
    required this.trainingSummary,
    required this.activitySummary,
    required this.refreshToken,
    required this.morningBriefRevision,
    required this.useLargeLayout,
    required this.onWaterTap,
  });

  final MorningFact? morningFact;
  final double? estimatedTDEE;
  final FoodSummary? foodSummary;
  final TrainingSummary? trainingSummary;
  final ActivitySummary activitySummary;
  final int refreshToken;
  final int morningBriefRevision;
  final bool useLargeLayout;
  final VoidCallback? onWaterTap;

  @override
  State<_DashboardOperationOverview> createState() =>
      _DashboardOperationOverviewState();
}

class _DashboardOperationOverviewState
    extends State<_DashboardOperationOverview> {
  late Future<DailyCommandReadModel> _model = _load();

  @override
  void didUpdateWidget(covariant _DashboardOperationOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.morningFact != widget.morningFact ||
        oldWidget.foodSummary != widget.foodSummary ||
        oldWidget.trainingSummary != widget.trainingSummary ||
        oldWidget.activitySummary != widget.activitySummary ||
        oldWidget.refreshToken != widget.refreshToken ||
        oldWidget.morningBriefRevision != widget.morningBriefRevision) {
      _model = _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<DailyCommandReadModel>(
    future: _model,
    builder: (context, snapshot) {
      final model = snapshot.data;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            icon: Icons.dashboard_outlined,
            title: 'DAILY COMMAND',
          ),
          AppSpacing.gapSM,
          if (snapshot.connectionState != ConnectionState.done)
            const OperationCard(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (snapshot.hasError || model == null)
            const OperationCard(child: Text('Current Operationを読み込めませんでした。'))
          else
            _DailyCommandSummaryCard(model: model),
          AppSpacing.gapXL,
          const SectionHeader(
            icon: Icons.timeline_outlined,
            title: 'OPERATION PROGRESS',
          ),
          AppSpacing.gapSM,
          _ProgressCard(
            morningFact: widget.morningFact,
            estimatedTDEE: widget.estimatedTDEE,
            foodSummary: widget.foodSummary,
            trainingSummary: widget.trainingSummary,
            activitySummary: widget.activitySummary,
            refreshToken: widget.refreshToken,
            useLargeLayout: widget.useLargeLayout,
            onWaterTap: widget.onWaterTap,
            completionModel: model,
          ),
        ],
      );
    },
  );

  Future<DailyCommandReadModel> _load() async {
    final state = await AppRepositoryRegistry.container.operationState
        .requireCurrent();
    final morningBrief = await AppRepositoryRegistry.container.morningBriefs
        .readByLocalDate(state.operationDate.value);
    final burnWeight = await TrainingStatusWeightResolver(
      repository: AppRepositoryRegistry.container.status,
    ).resolve(state.operationDate.value);
    var dailyDebriefFinalizeReady = false;
    if (state.phase == OperationPhase.awaitingDebrief) {
      final debrief = await AppRepositoryRegistry.container.dailyDebriefs
          .readByLocalDate(state.operationDate.value);
      if (debrief != null &&
          await AppRepositoryRegistry.container.dailyDebriefSources
                  .projectLifecycle(debrief) ==
              DailyDebriefLifecycleStatus.active) {
        try {
          await DailyFinalizeCoordinatorFactory.production()
              .validateCurrentSourceSnapshot(state);
          dailyDebriefFinalizeReady = true;
        } catch (_) {}
      }
    }
    return DailyCommandReadModelBuilder.build(
      operationState: state,
      status: widget.morningFact,
      food: widget.foodSummary,
      training: widget.trainingSummary,
      activity: widget.activitySummary,
      morningBrief: morningBrief,
      burnWeightKg: burnWeight,
      dailyDebriefFinalizeReady: dailyDebriefFinalizeReady,
    );
  }
}

class _DailyCommandSummaryCard extends StatelessWidget {
  const _DailyCommandSummaryCard({required this.model});

  final DailyCommandReadModel model;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: DailyCommandItem(
                icon: model.operationStatus == null
                    ? Icons.cancel_outlined
                    : Icons.check_circle_outline,
                label: 'OPERATION STATUS',
                value: model.operationStatus?.name.toUpperCase() ?? 'STANDBY',
                status: model.operationStatus,
                showStatusLamp: true,
                valueKey: const ValueKey('daily-command-status-value'),
                onValueTap: () => _showStatusReasonPreview(context, model),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 5,
              child: _DailyCommandCycleState(cycleState: model.cycleState),
            ),
          ],
        ),
        AppSpacing.gapMD,
        _DailyCommandAmbientMonitor(status: model.operationStatus),
        AppSpacing.gapMD,
        DailyCommandItem(
          icon: Icons.flag_outlined,
          label: 'COMMANDER INTENT',
          value: model.commanderIntent ?? '—',
        ),
      ],
    ),
  );
}

Future<void> _showStatusReasonPreview(
  BuildContext context,
  DailyCommandReadModel model,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    content: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 360,
        maxHeight: MediaQuery.sizeOf(context).height * .45,
      ),
      child: SingleChildScrollView(
        child: _DailyCommandStatusReasonPreview(model: model),
      ),
    ),
  ),
);

class _DailyCommandStatusReasonPreview extends StatelessWidget {
  const _DailyCommandStatusReasonPreview({required this.model});

  final DailyCommandReadModel model;

  @override
  Widget build(BuildContext context) {
    final status = model.operationStatus;
    final title = status?.name.toUpperCase() ?? 'STANDBY';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('OPERATION STATUS', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Icon(
              Symbols.circle,
              fill: status == null ? 0 : 1,
              size: 18,
              color: DailyCommandItem.statusColor(status),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text('判定理由', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          status == null
              ? 'DAILY BRIEF未作成\n判定理由はまだありません'
              : model.statusReasonSummary,
          key: const ValueKey('daily-command-status-reason-preview'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _DailyCommandCycleState extends StatelessWidget {
  _DailyCommandCycleState({required this.cycleState})
    : _visibleAnchorKey = GlobalKey();

  final DailyCommandCycleState cycleState;
  final GlobalKey _visibleAnchorKey;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.page_info,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text('CYCLE STATE', style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
      AppSpacing.gapXS,
      SemanticHelpPopover(
        id: 'cycle-${cycleState.name}',
        title: cycleStateShortLabelFor(cycleState),
        description: cycleStateHelp(cycleState),
        constraints: const BoxConstraints(minWidth: 240, maxWidth: 280),
        visibleAnchorKey: _visibleAnchorKey,
        child: Semantics(
          button: true,
          label: 'CYCLE STATE ${cycleStateShortLabelFor(cycleState)}',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              KeyedSubtree(
                key: _visibleAnchorKey,
                child: Icon(
                  cycleStateIconFor(cycleState),
                  key: const ValueKey('dashboard-cycle-state-visible-icon'),
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(cycleStateShortLabelFor(cycleState)),
            ],
          ),
        ),
      ),
    ],
  );
}

class _DailyCommandAmbientMonitor extends StatelessWidget {
  const _DailyCommandAmbientMonitor({required this.status});

  static const _borderWidth = 1.0;
  static const _radius = 6.0;

  final OperationStatus? status;

  @override
  Widget build(BuildContext context) {
    final color = _monitorColorFor(status);
    return Container(
      key: const ValueKey('daily-command-ambient-monitor'),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: .28),
        border: Border.all(
          color: color.withValues(alpha: .56),
          width: _borderWidth,
        ),
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: SizedBox(
        height:
            OperationAmbientAnimation.height +
            DailyCommandAmbientHudGeometry.verticalPadding * 2,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                key: const ValueKey('daily-command-ambient-monitor-grid'),
                painter: _DailyCommandAmbientGridPainter(color),
              ),
            ),
            Positioned(
              left: DailyCommandAmbientHudGeometry.horizontalPadding,
              right: DailyCommandAmbientHudGeometry.horizontalPadding,
              top: DailyCommandAmbientHudGeometry.verticalPadding,
              height: OperationAmbientAnimation.height,
              child: OperationAmbientAnimation(status: status),
            ),
            Positioned(
              key: const ValueKey('daily-command-ambient-monitor-identifier'),
              right:
                  DailyCommandAmbientHudGeometry.horizontalPadding +
                  DailyCommandAmbientHudGeometry.rightHudRightInset,
              top:
                  DailyCommandAmbientHudGeometry.verticalPadding +
                  DailyCommandAmbientHudGeometry.identifierTop,
              child: Text(
                'O.R.L.O.',
                style: AppTextStyles.bootTechnical.copyWith(
                  color: color.withValues(
                    alpha: DailyCommandAmbientHudGeometry.identifierOpacity,
                  ),
                  fontSize: DailyCommandAmbientHudGeometry.identifierFontSize,
                  height: 1,
                  letterSpacing: .15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _monitorColorFor(OperationStatus? status) => switch (status) {
  OperationStatus.green => AppColors.success,
  OperationStatus.yellow => AppColors.warning,
  OperationStatus.red => AppColors.danger,
  OperationStatus.black || null => AppColors.information,
};

class _DailyCommandAmbientGridPainter extends CustomPainter {
  const _DailyCommandAmbientGridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = color.withValues(alpha: .10)
      ..strokeWidth = 1;
    const verticalSpacing = 24.0;
    const horizontalSpacing = 10.0;
    final lane = DailyCommandAmbientHudGeometry.laneBoundsFor(size);
    for (var x = lane.left; x <= lane.right; x += verticalSpacing) {
      canvas.drawLine(Offset(x, lane.top), Offset(x, lane.bottom), gridPaint);
    }
    for (var y = lane.top; y <= lane.bottom; y += horizontalSpacing) {
      canvas.drawLine(Offset(lane.left, y), Offset(lane.right, y), gridPaint);
    }

    final bracketPaint = Paint()
      ..color = color.withValues(
        alpha: DailyCommandAmbientHudGeometry.bracketOpacity,
      )
      ..strokeWidth = DailyCommandAmbientHudGeometry.cornerStrokeWidth
      ..strokeCap = StrokeCap.square;
    _drawCornerBrackets(canvas, size, bracketPaint);

    final bars = DailyCommandAmbientHudGeometry.barWidths;
    for (var index = 0; index < bars.length; index++) {
      final width = bars[index];
      final top =
          DailyCommandAmbientHudGeometry.verticalPadding +
          DailyCommandAmbientHudGeometry.rightBarsTop +
          index *
              (DailyCommandAmbientHudGeometry.rightBarHeight +
                  DailyCommandAmbientHudGeometry.rightBarGap);
      final paint = Paint()
        ..color = color.withValues(
          alpha: index == 1
              ? DailyCommandAmbientHudGeometry.primaryBarOpacity
              : DailyCommandAmbientHudGeometry.secondaryBarOpacity,
        )
        ..strokeWidth = DailyCommandAmbientHudGeometry.rightBarHeight;
      final right =
          size.width -
          DailyCommandAmbientHudGeometry.horizontalPadding -
          DailyCommandAmbientHudGeometry.rightHudRightInset;
      canvas.drawLine(Offset(right - width, top), Offset(right, top), paint);
    }
  }

  void _drawCornerBrackets(Canvas canvas, Size size, Paint paint) {
    final left = DailyCommandAmbientHudGeometry.cornerInset;
    final right = size.width - DailyCommandAmbientHudGeometry.cornerInset;
    final top = DailyCommandAmbientHudGeometry.cornerInset;
    final bottom = size.height - DailyCommandAmbientHudGeometry.cornerInset;
    final arm = DailyCommandAmbientHudGeometry.cornerArmLength;
    canvas
      ..drawLine(Offset(left, top + arm), Offset(left, top), paint)
      ..drawLine(Offset(left, top), Offset(left + arm, top), paint)
      ..drawLine(Offset(right - arm, top), Offset(right, top), paint)
      ..drawLine(Offset(right, top), Offset(right, top + arm), paint)
      ..drawLine(Offset(left, bottom - arm), Offset(left, bottom), paint)
      ..drawLine(Offset(left, bottom), Offset(left + arm, bottom), paint)
      ..drawLine(Offset(right - arm, bottom), Offset(right, bottom), paint)
      ..drawLine(Offset(right, bottom - arm), Offset(right, bottom), paint);
  }

  @override
  bool shouldRepaint(covariant _DailyCommandAmbientGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

class DailyCommandAmbientHudGeometry {
  const DailyCommandAmbientHudGeometry._();

  static const horizontalPadding = 6.0;
  static const verticalPadding = 3.0;
  static const cornerArmLength = 4.0;
  static const cornerInset = 3.5;
  static const cornerStrokeWidth = 1.0;
  static const bracketOpacity = .58;
  static const identifierFontSize = 6.0;
  static const identifierOpacity = .58;
  static const identifierTop = 3.0;
  static const rightHudRightInset = 8.0;
  static const rightBarsTop = 16.0;
  static const rightBarHeight = 1.0;
  static const rightBarGap = 2.0;
  static const primaryBarOpacity = .46;
  static const secondaryBarOpacity = .28;
  static const barWidths = <double>[7, 10, 5];

  static Rect laneBoundsFor(Size size) => Rect.fromLTWH(
    horizontalPadding,
    verticalPadding,
    size.width - horizontalPadding * 2,
    OperationAmbientAnimation.height,
  );

  static List<Rect> cornerBoundsFor(Size size) {
    final halfStroke = cornerStrokeWidth / 2;
    final left = cornerInset - halfStroke;
    final right = size.width - cornerInset + halfStroke;
    final top = cornerInset - halfStroke;
    final bottom = size.height - cornerInset + halfStroke;
    final arm = cornerArmLength + cornerStrokeWidth;
    return [
      Rect.fromLTRB(left, top, left + arm, top + arm),
      Rect.fromLTRB(right - arm, top, right, top + arm),
      Rect.fromLTRB(left, bottom - arm, left + arm, bottom),
      Rect.fromLTRB(right - arm, bottom - arm, right, bottom),
    ];
  }

  static Rect barsBoundsFor(Size size) {
    final right =
        size.width -
        horizontalPadding -
        rightHudRightInset +
        rightBarHeight / 2;
    final lastBarTop =
        verticalPadding +
        rightBarsTop +
        (barWidths.length - 1) * (rightBarHeight + rightBarGap);
    return Rect.fromLTRB(
      right - barWidths.reduce((a, b) => a > b ? a : b),
      verticalPadding + rightBarsTop - rightBarHeight / 2,
      right,
      lastBarTop + rightBarHeight / 2,
    );
  }
}

class _ProgressCard extends StatefulWidget {
  final MorningFact? morningFact;
  final double? estimatedTDEE;
  final FoodSummary? foodSummary;
  final TrainingSummary? trainingSummary;
  final ActivitySummary activitySummary;
  final int refreshToken;
  final bool useLargeLayout;
  final VoidCallback? onWaterTap;
  final DailyCommandReadModel? completionModel;

  const _ProgressCard({
    required this.morningFact,
    required this.estimatedTDEE,
    required this.foodSummary,
    required this.trainingSummary,
    required this.activitySummary,
    required this.refreshToken,
    required this.useLargeLayout,
    required this.onWaterTap,
    required this.completionModel,
  });

  @override
  State<_ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends State<_ProgressCard> {
  late Future<DynamicDailyTargetResult> _targets = _loadDynamicTargets();

  @override
  void didUpdateWidget(covariant _ProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.morningFact != widget.morningFact ||
        oldWidget.foodSummary != widget.foodSummary ||
        oldWidget.trainingSummary != widget.trainingSummary ||
        oldWidget.activitySummary != widget.activitySummary ||
        oldWidget.refreshToken != widget.refreshToken) {
      _targets = _loadDynamicTargets();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mealCount = widget.foodSummary?.mealCount ?? 0;
    final calories = widget.foodSummary?.calories ?? 0;
    final protein = widget.foodSummary?.protein ?? 0;
    final hydrationMl = widget.foodSummary?.hydrationMl ?? 0;
    final digestiveSummary = widget.activitySummary.digestiveSummary;
    final activityDetails = !widget.activitySummary.isRecorded
        ? const <String>[]
        : digestiveSummary?.hasExplicitNoMovement == true
        ? const ['Digestive None']
        : (digestiveSummary?.eventCount ?? 0) > 0
        ? [
            'Digestive Count ${digestiveSummary!.eventCount}',
            'Total Amount ${digestiveSummary.totalAmount}',
          ]
        : const <String>[];

    final energyStatus =
        widget.trainingSummary?.totalEnergyCalculationStatus ??
        TrainingEnergyCalculationStatus.complete;
    final exerciseCalories =
        widget.trainingSummary?.trainingEstimatedCaloriesKcal ?? 0;
    return FutureBuilder<DynamicDailyTargetResult>(
      future: _targets,
      builder: (context, snapshot) {
        final targets = snapshot.data;
        final estimatedTotalBurn =
            targets?.estimatedTotalBurnKcal ??
            _estimatedTotalBurn(widget.estimatedTDEE, widget.trainingSummary);
        return OperationCard(
          child: widget.useLargeLayout
              ? Row(
                  key: const ValueKey('operation-progress-large-layout'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildSummary(
                        context,
                        estimatedBaseBurn:
                            targets?.estimatedBaseBurnKcal ??
                            widget.estimatedTDEE,
                        exerciseCalories: exerciseCalories,
                        energyStatus: energyStatus,
                        estimatedTotalBurn: estimatedTotalBurn,
                        large: true,
                      ),
                    ),
                    SizedBox(width: AppSpacing.xl),
                    Expanded(
                      flex: 3,
                      child: _buildProgressTiles(
                        mealCount: mealCount,
                        calories: calories,
                        protein: protein,
                        hydrationMl: hydrationMl,
                        activityDetails: activityDetails,
                        targets: targets,
                        completionModel: widget.completionModel,
                        forceTwoColumns: true,
                      ),
                    ),
                  ],
                )
              : Column(
                  key: const ValueKey('operation-progress-compact-layout'),
                  children: [
                    _buildSummary(
                      context,
                      estimatedBaseBurn:
                          targets?.estimatedBaseBurnKcal ??
                          widget.estimatedTDEE,
                      exerciseCalories: exerciseCalories,
                      energyStatus: energyStatus,
                      estimatedTotalBurn: estimatedTotalBurn,
                      large: false,
                    ),
                    AppSpacing.gapLG,
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: _buildProgressTiles(
                          mealCount: mealCount,
                          calories: calories,
                          protein: protein,
                          hydrationMl: hydrationMl,
                          activityDetails: activityDetails,
                          targets: targets,
                          completionModel: widget.completionModel,
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future<DynamicDailyTargetResult> _loadDynamicTargets() async {
    final operationDate = await const OperationDateService().current();
    final repositories = AppRepositoryRegistry.container;
    return DynamicDailyTargetService(
      statusRepository: repositories.status,
      trainingRepository: repositories.training,
    ).loadForOperationDate(
      operationDate: operationDate.value,
      food: widget.foodSummary,
      activity: widget.activitySummary,
      training: widget.trainingSummary,
    );
  }

  Widget _buildSummary(
    BuildContext context, {
    required double? estimatedBaseBurn,
    required double exerciseCalories,
    required TrainingEnergyCalculationStatus energyStatus,
    required double? estimatedTotalBurn,
    required bool large,
  }) {
    final metrics = [
      _ProgressSummaryMetric(
        label: 'WEIGHT',
        value: widget.morningFact == null
            ? '--'
            : widget.morningFact!.weight == null
            ? '未計測'
            : '${widget.morningFact!.weight!.toStringAsFixed(1)} kg',
        labelFirst: true,
      ),
      _ProgressSummaryMetric(
        label: 'SLEEP',
        value: widget.morningFact == null
            ? '--'
            : widget.morningFact!.sleepDuration == null
            ? '未計測'
            : _formatSleep(widget.morningFact!.sleepDuration!),
        labelFirst: true,
      ),
      _ProgressSummaryMetric(
        label: 'BASE BURN',
        value: estimatedBaseBurn == null
            ? '--'
            : '${estimatedBaseBurn.toStringAsFixed(0)} kcal',
        labelFirst: true,
      ),
      _ProgressSummaryMetric(
        label: 'EXERCISE',
        value: switch (energyStatus) {
          TrainingEnergyCalculationStatus.complete =>
            '${exerciseCalories.toStringAsFixed(0)} kcal',
          TrainingEnergyCalculationStatus.partial =>
            '${exerciseCalories.toStringAsFixed(0)} kcal\nPartial',
          TrainingEnergyCalculationStatus.notCalculated => 'Not calculated',
        },
        labelFirst: true,
      ),
      _ProgressSummaryMetric(
        label: 'EST. TOTAL BURN',
        value: estimatedTotalBurn == null
            ? 'Not calculated'
            : energyStatus == TrainingEnergyCalculationStatus.partial
            ? '${estimatedTotalBurn.toStringAsFixed(0)} kcal\nPartial'
            : '${estimatedTotalBurn.toStringAsFixed(0)} kcal',
        labelFirst: true,
      ),
    ];

    if (large) {
      return Column(
        key: const ValueKey('operation-summary'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OPERATION SUMMARY',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          AppSpacing.gapMD,
          for (var index = 0; index < metrics.length; index++) ...[
            metrics[index],
            if (index != metrics.length - 1) AppSpacing.gapMD,
          ],
        ],
      );
    }

    return Column(
      key: const ValueKey('operation-summary'),
      children: [
        Row(
          children: [
            for (final metric in metrics.take(3)) Expanded(child: metric),
          ],
        ),
        AppSpacing.gapMD,
        Row(
          children: [
            for (final metric in metrics.skip(3)) Expanded(child: metric),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressTiles({
    required int mealCount,
    required double calories,
    required double protein,
    required double hydrationMl,
    required List<String> activityDetails,
    required DynamicDailyTargetResult? targets,
    required DailyCommandReadModel? completionModel,
    bool forceTwoColumns = false,
  }) {
    final foodSummaryAvailable = widget.foodSummary != null && mealCount > 0;
    return LayoutBuilder(
      key: const ValueKey('operation-progress-tiles'),
      builder: (context, constraints) {
        final useTwoColumns = forceTwoColumns || constraints.maxWidth >= 280;
        final tileWidth = useTwoColumns
            ? (constraints.maxWidth - AppSpacing.md) / 2
            : constraints.maxWidth;

        Widget tile({
          required String label,
          required String status,
          required double progress,
          VoidCallback? onTap,
          bool fullWidth = false,
          List<String> details = const [],
          DynamicTargetState? targetState,
          DailyCommandCompletionItem? completion,
        }) {
          return SizedBox(
            key: ValueKey('operation-progress-$label'),
            width: fullWidth ? constraints.maxWidth : tileWidth,
            child: _ProgressRow(
              label: label,
              status: status,
              progress: progress,
              onTap: onTap,
              details: details,
              targetState: targetState,
              completion: completion,
            ),
          );
        }

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            tile(
              label: 'STATUS',
              status:
                  completionModel?.statusCompletion.displayState ??
                  (widget.morningFact == null ? '未完了' : '完了'),
              progress:
                  completionModel?.statusCompletion.isComplete == true ||
                      (completionModel == null && widget.morningFact != null)
                  ? 1.0
                  : 0.0,
              completion: completionModel?.statusCompletion,
              onTap: () => Navigator.pushNamed(context, AppRoutes.morning),
            ),
            tile(
              label: 'FOOD',
              status:
                  completionModel?.foodCompletion.displayState ??
                  '$mealCount / 3',
              progress: completionModel?.foodCompletion.isComplete == true
                  ? 1.0
                  : completionModel == null
                  ? (mealCount / 3).clamp(0.0, 1.0).toDouble()
                  : 0.0,
              completion: completionModel?.foodCompletion,
              onTap: () => Navigator.pushNamed(context, AppRoutes.food),
            ),
            tile(
              label: 'CALORIES',
              status: _rangeStatus(
                targets?.calories,
                unit: 'kcal',
                displayTarget:
                    DynamicDailyTargetPresentation.caloriesTargetKcal(
                      targets?.calories,
                    ),
                formatCurrent: _formatIntegerValue,
                fallbackCurrent: foodSummaryAvailable ? calories : null,
              ),
              progress: _rangeProgress(targets?.calories),
              targetState: targets?.calories.state,
            ),
            tile(
              label: 'PROTEIN',
              status: _rangeStatus(
                targets?.protein,
                unit: 'g',
                displayTarget: DynamicDailyTargetPresentation.proteinTargetG(
                  targets?.protein,
                ),
                formatCurrent: _formatProtein,
                fallbackCurrent: foodSummaryAvailable ? protein : null,
              ),
              progress: _rangeProgress(targets?.protein),
              targetState: targets?.protein.state,
            ),
            tile(
              label: 'WATER',
              status: _waterStatus(
                targets?.water,
                fallbackCurrent: widget.foodSummary?.waterRecorded == true
                    ? hydrationMl
                    : null,
              ),
              progress: _waterProgress(targets?.water),
              targetState: targets?.water.state,
              onTap: widget.onWaterTap,
            ),
            tile(
              label: 'TRAINING',
              status: widget.trainingSummary?.completed == true
                  ? 'Recorded'
                  : 'Not recorded',
              progress: widget.trainingSummary?.completed == true ? 1.0 : 0.0,
              completion:
                  completionModel?.trainingCompletion ??
                  DailyCommandCompletionItem(
                    label: 'TRAINING',
                    state: widget.trainingSummary?.completed == true
                        ? DailyCommandModuleState.recorded
                        : DailyCommandModuleState.optionalMissing,
                    missingRequirements: const [],
                  ),
              onTap: () => Navigator.pushNamed(context, AppRoutes.training),
            ),
            tile(
              label: 'ACTIVITY',
              status:
                  completionModel?.activityCompletion.displayState ??
                  (widget.activitySummary.isRecorded
                      ? '${_formatInteger(widget.activitySummary.steps)} steps'
                      : 'Not recorded'),
              progress: completionModel?.activityCompletion.isComplete == true
                  ? 1.0
                  : completionModel == null && widget.activitySummary.isRecorded
                  ? 1.0
                  : 0.0,
              fullWidth: true,
              details: activityDetails,
              completion: completionModel?.activityCompletion,
              onTap: () => Navigator.pushNamed(context, AppRoutes.activity),
            ),
          ],
        );
      },
    );
  }

  String _formatSleep(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    return '${duration.inHours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  String _formatInteger(int value) => value.toString().replaceAllMapped(
    RegExp(r'(?<!^)(?=(\d{3})+$)'),
    (_) => ',',
  );

  String _rangeStatus(
    DynamicRangeTarget? target, {
    required String unit,
    required int? displayTarget,
    required String Function(double) formatCurrent,
    required double? fallbackCurrent,
  }) {
    final current = target?.current ?? fallbackCurrent ?? 0;
    final targetLabel = displayTarget == null
        ? '--'
        : _formatInteger(displayTarget);
    return '${formatCurrent(current)} / $targetLabel $unit';
  }

  double _rangeProgress(DynamicRangeTarget? target) {
    final current = target?.current;
    final low = target?.low;
    if (current == null || low == null || low <= 0) return 0;
    return (current / low).clamp(0.0, 1.0).toDouble();
  }

  String _waterStatus(
    DynamicWaterTarget? target, {
    required double? fallbackCurrent,
  }) {
    final current = target?.current ?? fallbackCurrent ?? 0;
    final displayTarget = DynamicDailyTargetPresentation.waterTargetMl(target);
    final targetLabel = displayTarget == null
        ? '--'
        : _formatInteger(displayTarget);
    return '${_formatIntegerValue(current)} / $targetLabel ml';
  }

  String _formatIntegerValue(double value) => _formatInteger(value.round());

  String _formatProtein(double value) => value == value.roundToDouble()
      ? _formatInteger(value.round())
      : value.toStringAsFixed(1);

  double _waterProgress(DynamicWaterTarget? target) {
    final current = target?.current;
    final goal = target?.finalTargetMl;
    if (current == null || goal == null || goal <= 0) return 0;
    return (current / goal).clamp(0.0, 1.0).toDouble();
  }
}

double? _estimatedTotalBurn(
  double? baseBurn,
  TrainingSummary? trainingSummary,
) {
  if (baseBurn == null) return null;
  final status =
      trainingSummary?.totalEnergyCalculationStatus ??
      TrainingEnergyCalculationStatus.complete;
  if (status == TrainingEnergyCalculationStatus.notCalculated) return null;
  return baseBurn + (trainingSummary?.trainingEstimatedCaloriesKcal ?? 0);
}

class _ProgressSummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool labelFirst;

  const _ProgressSummaryMetric({
    required this.label,
    required this.value,
    this.labelFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: labelFirst
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (labelFirst)
          Text(label, style: Theme.of(context).textTheme.labelSmall)
        else
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        AppSpacing.gapXS,
        if (labelFirst)
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          )
        else
          Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

/// Shared horizontal geometry for status-bearing OPERATION PROGRESS cards.
abstract final class _ProgressStatusAnchorGeometry {
  static const statusZoneWidth = 48.0;
  static const statusZoneRightPadding = AppSpacing.sm;
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final String status;
  final double progress;
  final VoidCallback? onTap;
  final List<String> details;
  final DynamicTargetState? targetState;
  final DailyCommandCompletionItem? completion;

  const _ProgressRow({
    required this.label,
    required this.status,
    required this.progress,
    this.onTap,
    this.details = const [],
    this.targetState,
    this.completion,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final completed = targetState == null
        ? progress >= 1
        : targetState == DynamicTargetState.green ||
              targetState == DynamicTargetState.greenHigh;
    final semanticColor = switch (targetState) {
      DynamicTargetState.green ||
      DynamicTargetState.greenHigh => AppColors.success,
      DynamicTargetState.yellowLow ||
      DynamicTargetState.yellowHigh => AppColors.warning,
      DynamicTargetState.redLow ||
      DynamicTargetState.redHigh => AppColors.danger,
      DynamicTargetState.neutral => colorScheme.outline,
      _ => null,
    };
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          key: ValueKey('operation-progress-title-$label'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        AppSpacing.gapXS,
        Row(
          children: [
            Expanded(child: Text(status)),
            if (completion == null && onTap != null) ...[
              SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.add_circle_outline,
                size: 18,
                color: colorScheme.primary,
              ),
            ],
          ],
        ),
        if (details.isNotEmpty) ...[
          AppSpacing.gapSM,
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [for (final detail in details) Text(detail)],
          ),
        ],
        AppSpacing.gapXS,
        LinearProgressIndicator(
          value: progress,
          color: semanticColor ?? (completed ? AppColors.success : null),
        ),
      ],
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(
        color: completed
            ? semanticColor ?? AppColors.success
            : semanticColor ??
                  colorScheme.outlineVariant.withValues(alpha: 0.6),
      ),
    );
    final color = completed
        ? (semanticColor ?? AppColors.success).withValues(alpha: 0.12)
        : Colors.transparent;
    if (completion != null) {
      return Material(
        color: color,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: 'Open $label',
                child: InkWell(
                  key: ValueKey('operation-progress-body-$label'),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.md,
                    ),
                    child: content,
                  ),
                ),
              ),
            ),
            SizedBox(
              key: ValueKey('operation-progress-status-zone-$label'),
              width: _ProgressStatusAnchorGeometry.statusZoneWidth,
              child: _CompletionHelpButton(completion: completion!),
            ),
          ],
        ),
      );
    }

    return Material(
      color: color,
      shape: shape,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: content,
        ),
      ),
    );
  }
}

class _CompletionHelpButton extends StatelessWidget {
  _CompletionHelpButton({required this.completion})
    : _visibleAnchorKey = GlobalKey();

  final DailyCommandCompletionItem completion;
  final GlobalKey _visibleAnchorKey;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (completion.state) {
      DailyCommandModuleState.recorded => (
        Icons.check_circle_outline,
        colorScheme.primary,
      ),
      DailyCommandModuleState.missing || DailyCommandModuleState.invalid => (
        Icons.error_outline,
        colorScheme.error,
      ),
      DailyCommandModuleState.optionalMissing => (
        Icons.radio_button_unchecked,
        colorScheme.onSurfaceVariant,
      ),
    };
    return SemanticHelpPopover(
      id: 'completion-${completion.label.toLowerCase()}',
      title: completion.label,
      description: completion.displayState,
      secondary: completion.missingRequirements.isEmpty
          ? null
          : 'Missing: ${completion.missingRequirements.join(', ')}',
      descriptionColor: switch (completion.state) {
        DailyCommandModuleState.recorded => colorScheme.primary,
        DailyCommandModuleState.missing ||
        DailyCommandModuleState.invalid => colorScheme.error,
        DailyCommandModuleState.optionalMissing => colorScheme.onSurfaceVariant,
      },
      offset: const Offset(0, 4),
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 300),
      visibleAnchorKey: _visibleAnchorKey,
      child: Semantics(
        button: true,
        label:
            '${completion.label} status: ${completion.displayState.toLowerCase()}',
        child: SizedBox(
          key: ValueKey('operation-progress-info-${completion.label}'),
          width: _ProgressStatusAnchorGeometry.statusZoneWidth,
          height: _ProgressStatusAnchorGeometry.statusZoneWidth,
          child: Padding(
            padding: const EdgeInsets.only(
              right: _ProgressStatusAnchorGeometry.statusZoneRightPadding,
            ),
            child: Center(
              child: KeyedSubtree(
                key: _visibleAnchorKey,
                child: Icon(
                  icon,
                  key: ValueKey(
                    completion.label == 'TRAINING'
                        ? (completion.state == DailyCommandModuleState.recorded
                              ? 'operation-progress-training-recorded'
                              : 'operation-progress-training-optional')
                        : 'operation-progress-completion-${completion.label}',
                  ),
                  color: color,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickWaterSheet extends StatefulWidget {
  final BuildContext dashboardContext;

  const _QuickWaterSheet({required this.dashboardContext});

  @override
  State<_QuickWaterSheet> createState() => _QuickWaterSheetState();
}

class _QuickWaterSheetState extends State<_QuickWaterSheet> {
  final _customAmountController = TextEditingController();
  bool _isSaving = false;
  int _recordSequence = 0;
  String? _validationMessage;

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  void _addDraftAmount(int amountMl) {
    final input = _customAmountController.text.trim();
    final currentAmount = input.isEmpty ? 0 : int.tryParse(input);
    if (currentAmount == null || currentAmount < 0) return;

    final nextAmount = currentAmount + amountMl;
    final nextText = nextAmount.toString();
    _customAmountController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
    if (_validationMessage != null) {
      setState(() => _validationMessage = null);
    }
  }

  Future<void> _saveCustomAmount() async {
    if (_isSaving) return;

    final amountMl = int.tryParse(_customAmountController.text.trim());

    if (amountMl == null || amountMl <= 0) {
      setState(() => _validationMessage = '正の整数の ml を入力してください。');
      return;
    }

    setState(() {
      _isSaving = true;
      _validationMessage = null;
    });

    try {
      final operationDate = await const OperationDateService().current();
      await FoodSubmitService.save(
        MealData(
          id: '${DateTime.now().microsecondsSinceEpoch}-${_recordSequence++}',
          date: operationDate.value,
          mealType: 'Water',
          items: const [],
          memo: '',
          waterMl: amountMl.toDouble(),
        ),
        operationLocalDate: operationDate.value,
      );

      if (!mounted || !widget.dashboardContext.mounted) return;

      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        widget.dashboardContext,
      ).showSnackBar(SnackBar(content: Text('Water +$amountMl ml recorded')));
    } on ConfirmedDailyLogException catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showConfirmedLogMessage(context, error);
    } catch (_) {
      if (!mounted) return;

      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Water を記録できませんでした')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: OperationCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.water_drop_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    'QUICK WATER LOG',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              AppSpacing.gapMD,
              ValueListenableBuilder<FoodSummary?>(
                valueListenable: foodSummaryNotifier,
                builder: (context, summary, _) => Text(
                  'CURRENT WATER  ${(summary?.hydrationMl ?? 0).toStringAsFixed(0)} ml',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              AppSpacing.gapMD,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: WaterQuickPresets.valuesMl
                    .map(
                      (amount) => OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => _addDraftAmount(amount),
                        child: Text('+$amount ml'),
                      ),
                    )
                    .toList(),
              ),
              AppSpacing.gapLG,
              OperationTextField(
                controller: _customAmountController,
                label: 'Amount (ml)',
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  if (_validationMessage != null) {
                    setState(() => _validationMessage = null);
                  }
                },
              ),
              if (_validationMessage != null) ...[
                AppSpacing.gapXS,
                Text(
                  _validationMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              AppSpacing.gapMD,
              OperationButton(
                icon: Icons.save_outlined,
                text: 'Save Water',
                onPressed: _isSaving ? null : _saveCustomAmount,
              ),
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MorningButton extends StatelessWidget {
  const _MorningButton();

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      role: OperationActionRole.primary,
      icon: Icons.play_arrow,
      text: 'STATUS',
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.morning);
      },
    );
  }
}

class _FoodButton extends StatelessWidget {
  const _FoodButton();

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      role: OperationActionRole.primary,
      icon: Icons.restaurant,
      text: 'FOOD',
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.food);
      },
    );
  }
}

class _ActivityButton extends StatelessWidget {
  const _ActivityButton();

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      role: OperationActionRole.primary,
      icon: Icons.directions_walk_outlined,
      text: 'ACTIVITY',
      onPressed: () => Navigator.pushNamed(context, AppRoutes.activity),
    );
  }
}

class _TrainingButton extends StatelessWidget {
  const _TrainingButton();

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      role: OperationActionRole.primary,
      icon: Icons.fitness_center,
      text: 'TRAINING',
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.training);
      },
    );
  }
}

class _CommandCenterButton extends StatelessWidget {
  const _CommandCenterButton();

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      role: OperationActionRole.primary,
      icon: Icons.flag,
      text: 'COMMAND CENTER',
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.commandCenter);
      },
    );
  }
}

/// Isolated AppBar-title renderer for the O.R.L.O. neon sign.  It remains
/// idle while lit normally; timers exist only to schedule and play rare fault
/// events, so the Dashboard itself is never rebuilt for the effect.
class _DashboardNeonBrandMark extends StatefulWidget {
  const _DashboardNeonBrandMark();

  @override
  State<_DashboardNeonBrandMark> createState() =>
      _DashboardNeonBrandMarkState();
}

class _DashboardNeonBrandMarkState extends State<_DashboardNeonBrandMark>
    with WidgetsBindingObserver {
  final math.Random _random = math.Random();
  Timer? _nextFaultTimer;
  Timer? _phaseTimer;
  DashboardNeonFaultPhase _phase = DashboardNeonFaultPatterns.stable;
  bool _reducedMotion = false;
  bool _appActive = true;
  bool _tickerEnabled = true;
  var _dependenciesReady = false;

  bool get _motionAllowed => !_reducedMotion && _appActive && _tickerEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (_dependenciesReady &&
        _reducedMotion == reducedMotion &&
        _tickerEnabled == tickerEnabled) {
      return;
    }
    _dependenciesReady = true;
    _reducedMotion = reducedMotion;
    _tickerEnabled = tickerEnabled;
    _resetAndSchedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _resetAndSchedule();
  }

  void _resetAndSchedule() {
    _nextFaultTimer?.cancel();
    _phaseTimer?.cancel();
    if (mounted && _phase != DashboardNeonFaultPatterns.stable) {
      setState(() => _phase = DashboardNeonFaultPatterns.stable);
    } else {
      _phase = DashboardNeonFaultPatterns.stable;
    }
    if (_motionAllowed) _scheduleNextFault();
  }

  void _scheduleNextFault() {
    _nextFaultTimer?.cancel();
    if (!mounted || !_motionAllowed) return;
    _nextFaultTimer = Timer(
      DashboardNeonFaultPatterns.intervalFor(_random),
      _startFault,
    );
  }

  void _startFault() {
    if (!mounted || !_motionAllowed) return;
    _playPhase(DashboardNeonFaultPatterns.choose(_random).phases, 1);
  }

  void _playPhase(List<DashboardNeonFaultPhase> plan, int index) {
    if (!mounted || !_motionAllowed) return;
    if (index >= plan.length) {
      setState(() => _phase = DashboardNeonFaultPatterns.stable);
      _scheduleNextFault();
      return;
    }
    setState(() => _phase = plan[index]);
    _phaseTimer = Timer(plan[index].duration, () {
      _playPhase(plan, index + 1);
    });
  }

  @override
  void dispose() {
    _nextFaultTimer?.cancel();
    _phaseTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coreColor = Color.lerp(
      AppColors.information.withValues(alpha: .45),
      const Color(0xFFE2F9FF),
      _phase.coreIntensity,
    )!;
    final glowColor = AppColors.information;
    final physicalFrameColor = Color.lerp(
      const Color(0xFF18262C),
      const Color(0xFF24414A),
      _phase.frameReflectionIntensity,
    )!;

    return RepaintBoundary(
      key: const ValueKey('dashboard-neon-brand-mark'),
      child: Semantics(
        label: 'O.R.L.O.',
        child: Container(
          key: const ValueKey('dashboard-neon-physical-sign'),
          height: DashboardNeonTubeGeometry.signHeight,
          width: DashboardNeonTubeGeometry.signWidth,
          padding: const EdgeInsets.symmetric(
            horizontal: DashboardNeonTubeGeometry.signHorizontalPadding,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF07141B),
            borderRadius: BorderRadius.circular(
              DashboardNeonTubeGeometry.physicalFrameRadius,
            ),
            border: Border.all(color: physicalFrameColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(
                  alpha: .035 * _phase.frameReflectionIntensity,
                ),
                blurRadius: 5,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      gradient: RadialGradient(
                        center: const Alignment(.35, 0),
                        radius: 1.25,
                        colors: [
                          glowColor.withValues(
                            alpha: .045 * _phase.frameReflectionIntensity,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: const ValueKey('dashboard-neon-perimeter-tube'),
                    painter: _DashboardNeonPerimeterPainter(
                      intensity: _phase.frameTubeIntensity,
                      outerGlowIntensity: _phase.outerGlowIntensity,
                    ),
                  ),
                ),
              ),
              const _DashboardNeonSignFasteners(),
              Center(
                child: Transform.translate(
                  offset: const Offset(
                    DashboardNeonTubeGeometry.lockupOffsetX,
                    0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: DashboardNeonTubeGeometry.logoSize,
                        width: DashboardNeonTubeGeometry.logoSize,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: .22 * _phase.outerGlowIntensity,
                              child: Image.asset(
                                'assets/icons/orlo_logo_1024_transparent.png',
                                height: DashboardNeonTubeGeometry.logoSize,
                                fit: BoxFit.contain,
                                color: glowColor,
                                colorBlendMode: BlendMode.srcIn,
                              ),
                            ),
                            Opacity(
                              opacity: .78 * _phase.logoIntensity,
                              child: Image.asset(
                                'assets/icons/orlo_logo_1024_transparent.png',
                                key: const ValueKey('dashboard-brand-logo'),
                                height: DashboardNeonTubeGeometry.logoSize,
                                fit: BoxFit.contain,
                                color: coreColor,
                                colorBlendMode: BlendMode.srcIn,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        width: DashboardNeonTubeGeometry.logoWordmarkGap,
                      ),
                      _DashboardNeonTubeWordmark(
                        key: const ValueKey('dashboard-brand-wordmark'),
                        phase: _phase,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fixed vector tubing for the brand wordmark.  ShareTechMono was audited but
/// rejected here because its filled glyphs do not read as a single bent tube.
class _DashboardNeonTubeWordmark extends StatelessWidget {
  const _DashboardNeonTubeWordmark({super.key, required this.phase});

  final DashboardNeonFaultPhase phase;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: DashboardNeonTubeGeometry.wordmarkWidth,
      height: DashboardNeonTubeGeometry.wordmarkHeight,
      child: CustomPaint(
        painter: _DashboardNeonTubeWordmarkPainter(phase: phase),
      ),
    ),
  );
}

/// The perimeter is a separate low-intensity neon tube, inset from the
/// physical frame so the sign retains visible mechanical depth when unlit.
class _DashboardNeonPerimeterPainter extends CustomPainter {
  const _DashboardNeonPerimeterPainter({
    required this.intensity,
    required this.outerGlowIntensity,
  });

  final double intensity;
  final double outerGlowIntensity;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = DashboardNeonTubeGeometry.perimeterInset;
    final insetRect = Rect.fromLTWH(
      inset,
      inset,
      size.width - (inset * 2),
      size.height - (inset * 2),
    );
    final tube = RRect.fromRectAndRadius(
      insetRect,
      const Radius.circular(DashboardNeonTubeGeometry.perimeterRadius),
    );
    const cyan = AppColors.information;

    _stroke(
      canvas,
      tube,
      color: cyan.withValues(alpha: .12 * intensity * outerGlowIntensity),
      width: 4.5,
      blur: 3.5,
    );
    _stroke(
      canvas,
      tube,
      color: cyan.withValues(alpha: .35 * intensity),
      width: 2.1,
      blur: 1.3,
    );
    _stroke(
      canvas,
      tube,
      color: cyan.withValues(alpha: .62 * intensity),
      width: 1.2,
    );
    _stroke(
      canvas,
      tube,
      color: const Color(0xFFE2F9FF).withValues(alpha: .48 * intensity),
      width: .5,
    );
  }

  void _stroke(
    Canvas canvas,
    RRect tube, {
    required Color color,
    required double width,
    double? blur,
  }) {
    canvas.drawRRect(
      tube,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color
        ..isAntiAlias = true
        ..maskFilter = blur == null
            ? null
            : MaskFilter.blur(BlurStyle.normal, blur),
    );
  }

  @override
  bool shouldRepaint(_DashboardNeonPerimeterPainter oldDelegate) =>
      oldDelegate.intensity != intensity ||
      oldDelegate.outerGlowIntensity != outerGlowIntensity;
}

/// A cached, deliberately fixed vector alphabet for the single O.R.L.O.
/// sign.  The paths are invariant; fault phases only repaint light layers.
class _DashboardNeonTubeWordmarkPainter extends CustomPainter {
  const _DashboardNeonTubeWordmarkPainter({required this.phase});

  final DashboardNeonFaultPhase phase;

  static final _tubes = _buildTubes();
  static const _dots = DashboardNeonTubeGeometry.periodCenters;

  static List<Path> _buildTubes() => [
    Path()..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, 2, 12, 18),
        const Radius.circular(2.25),
      ),
    ),
    Path()
      ..moveTo(18, 20)
      ..lineTo(18, 2),
    Path()
      ..moveTo(18, 2)
      ..lineTo(27, 2)
      ..quadraticBezierTo(30, 2, 30, 6)
      ..quadraticBezierTo(30, 10, 27, 10)
      ..lineTo(18, 10),
    Path()
      ..moveTo(22, 10)
      ..lineTo(31, 20),
    Path()
      ..moveTo(35, 2)
      ..lineTo(35, 20)
      ..lineTo(44, 20),
    Path()..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(49, 2, 12, 18),
        const Radius.circular(2.25),
      ),
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const cyan = AppColors.information;
    final hotCore = Color.lerp(cyan, const Color(0xFFE2F9FF), .86)!;

    _drawLayer(
      canvas,
      color: cyan.withValues(alpha: .16 * phase.outerGlowIntensity),
      strokeWidth: 6,
      blur: 6,
    );
    _drawLayer(
      canvas,
      color: cyan.withValues(alpha: .58 * phase.innerGlowIntensity),
      strokeWidth: 3.7,
      blur: 2.1,
    );
    _drawLayer(
      canvas,
      color: cyan.withValues(alpha: .9 * phase.coreIntensity),
      strokeWidth: DashboardNeonTubeGeometry.tubeWidth,
    );
    _drawLayer(
      canvas,
      color: hotCore.withValues(alpha: phase.coreIntensity),
      strokeWidth: DashboardNeonTubeGeometry.hotCoreWidth,
    );
  }

  void _drawLayer(
    Canvas canvas, {
    required Color color,
    required double strokeWidth,
    double? blur,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color
      ..isAntiAlias = true
      ..maskFilter = blur == null
          ? null
          : MaskFilter.blur(BlurStyle.normal, blur);
    for (final path in _tubes) {
      canvas.drawPath(path, paint);
    }
    for (final dot in _dots) {
      canvas.drawCircle(dot, DashboardNeonTubeGeometry.periodRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_DashboardNeonTubeWordmarkPainter oldDelegate) =>
      oldDelegate.phase.coreIntensity != phase.coreIntensity ||
      oldDelegate.phase.innerGlowIntensity != phase.innerGlowIntensity ||
      oldDelegate.phase.outerGlowIntensity != phase.outerGlowIntensity;
}

/// Static mechanical anchors which remain visible when the neon loses power.
class _DashboardNeonSignFasteners extends StatelessWidget {
  const _DashboardNeonSignFasteners();

  @override
  Widget build(BuildContext context) {
    const positions = [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ];
    return IgnorePointer(
      child: Stack(
        children: [
          for (final alignment in positions)
            Align(
              alignment: alignment,
              child: Container(
                width: 2,
                height: 2,
                margin: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Color(0xFF3A4D55),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
