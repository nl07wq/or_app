import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../base_camp_dashboard_page.dart' show BaseCampLcdGrainPainter;

enum BaseCampCommunicationKind {
  dailyBrief,
  dailyDebrief,
  weeklyReport,
  monthlyReport,
  yearlyReport,
  backup,
}

enum BaseCampCommunicationPhase { running, success }

enum BaseCampCommunicationEndpoint { documentToComputer, folderToServer }

const baseCampCommunicationFrameDuration = Duration(milliseconds: 200);
const baseCampCommunicationConnectingDuration = Duration(milliseconds: 300);
const baseCampCommunicationTransferDuration = Duration(milliseconds: 1200);
const baseCampCommunicationCompletionHold = Duration(milliseconds: 1000);
const baseCampCommunicationMinimumDisplay = Duration(milliseconds: 2500);

const baseCampCommunicationAssetRoot =
    'assets/images/themes/base_camp/communication';
const baseCampCommunicationDocumentAsset =
    '$baseCampCommunicationAssetRoot/document.svg';
const baseCampCommunicationComputerIdleAsset =
    '$baseCampCommunicationAssetRoot/computer_idle.svg';
const baseCampCommunicationComputerCompleteAsset =
    '$baseCampCommunicationAssetRoot/computer_complete.svg';
const baseCampCommunicationFolderAsset =
    '$baseCampCommunicationAssetRoot/folder.svg';
const baseCampCommunicationServerIdleAsset =
    '$baseCampCommunicationAssetRoot/server_idle.svg';
const baseCampCommunicationServerCompleteAsset =
    '$baseCampCommunicationAssetRoot/server_complete.svg';
const baseCampCommunicationArrowIdleAsset =
    '$baseCampCommunicationAssetRoot/arrow_idle.svg';
const baseCampCommunicationArrowActiveAsset =
    '$baseCampCommunicationAssetRoot/arrow_active.svg';
const baseCampCommunicationStatusRunningAsset =
    '$baseCampCommunicationAssetRoot/status_strip_running.svg';
const baseCampCommunicationStatusCompleteAsset =
    '$baseCampCommunicationAssetRoot/status_strip_complete.svg';

const baseCampCommunicationAssets = <String>[
  baseCampCommunicationDocumentAsset,
  baseCampCommunicationComputerIdleAsset,
  baseCampCommunicationComputerCompleteAsset,
  baseCampCommunicationFolderAsset,
  baseCampCommunicationServerIdleAsset,
  baseCampCommunicationServerCompleteAsset,
  baseCampCommunicationArrowIdleAsset,
  baseCampCommunicationArrowActiveAsset,
  baseCampCommunicationStatusRunningAsset,
  baseCampCommunicationStatusCompleteAsset,
];

Future<void> prepareBaseCampCommunicationAssets(BuildContext context) =>
    Future.wait<void>([
      for (final asset in baseCampCommunicationAssets)
        SvgAssetLoader(asset).loadBytes(context).then<void>((_) {}),
    ]);

BaseCampCommunicationEndpoint baseCampCommunicationEndpoint(
  BaseCampCommunicationKind kind,
) => kind == BaseCampCommunicationKind.backup
    ? BaseCampCommunicationEndpoint.folderToServer
    : BaseCampCommunicationEndpoint.documentToComputer;

String baseCampCommunicationSourceAsset(BaseCampCommunicationKind kind) =>
    kind == BaseCampCommunicationKind.backup
    ? baseCampCommunicationFolderAsset
    : baseCampCommunicationDocumentAsset;

String baseCampCommunicationDestinationIdleAsset(
  BaseCampCommunicationKind kind,
) => kind == BaseCampCommunicationKind.backup
    ? baseCampCommunicationServerIdleAsset
    : baseCampCommunicationComputerIdleAsset;

String baseCampCommunicationDestinationCompleteAsset(
  BaseCampCommunicationKind kind,
) => kind == BaseCampCommunicationKind.backup
    ? baseCampCommunicationServerCompleteAsset
    : baseCampCommunicationComputerCompleteAsset;

String baseCampCommunicationTitle(BaseCampCommunicationKind kind) =>
    switch (kind) {
      BaseCampCommunicationKind.dailyBrief => 'DAILY BRIEF',
      BaseCampCommunicationKind.dailyDebrief => 'DAILY DEBRIEF',
      BaseCampCommunicationKind.weeklyReport => 'WEEKLY REPORT',
      BaseCampCommunicationKind.monthlyReport => 'MONTHLY REPORT',
      BaseCampCommunicationKind.yearlyReport => 'YEARLY REPORT',
      BaseCampCommunicationKind.backup => 'ARK BACKUP',
    };

String baseCampCommunicationStatus(
  BaseCampCommunicationKind kind,
  BaseCampCommunicationPhase phase,
) => switch ((kind, phase)) {
  (BaseCampCommunicationKind.dailyBrief, BaseCampCommunicationPhase.running) ||
  (
    BaseCampCommunicationKind.dailyDebrief,
    BaseCampCommunicationPhase.running,
  ) ||
  (
    BaseCampCommunicationKind.weeklyReport,
    BaseCampCommunicationPhase.running,
  ) ||
  (
    BaseCampCommunicationKind.monthlyReport,
    BaseCampCommunicationPhase.running,
  ) ||
  (
    BaseCampCommunicationKind.yearlyReport,
    BaseCampCommunicationPhase.running,
  ) => 'RECEIVING...',
  (BaseCampCommunicationKind.dailyBrief, BaseCampCommunicationPhase.success) ||
  (
    BaseCampCommunicationKind.dailyDebrief,
    BaseCampCommunicationPhase.success,
  ) ||
  (
    BaseCampCommunicationKind.weeklyReport,
    BaseCampCommunicationPhase.success,
  ) ||
  (
    BaseCampCommunicationKind.monthlyReport,
    BaseCampCommunicationPhase.success,
  ) ||
  (
    BaseCampCommunicationKind.yearlyReport,
    BaseCampCommunicationPhase.success,
  ) => 'RECEIVED',
  (BaseCampCommunicationKind.backup, BaseCampCommunicationPhase.running) =>
    'ARCHIVING...',
  (BaseCampCommunicationKind.backup, BaseCampCommunicationPhase.success) =>
    'COMPLETE',
};

/// Runs a BASE CAMP-only presentation after an existing operation succeeds.
///
/// The operation remains the sole source of truth. Failed, cancelled, or
/// rejected operations return without inserting a success presentation.
abstract final class BaseCampCommunicationOverlay {
  static Future<T> run<T>(
    BuildContext context, {
    required BaseCampCommunicationKind kind,
    required Future<T> Function() task,
    bool Function(T result)? isSuccess,
  }) async {
    final result = await task();
    if (!(isSuccess?.call(result) ?? true)) return result;
    if (!context.mounted) return result;

    await prepareBaseCampCommunicationAssets(context);
    if (!context.mounted) return result;
    final overlay = Overlay.of(context, rootOverlay: true);
    final phase = ValueNotifier(BaseCampCommunicationPhase.running);
    final entry = OverlayEntry(
      builder: (_) => ValueListenableBuilder<BaseCampCommunicationPhase>(
        valueListenable: phase,
        builder: (_, value, _) =>
            BaseCampCommunicationMotion(kind: kind, phase: value),
      ),
    );
    overlay.insert(entry);
    try {
      await Future<void>.delayed(
        baseCampCommunicationConnectingDuration +
            baseCampCommunicationTransferDuration,
      );
      phase.value = BaseCampCommunicationPhase.success;
      await Future<void>.delayed(baseCampCommunicationCompletionHold);
      return result;
    } finally {
      entry.remove();
      phase.dispose();
    }
  }
}

class BaseCampCommunicationMotion extends StatefulWidget {
  const BaseCampCommunicationMotion({
    super.key,
    required this.kind,
    required this.phase,
  });

  final BaseCampCommunicationKind kind;
  final BaseCampCommunicationPhase phase;

  @override
  State<BaseCampCommunicationMotion> createState() =>
      _BaseCampCommunicationMotionState();
}

class _BaseCampCommunicationMotionState
    extends State<BaseCampCommunicationMotion> {
  Timer? _connectingTimer;
  Timer? _transferTimer;
  int _frame = 0;
  bool _connecting = true;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(BaseCampCommunicationMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase || oldWidget.kind != widget.kind) {
      _syncTimer();
    }
  }

  void _syncTimer() {
    _connectingTimer?.cancel();
    _transferTimer?.cancel();
    if (widget.phase == BaseCampCommunicationPhase.success) {
      _connecting = false;
      _frame = 4;
      return;
    }
    _connecting = true;
    _frame = 0;
    _connectingTimer = Timer(baseCampCommunicationConnectingDuration, () {
      if (!mounted || widget.phase == BaseCampCommunicationPhase.success) {
        return;
      }
      setState(() {
        _connecting = false;
        _frame = 0;
      });
      _transferTimer = Timer.periodic(baseCampCommunicationFrameDuration, (_) {
        if (!mounted || widget.phase == BaseCampCommunicationPhase.success) {
          return;
        }
        setState(() => _frame = (_frame + 1) % 4);
      });
    });
  }

  @override
  void dispose() {
    _connectingTimer?.cancel();
    _transferTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const phosphor = Color(0xffb8cf72);
    const housing = Color(0xff171d13);
    const frame = Color(0xff6e7b4c);
    const lcd = Color(0xff232d1b);
    final complete = widget.phase == BaseCampCommunicationPhase.success;
    final status = _connecting && !complete
        ? 'CONNECTING...'
        : baseCampCommunicationStatus(widget.kind, widget.phase);

    return Material(
      color: const Color(0xe6080b07),
      child: SafeArea(
        child: Center(
          child: FractionallySizedBox(
            widthFactor: .9,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
                key: const ValueKey('base-camp-communication-housing'),
                decoration: BoxDecoration(
                  color: housing,
                  border: Border.all(color: frame, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 10),
                  ],
                ),
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: _CommunicationScrews(color: frame),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: lcd,
                          border: Border.all(color: frame),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  18,
                                  14,
                                  14,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      baseCampCommunicationTitle(widget.kind),
                                      key: const ValueKey(
                                        'base-camp-communication-title',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: phosphor,
                                        fontFamily: 'PressStart2P',
                                        fontSize: 12,
                                        height: 1.35,
                                        letterSpacing: -.4,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    SizedBox(
                                      key: ValueKey(
                                        'base-camp-communication-frame-$_frame',
                                      ),
                                      height: 64,
                                      width: double.infinity,
                                      child: _CommunicationTransferDisplay(
                                        kind: widget.kind,
                                        activeArrowCount: complete
                                            ? 3
                                            : _connecting
                                            ? 0
                                            : _frame,
                                        complete: complete,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _CommunicationStatusStrip(
                                      complete: complete,
                                      status: status,
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      key: ValueKey(
                                        'base-camp-communication-vent',
                                      ),
                                      width: double.infinity,
                                      height: 8,
                                      child: CustomPaint(
                                        painter:
                                            BaseCampCommunicationVentPainter(
                                              color: Color(0xff4e5f37),
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Positioned.fill(
                                child: IgnorePointer(
                                  key: ValueKey(
                                    'base-camp-communication-lcd-grid',
                                  ),
                                  child: CustomPaint(
                                    painter: BaseCampLcdGrainPainter(
                                      negative: true,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommunicationTransferDisplay extends StatelessWidget {
  const _CommunicationTransferDisplay({
    required this.kind,
    required this.activeArrowCount,
    required this.complete,
  });

  final BaseCampCommunicationKind kind;
  final int activeArrowCount;
  final bool complete;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      _CommunicationSvg(
        key: const ValueKey('base-camp-communication-source'),
        asset: baseCampCommunicationSourceAsset(kind),
        size: 64,
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < 3; index++) ...[
            if (index > 0) const SizedBox(width: 6),
            _CommunicationSvgSwitch(
              switchKey: 'base-camp-communication-arrow-$index',
              idleAsset: baseCampCommunicationArrowIdleAsset,
              activeAsset: baseCampCommunicationArrowActiveAsset,
              active: index < activeArrowCount,
              size: 20,
            ),
          ],
        ],
      ),
      _CommunicationSvgSwitch(
        switchKey: 'base-camp-communication-destination',
        idleAsset: baseCampCommunicationDestinationIdleAsset(kind),
        activeAsset: baseCampCommunicationDestinationCompleteAsset(kind),
        active: complete,
        size: 64,
      ),
    ],
  );
}

class _CommunicationStatusStrip extends StatelessWidget {
  const _CommunicationStatusStrip({
    required this.complete,
    required this.status,
  });

  final bool complete;
  final String status;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth.clamp(0.0, 256.0);
      return Align(
        child: SizedBox(
          key: const ValueKey('base-camp-communication-status-strip-surface'),
          width: width,
          height: width * 30 / 256,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _CommunicationSvgSwitch(
                switchKey: 'base-camp-communication-status-strip',
                idleAsset: baseCampCommunicationStatusRunningAsset,
                activeAsset: baseCampCommunicationStatusCompleteAsset,
                active: complete,
              ),
              Center(
                child: Text(
                  status,
                  key: const ValueKey('base-camp-communication-status'),
                  style: TextStyle(
                    color: complete
                        ? const Color(0xff17251a)
                        : const Color(0xffb8cf72),
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                    height: 1.2,
                    letterSpacing: -.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _CommunicationSvgSwitch extends StatelessWidget {
  const _CommunicationSvgSwitch({
    required this.switchKey,
    required this.idleAsset,
    required this.activeAsset,
    required this.active,
    this.size,
  });

  final String switchKey;
  final String idleAsset;
  final String activeAsset;
  final bool active;
  final double? size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          key: ValueKey('$switchKey-idle'),
          opacity: active ? 0 : 1,
          child: _CommunicationSvg(asset: idleAsset),
        ),
        Opacity(
          key: ValueKey('$switchKey-active'),
          opacity: active ? 1 : 0,
          child: _CommunicationSvg(asset: activeAsset),
        ),
      ],
    ),
  );
}

class _CommunicationSvg extends StatelessWidget {
  const _CommunicationSvg({super.key, required this.asset, this.size});

  final String asset;
  final double? size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: SvgPicture.asset(
      asset,
      key: ValueKey('base-camp-communication-svg-$asset'),
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
  );
}

@visibleForTesting
class BaseCampCommunicationVentPainter extends CustomPainter {
  const BaseCampCommunicationVentPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..isAntiAlias = false;
    const pitch = 8.0;
    for (var x = -size.height; x < size.width; x += pitch) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BaseCampCommunicationVentPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CommunicationScrews extends StatelessWidget {
  const _CommunicationScrews({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      for (final alignment in const [
        Alignment.topLeft,
        Alignment.topRight,
        Alignment.bottomLeft,
        Alignment.bottomRight,
      ])
        Align(
          alignment: alignment,
          child: Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
    ],
  );
}
