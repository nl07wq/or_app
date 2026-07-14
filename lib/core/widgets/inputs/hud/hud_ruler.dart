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
  double _velocity = 0;
  double _dragSpeed = 0;

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

    _controller.addListener(() {
      if (_dragging) return;

      if (_velocity.abs() < .003) {
        _velocity = 0;
        return;
      }

      _velocity *= .86;

      _displayValue += _velocity;

      widget.onDrag(_displayValue - widget.value);

      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant HUDRuler oldWidget) {
    super.didUpdateWidget(oldWidget);

    setState(() {
      _displayValue += (widget.value - _displayValue) * 0.22;
    });
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
    _dragging = false;

    // ゆっくりドラッグなら慣性なし
    if (_dragSpeed < 0.18) {
      _velocity = 0;
    }

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
            _velocity = 0;
            _startDrag();
          },

          onHorizontalDragUpdate: (details) {
            final delta = details.delta.dx * -0.02;

            _velocity = delta;
            _dragSpeed = delta.abs();

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
