import 'dart:async';

import 'package:flutter/material.dart';

import '../pages/boot_send_sequence_sandbox.dart';

export '../pages/boot_send_sequence_sandbox.dart'
    show OperationSequenceMode, OperationSequenceMotion;

enum OperationSequenceState { running, success, failure }

/// A non-mutating production presentation shell for long-running BRIEF,
/// DEBRIEF, and BACKUP operations. The wrapped Future remains the sole owner
/// of persistence, transport, validation, and navigation outcomes.
class OperationSequenceOverlay extends StatefulWidget {
  const OperationSequenceOverlay({
    super.key,
    required this.operationMode,
    required this.motion,
    required this.operationState,
    this.onMotionChanged,
    this.onDismiss,
  });

  final OperationSequenceMode operationMode;
  final OperationSequenceMotion motion;
  final OperationSequenceState operationState;
  final ValueChanged<OperationSequenceMotion>? onMotionChanged;
  final VoidCallback? onDismiss;

  /// Inserts a blocking presentation layer while [task] is running. It does
  /// not reinterpret task success; [isSuccess] merely controls the visual
  /// state after that task has already returned its existing result.
  static Future<T> run<T>(
    BuildContext context, {
    required OperationSequenceMode operationMode,
    required Future<T> Function() task,
    OperationSequenceMotion initialMotion =
        OperationSequenceMotion.messageAssembly,
    bool Function(T result)? isSuccess,
  }) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final state = ValueNotifier(OperationSequenceState.running);
    final motion = ValueNotifier(initialMotion);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => ValueListenableBuilder<OperationSequenceState>(
        valueListenable: state,
        builder: (_, operationState, _) =>
            ValueListenableBuilder<OperationSequenceMotion>(
              valueListenable: motion,
              builder: (_, selectedMotion, _) => OperationSequenceOverlay(
                operationMode: operationMode,
                motion: selectedMotion,
                operationState: operationState,
                onMotionChanged:
                    operationState == OperationSequenceState.running
                    ? (value) => motion.value = value
                    : null,
              ),
            ),
      ),
    );
    overlay.insert(entry);
    try {
      final result = await task();
      state.value = (isSuccess?.call(result) ?? true)
          ? OperationSequenceState.success
          : OperationSequenceState.failure;
      await Future<void>.delayed(const Duration(milliseconds: 180));
      return result;
    } catch (_) {
      state.value = OperationSequenceState.failure;
      await Future<void>.delayed(const Duration(milliseconds: 180));
      rethrow;
    } finally {
      entry.remove();
      state.dispose();
      motion.dispose();
    }
  }

  @override
  State<OperationSequenceOverlay> createState() =>
      _OperationSequenceOverlayState();
}

class _OperationSequenceOverlayState extends State<OperationSequenceOverlay> {
  @override
  void dispose() {
    widget.onDismiss?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xdd050704),
    child: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.operationState == OperationSequenceState.running)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SegmentedButton<OperationSequenceMotion>(
                      segments: const [
                        ButtonSegment(
                          value: OperationSequenceMotion.messageAssembly,
                          label: Text('MESSAGE ASSEMBLY'),
                        ),
                        ButtonSegment(
                          value: OperationSequenceMotion.voxelWalkIn,
                          label: Text('VOXEL WALK-IN'),
                        ),
                      ],
                      selected: {widget.motion},
                      onSelectionChanged: widget.onMotionChanged == null
                          ? null
                          : (value) => widget.onMotionChanged!(value.first),
                    ),
                  ),
                AspectRatio(
                  aspectRatio: 360 / 280,
                  child: OperationSequenceAnimation(
                    operationMode: widget.operationMode,
                    motion: widget.motion,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  switch (widget.operationState) {
                    OperationSequenceState.running => 'PROCESSING',
                    OperationSequenceState.success => 'COMPLETE',
                    OperationSequenceState.failure => 'RETURNING TO RESULT',
                  },
                  style: const TextStyle(
                    color: Color(0xffd8fbff),
                    fontFamily: 'ShareTechMono',
                    fontSize: 12,
                    letterSpacing: 1.2,
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
