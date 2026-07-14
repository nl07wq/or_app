import 'package:flutter/material.dart';

import 'hud_scale.dart';
import 'hud_state.dart';
import 'hud_value.dart';

class HUDRuler extends StatefulWidget {
  final double value;
  final String unit;
  final ValueChanged<double> onDrag;

  const HUDRuler({
    super.key,
    required this.value,
    required this.unit,
    required this.onDrag,
  });

  @override
  State<HUDRuler> createState() => _HUDRulerState();
}

class _HUDRulerState extends State<HUDRuler> with TickerProviderStateMixin {
  late final AnimationController _controller;

  bool _dragging = false;

  HUDState _state = HUDState.idle;

  double _displayValue = 0;
  
  double _lastLockValue = 0;

  @override
  void initState() {
    super.initState();

    _displayValue = widget.value;
    _lastLockValue = widget.value;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      lowerBound: 0,
      upperBound: 1,
    );
  }

  @override
  void didUpdateWidget(covariant HUDRuler oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_dragging) return;

    _displayValue = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startDrag() {
    _dragging = true;
    _state = HUDState.drag;
    _controller.forward();

    setState(() {});
  }

  void _endDrag() {
    _displayValue = widget.value;

    _dragging = false;

    _state = HUDState.locked;
    _controller.reverse();

    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;

      setState(() {
        _state = HUDState.idle;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),

        HUDValue(value: _displayValue, unit: widget.unit),

        GestureDetector(
          behavior: HitTestBehavior.opaque,

          onHorizontalDragStart: (_) {
            _startDrag();
          },

          onHorizontalDragUpdate: (details) {
            final delta = details.delta.dx * -0.012;

            _displayValue += delta;

            widget.onDrag(delta);

            final current = (_displayValue * 10).round();
            final last = (_lastLockValue * 10).round();

            if (current != last) {
              _lastLockValue = _displayValue;

              _state = HUDState.locked;

              Future.delayed(const Duration(milliseconds: 100), () {
                if (!mounted || _dragging) return;

                setState(() {
                  _state = HUDState.drag;
                });
              });
            }

            setState(() {});
          },

          onHorizontalDragEnd: (_) {
            _endDrag();
          },

          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              return HUDScale(
                value: _displayValue,
                animation: _controller.value,
                state: _state,
              );
            },
          ),
        ),
      ],
    );
  }
}
