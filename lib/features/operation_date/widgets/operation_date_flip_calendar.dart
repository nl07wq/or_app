import 'package:flutter/material.dart';

import '../../../core/widgets/operation_flip_tile.dart';
import '../models/operation_local_date.dart';

class OperationDateFlipCalendar extends StatefulWidget {
  const OperationDateFlipCalendar({
    required this.operationDateFuture,
    required this.transitionToken,
    super.key,
    this.onDateDisplayed,
    this.tileWidth = defaultTileWidth,
    this.tileHeight = defaultTileHeight,
    this.tileGap = defaultTileGap,
  });

  static const defaultTileWidth = 52.0;
  static const defaultTileHeight = 36.0;
  static const defaultTileGap = 6.0;
  static const maximumTransitionDuration = Duration(milliseconds: 440);

  final Future<OperationLocalDate> operationDateFuture;
  final int transitionToken;
  final ValueChanged<OperationLocalDate>? onDateDisplayed;
  final double tileWidth;
  final double tileHeight;
  final double tileGap;

  @override
  State<OperationDateFlipCalendar> createState() =>
      _OperationDateFlipCalendarState();
}

class _OperationDateFlipCalendarState extends State<OperationDateFlipCalendar> {
  OperationLocalDate? _displayedDate;
  int _consumedTransitionToken = 0;

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: widget.operationDateFuture,
    builder: (context, snapshot) {
      var animate = false;
      if (snapshot.connectionState == ConnectionState.done &&
          snapshot.hasData) {
        final nextDate = snapshot.requireData;
        animate =
            widget.transitionToken != _consumedTransitionToken &&
            _displayedDate != null &&
            _displayedDate != nextDate;
        _displayedDate = nextDate;
        _consumedTransitionToken = widget.transitionToken;
        final onDateDisplayed = widget.onDateDisplayed;
        if (onDateDisplayed != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) onDateDisplayed(nextDate);
          });
        }
      }
      final date = _displayedDate;
      return date == null
          ? Text('LOADING...', style: Theme.of(context).textTheme.titleSmall)
          : _OperationDateFlipRow(
              date: date,
              animate: animate,
              tileWidth: widget.tileWidth,
              tileHeight: widget.tileHeight,
              tileGap: widget.tileGap,
            );
    },
  );
}

class _OperationDateFlipRow extends StatefulWidget {
  const _OperationDateFlipRow({
    required this.date,
    required this.animate,
    required this.tileWidth,
    required this.tileHeight,
    required this.tileGap,
  });

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

  final OperationLocalDate date;
  final bool animate;
  final double tileWidth;
  final double tileHeight;
  final double tileGap;

  @override
  State<_OperationDateFlipRow> createState() => _OperationDateFlipRowState();
}

class _OperationDateFlipRowState extends State<_OperationDateFlipRow> {
  Map<int, Duration> _startDelays = const {};

  @override
  void didUpdateWidget(covariant _OperationDateFlipRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animate || oldWidget.date == widget.date) {
      _startDelays = const {};
      return;
    }
    final previousValues = _values(oldWidget.date);
    final nextValues = _values(widget.date);
    final changedIndices = [
      for (var index = 0; index < nextValues.length; index++)
        if (previousValues[index] != nextValues[index]) index,
    ];
    _startDelays = {
      for (var order = 0; order < changedIndices.length; order++)
        changedIndices[order]: OperationMechanicalFlipTile.stagger * order,
    };
  }

  @override
  Widget build(BuildContext context) {
    final values = _values(widget.date);
    return Semantics(
      label: 'OPERATION DATE ${widget.date.value}',
      child: ExcludeSemantics(
        child: Row(
          key: const ValueKey('operation-date-flip-row'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < values.length; index++) ...[
              if (index > 0) SizedBox(width: widget.tileGap),
              OperationMechanicalFlipTile(
                key: ValueKey('operation-date-tile-$index'),
                value: values[index],
                width: widget.tileWidth,
                height: widget.tileHeight,
                animate: widget.animate,
                startDelay: _startDelays[index] ?? Duration.zero,
                animationDuration: index == 1
                    ? OperationMechanicalFlipTile.dayDuration
                    : OperationMechanicalFlipTile.duration,
                firstPhaseRatio: index == 1
                    ? OperationMechanicalFlipTile.dayFirstPhaseRatio
                    : OperationMechanicalFlipTile.defaultFirstPhaseRatio,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _values(OperationLocalDate date) {
    final parsed = date.asUtcDate;
    return [
      _OperationDateFlipRow._months[parsed.month - 1],
      parsed.day.toString().padLeft(2, '0'),
      _OperationDateFlipRow._weekdays[parsed.weekday - 1],
    ];
  }
}
