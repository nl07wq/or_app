import 'package:flutter/foundation.dart';

import '../models/operation_local_date.dart';

/// A one-shot, in-memory request to present the date change created by a
/// successful DAILY LOG FINALIZE. This is deliberately not Formal state: the
/// canonical operation date is already committed before this is published.
@immutable
class FinalizeDateTransition {
  const FinalizeDateTransition({required this.fromDate, required this.toDate});

  final OperationLocalDate fromDate;
  final OperationLocalDate toDate;
}

/// Transfers the decorative FINALIZE transition across the route boundary.
/// Dashboard takes the value once when it mounts, so rebuilds and later route
/// visits cannot replay a completed transition.
abstract final class FinalizeDateTransitionStore {
  static FinalizeDateTransition? _pending;

  static void publish(FinalizeDateTransition transition) {
    _pending = transition;
  }

  static FinalizeDateTransition? take() {
    final transition = _pending;
    _pending = null;
    return transition;
  }

  @visibleForTesting
  static void resetForTesting() {
    _pending = null;
  }
}
