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
    this.onMotionCompleted,
    this.onDismiss,
    required this.operationFinished,
    required this.motionFinished,
  });

  final OperationSequenceMode operationMode;
  final OperationSequenceMotion motion;
  final OperationSequenceState operationState;
  final VoidCallback? onMotionCompleted;
  final VoidCallback? onDismiss;
  final bool operationFinished;
  final bool motionFinished;

  /// Inserts a blocking presentation layer while [task] is running. It does
  /// not reinterpret task success; [isSuccess] merely controls the visual
  /// state after that task has already returned its existing result.
  static Future<T> run<T>(
    BuildContext context, {
    required OperationSequenceMode operationMode,
    required Future<T> Function() task,
    bool Function(T result)? isSuccess,
  }) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    // Production always uses the accepted Voxel WALK-IN. MESSAGE ASSEMBLY is
    // intentionally retained for the Animation Sandbox only.
    final state = ValueNotifier(OperationSequenceState.running);
    final operationFinished = ValueNotifier(false);
    final motionFinished = ValueNotifier(false);
    final dismissRequested = Completer<void>();
    var dismissed = false;
    void requestDismiss() {
      if (dismissed || !operationFinished.value) return;
      dismissed = true;
      dismissRequested.complete();
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => ValueListenableBuilder<OperationSequenceState>(
        valueListenable: state,
        builder: (_, operationState, _) => ValueListenableBuilder<bool>(
          valueListenable: operationFinished,
          builder: (_, isOperationFinished, _) => ValueListenableBuilder<bool>(
            valueListenable: motionFinished,
            builder: (_, isMotionFinished, _) => OperationSequenceOverlay(
              operationMode: operationMode,
              motion: OperationSequenceMotion.voxelWalkIn,
              operationState: operationState,
              operationFinished: isOperationFinished,
              motionFinished: isMotionFinished,
              onMotionCompleted: () {
                if (motionFinished.value) return;
                motionFinished.value = true;
              },
              onDismiss: requestDismiss,
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    T? result;
    Object? taskError;
    StackTrace? taskStackTrace;
    unawaited(() async {
      try {
        final value = await task();
        result = value;
        state.value = (isSuccess?.call(value) ?? true)
            ? OperationSequenceState.success
            : OperationSequenceState.failure;
      } catch (error, stackTrace) {
        taskError = error;
        taskStackTrace = stackTrace;
        state.value = OperationSequenceState.failure;
      } finally {
        operationFinished.value = true;
      }
    }());
    // A visual sequence never decides the actual operation result. Once the
    // operation has settled, the user may skip its remaining motion or close
    // the held completed frame. There is deliberately no timed auto-dismiss.
    await dismissRequested.future;
    try {
      if (taskError != null) {
        Error.throwWithStackTrace(taskError!, taskStackTrace!);
      }
      return result as T;
    } finally {
      entry.remove();
      state.dispose();
      operationFinished.dispose();
      motionFinished.dispose();
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
                AspectRatio(
                  aspectRatio: 360 / 280,
                  child: OperationSequenceAnimation(
                    operationMode: widget.operationMode,
                    motion: OperationSequenceMotion.voxelWalkIn,
                    onCompleted: widget.onMotionCompleted,
                    productionVisualOnly: true,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  switch (widget.operationState) {
                    _ when !widget.operationFinished => 'PROCESSING',
                    _ when !widget.motionFinished => 'TAP TO SKIP',
                    _ => 'CLOSE',
                  },
                  style: const TextStyle(
                    color: Color(0xffd8fbff),
                    fontFamily: 'ShareTechMono',
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.operationFinished)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: widget.onDismiss,
                      child: Text(
                        widget.motionFinished ? 'CLOSE' : 'TAP TO SKIP',
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
