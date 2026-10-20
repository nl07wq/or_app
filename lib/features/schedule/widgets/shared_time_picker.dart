import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The single time-selection surface shared by Schedule and Reminder editors.
Future<TimeOfDay?> showSharedTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
}) => showDialog<TimeOfDay>(
  context: context,
  builder: (_) => OperationOrbitalTimePickerDialog(initialTime: initialTime),
);

/// Clock-face conversion kept separate from the dialog so 24:00 can never
/// leak into persisted [TimeOfDay] values.
class OperationOrbitalTimeMapping {
  const OperationOrbitalTimeMapping._();

  static bool isPm(int hour24) => hour24 >= 12;

  static int dialHour(int hour24) {
    final clockHour = hour24 % 12;
    return clockHour == 0 ? 12 : clockHour;
  }

  static int displayHour(int hour24) {
    if (hour24 == 0) return 12;
    if (hour24 == 12) return 24;
    return hour24;
  }

  static int fromDialHour({required int dialHour, required bool pm}) {
    assert(dialHour >= 1 && dialHour <= 12);
    if (pm) return dialHour == 12 ? 12 : dialHour + 12;
    return dialHour == 12 ? 0 : dialHour;
  }
}

enum _OrbitalMode { hour, minute }

class OperationOrbitalTimePickerDialog extends StatefulWidget {
  const OperationOrbitalTimePickerDialog({
    super.key,
    required this.initialTime,
  });

  final TimeOfDay initialTime;

  @override
  State<OperationOrbitalTimePickerDialog> createState() =>
      _OperationOrbitalTimePickerDialogState();
}

class _OperationOrbitalTimePickerDialogState
    extends State<OperationOrbitalTimePickerDialog> {
  late int _hour24;
  late int _minute;
  var _mode = _OrbitalMode.hour;
  var _keyboard = false;
  late final TextEditingController _hourController;
  late final TextEditingController _minuteController;

  bool get _pm => OperationOrbitalTimeMapping.isPm(_hour24);
  int get _dialHour => OperationOrbitalTimeMapping.dialHour(_hour24);
  bool get _validKeyboard {
    final hour = int.tryParse(_hourController.text);
    final minute = int.tryParse(_minuteController.text);
    return hour != null &&
        minute != null &&
        minute >= 0 &&
        minute <= 59 &&
        (_pm ? hour >= 13 && hour <= 24 : hour >= 1 && hour <= 12);
  }

  @override
  void initState() {
    super.initState();
    _hour24 = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _hourController = TextEditingController(
      text: OperationOrbitalTimeMapping.displayHour(_hour24).toString(),
    );
    _minuteController = TextEditingController(
      text: _minute.toString().padLeft(2, '0'),
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _syncInputs() {
    _hourController.text = OperationOrbitalTimeMapping.displayHour(
      _hour24,
    ).toString();
    _minuteController.text = _minute.toString().padLeft(2, '0');
  }

  void _setPeriod(bool pm) {
    if (_pm == pm) return;
    setState(() {
      _hour24 = OperationOrbitalTimeMapping.fromDialHour(
        dialHour: _dialHour,
        pm: pm,
      );
      _syncInputs();
    });
  }

  void _selectDialValue(Offset local, Size size) {
    final delta = local - Offset(size.width / 2, size.height / 2);
    if (delta.distance < size.width * .24) return;
    var angle = math.atan2(delta.dy, delta.dx) + math.pi / 2;
    if (angle < 0) angle += math.pi * 2;
    setState(() {
      if (_mode == _OrbitalMode.hour) {
        final value = (angle / (math.pi * 2) * 12).round() % 12;
        _hour24 = OperationOrbitalTimeMapping.fromDialHour(
          dialHour: value == 0 ? 12 : value,
          pm: _pm,
        );
        _mode = _OrbitalMode.minute;
      } else {
        _minute = (angle / (math.pi * 2) * 60).round() % 60;
      }
      _syncInputs();
    });
  }

  void _toggleKeyboard() => setState(() {
    _keyboard = !_keyboard;
    if (_keyboard) _syncInputs();
  });

  void _confirm() {
    if (_keyboard) {
      if (!_validKeyboard) return;
      final enteredHour = int.parse(_hourController.text);
      _hour24 = OperationOrbitalTimeMapping.fromDialHour(
        dialHour: _pm
            ? (enteredHour == 24 ? 12 : enteredHour - 12)
            : enteredHour,
        pm: _pm,
      );
      _minute = int.parse(_minuteController.text);
    }
    Navigator.of(context).pop(TimeOfDay(hour: _hour24, minute: _minute));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = math.min(media.size.width - 32, 360.0);
    final maxHeight = math.min(
      media.size.height - media.padding.vertical - 24,
      555.0,
    );
    return SafeArea(
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: BoxConstraints.tightFor(
            width: width,
          ).copyWith(maxHeight: maxHeight),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xff071521).withValues(alpha: .96),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xff36c5e5).withValues(alpha: .65),
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 18),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(23),
                border: Border.all(
                  color: const Color(0xff2c7295).withValues(alpha: .22),
                  width: .65,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header(),
                    const SizedBox(height: 4),
                    _readout(),
                    const SizedBox(height: 8),
                    _periodSegment(),
                    const SizedBox(height: 8),
                    _modeCaption(),
                    const SizedBox(height: 5),
                    _keyboard ? _keyboardInput() : _dial(width),
                    const SizedBox(height: 7),
                    _footer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => SizedBox(
    height: 44,
    child: Row(
      children: [
        const Text(
          'SELECT TIME',
          style: TextStyle(
            color: Color(0xff7dddf3),
            fontSize: 15,
            letterSpacing: 1.4,
            fontFamily: 'ShareTechMono',
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Close',
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: Color(0xffb8eafa)),
        ),
      ],
    ),
  );

  Widget _readout() => SizedBox(
    height: 82,
    child: Row(
      children: [
        Expanded(
          child: _ReadoutModule(
            key: const ValueKey('orbital-time-picker-hour'),
            value: OperationOrbitalTimeMapping.displayHour(
              _hour24,
            ).toString().padLeft(2, '0'),
            active: _mode == _OrbitalMode.hour,
            onTap: () => setState(() => _mode = _OrbitalMode.hour),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            ':',
            style: TextStyle(
              color: Color(0xffc6f5ff),
              fontSize: 38,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
        Expanded(
          child: _ReadoutModule(
            key: const ValueKey('orbital-time-picker-minute'),
            value: _minute.toString().padLeft(2, '0'),
            active: _mode == _OrbitalMode.minute,
            onTap: () => setState(() => _mode = _OrbitalMode.minute),
          ),
        ),
      ],
    ),
  );

  Widget _periodSegment() => SizedBox(
    height: 46,
    child: Row(
      children: [
        Expanded(
          child: _PeriodCell(
            key: const ValueKey('orbital-time-picker-am'),
            label: 'AM  /  1–12',
            active: !_pm,
            pm: false,
            onTap: () => _setPeriod(false),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _PeriodCell(
            key: const ValueKey('orbital-time-picker-pm'),
            label: 'PM  /  13–24',
            active: _pm,
            pm: true,
            onTap: () => _setPeriod(true),
          ),
        ),
      ],
    ),
  );

  Widget _modeCaption() => Row(
    children: [
      Expanded(
        child: Container(
          height: 1,
          color: const Color(0xff55cfe9).withValues(alpha: .28),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          _mode == _OrbitalMode.hour ? 'HOUR SELECT' : 'MINUTE SELECT',
          style: const TextStyle(
            color: Color(0xff74def4),
            fontSize: 12,
            letterSpacing: 1.2,
            fontFamily: 'ShareTechMono',
          ),
        ),
      ),
      Expanded(
        child: Container(
          height: 1,
          color: const Color(0xff55cfe9).withValues(alpha: .28),
        ),
      ),
    ],
  );

  Widget _dial(double dialogWidth) {
    final diameter = math.min(254.0, dialogWidth - 34);
    return SizedBox(
      key: const ValueKey('orbital-time-picker-dial'),
      width: diameter,
      height: diameter,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) =>
            _selectDialValue(details.localPosition, Size.square(diameter)),
        onPanUpdate: (details) =>
            _selectDialValue(details.localPosition, Size.square(diameter)),
        child: CustomPaint(
          painter: _OrbitalClockPainter(
            pm: _pm,
            mode: _mode,
            hour: _dialHour,
            minute: _minute,
          ),
        ),
      ),
    );
  }

  Widget _keyboardInput() => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: _NumericInput(
            label: _pm ? 'PM HOUR (13–24)' : 'AM HOUR (1–12)',
            controller: _hourController,
            valid: _validKeyboard,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _NumericInput(
            label: 'MINUTE (00–59)',
            controller: _minuteController,
            valid: _validKeyboard,
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    ),
  );

  Widget _footer() => SizedBox(
    height: 54,
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('orbital-time-picker-keyboard'),
          tooltip: 'Keyboard input',
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          onPressed: _toggleKeyboard,
          icon: Icon(
            _keyboard ? Icons.schedule_rounded : Icons.keyboard_rounded,
            color: const Color(0xff9cdff2),
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        const SizedBox(width: 6),
        FilledButton(
          key: const ValueKey('orbital-time-picker-ok'),
          onPressed: _keyboard && !_validKeyboard ? null : _confirm,
          style: FilledButton.styleFrom(
            minimumSize: const Size(54, 44),
            backgroundColor: const Color(0xff17617b),
            foregroundColor: const Color(0xffe2f8ff),
          ),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class _ReadoutModule extends StatelessWidget {
  const _ReadoutModule({
    super.key,
    required this.value,
    required this.active,
    required this.onTap,
  });
  final String value;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xff0e283b).withValues(alpha: .70),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xff48ccec).withValues(alpha: active ? .95 : .28),
          width: active ? 1.2 : 1,
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Text(
          value,
          key: ValueKey(value),
          style: const TextStyle(
            color: Color(0xffe2f8ff),
            fontSize: 40,
            height: 1,
            fontFamily: 'ShareTechMono',
          ),
        ),
      ),
    ),
  );
}

class _PeriodCell extends StatelessWidget {
  const _PeriodCell({
    super.key,
    required this.label,
    required this.active,
    required this.pm,
    required this.onTap,
  });
  final String label;
  final bool active;
  final bool pm;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final tint = pm ? const Color(0xffbe82f1) : const Color(0xff4de7ee);
    final fill = pm ? const Color(0xff3e2453) : const Color(0xff103e4b);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? fill : const Color(0xff10202d),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: tint.withValues(alpha: active ? .92 : .25),
            width: active ? 1.2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? tint : const Color(0xff88a9b7),
                fontSize: 11,
                letterSpacing: .5,
                fontFamily: 'ShareTechMono',
              ),
            ),
            const SizedBox(height: 3),
            Container(
              height: 1.5,
              width: active ? 32 : 16,
              color: tint.withValues(alpha: active ? .9 : .15),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumericInput extends StatelessWidget {
  const _NumericInput({
    required this.label,
    required this.controller,
    required this.valid,
    required this.onChanged,
  });
  final String label;
  final TextEditingController controller;
  final bool valid;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    keyboardType: TextInputType.number,
    style: const TextStyle(
      color: Color(0xffe2f8ff),
      fontFamily: 'ShareTechMono',
    ),
    decoration: InputDecoration(
      labelText: label,
      errorText: valid ? null : 'Invalid',
      errorStyle: const TextStyle(color: Color(0xffff9cb3)),
    ),
  );
}

class _OrbitalClockPainter extends CustomPainter {
  const _OrbitalClockPainter({
    required this.pm,
    required this.mode,
    required this.hour,
    required this.minute,
  });
  final bool pm;
  final _OrbitalMode mode;
  final int hour;
  final int minute;
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final scale = r / 127;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
      c,
      r * .98,
      paint
        ..color = const Color(0xff2ac8f0).withValues(alpha: .18)
        ..strokeWidth = .8 * scale,
    );
    canvas.drawCircle(
      c,
      r * .88,
      paint
        ..color = const Color(0xff66d9f2).withValues(alpha: .47)
        ..strokeWidth = scale,
    );
    for (final degrees in [20.0, 155.0, 265.0]) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * .88),
        (degrees - 90) * math.pi / 180,
        35 * math.pi / 180,
        false,
        paint
          ..color = const Color(0xffa1f5ff).withValues(alpha: .82)
          ..strokeWidth = 1.65 * scale,
      );
    }
    canvas.drawCircle(
      c,
      r * .70,
      paint
        ..color = const Color(0xff60b3d1).withValues(alpha: .22)
        ..strokeWidth = .7 * scale,
    );
    canvas.drawCircle(
      c,
      r * .55,
      Paint()..color = const Color(0xff0b2538).withValues(alpha: .22),
    );
    for (var i = 0; i < 60; i++) {
      final angle = i * math.pi * 2 / 60 - math.pi / 2;
      final major = i % 5 == 0;
      final outer = c + Offset(math.cos(angle), math.sin(angle)) * r * .79;
      final inner =
          c +
          Offset(math.cos(angle), math.sin(angle)) *
              (r * .79 - (major ? 7 : 3) * scale);
      canvas.drawLine(
        outer,
        inner,
        paint
          ..color = const Color(0xff89dff4).withValues(alpha: major ? .56 : .28)
          ..strokeWidth = major ? 1 : .65,
      );
    }
    final selectedPosition = mode == _OrbitalMode.hour ? hour % 12 : minute;
    final selectedAngle =
        selectedPosition * math.pi * 2 / (mode == _OrbitalMode.hour ? 12 : 60) -
        math.pi / 2;
    final labelRadius = r * .73;
    final node =
        c +
        Offset(math.cos(selectedAngle), math.sin(selectedAngle)) * labelRadius;
    final nodeR = (size.width <= 320 ? 17 : 19) * scale;
    final guideEnd =
        c + (node - c) / (node - c).distance * (labelRadius - nodeR);
    canvas.drawLine(
      c,
      guideEnd,
      paint
        ..color = const Color(0xff5cd9fa).withValues(alpha: .10)
        ..strokeWidth = 3.2 * scale,
    );
    canvas.drawLine(
      c,
      guideEnd,
      paint
        ..color = const Color(0xff80dffb).withValues(alpha: .80)
        ..strokeWidth = 1.5 * scale,
    );
    canvas.drawCircle(
      node,
      nodeR,
      Paint()..color = const Color(0xff185f83).withValues(alpha: .82),
    );
    canvas.drawCircle(
      node,
      nodeR,
      paint
        ..color = const Color(0xff8defff)
        ..strokeWidth = 1.5 * scale,
    );
    canvas.drawCircle(
      c,
      18 * scale,
      paint
        ..color = const Color(0xff72dff8).withValues(alpha: .32)
        ..strokeWidth = .8 * scale,
    );
    canvas.drawCircle(
      c,
      10 * scale,
      paint
        ..color = const Color(0xff8ceafa).withValues(alpha: .48)
        ..strokeWidth = .8 * scale,
    );
    canvas.drawCircle(c, 3.5 * scale, Paint()..color = const Color(0xffbefcff));
    for (var i = 0; i < 6; i++) {
      final angle = (i * 59 + 10) * math.pi / 180;
      final start = c + Offset(math.cos(angle), math.sin(angle)) * r * .91;
      final end =
          c + Offset(math.cos(angle + .08), math.sin(angle + .08)) * r * .99;
      canvas.drawLine(
        start,
        end,
        paint
          ..color = const Color(0xff66d9f2).withValues(alpha: .35)
          ..strokeWidth = .75 * scale,
      );
      canvas.drawCircle(
        end,
        1.1 * scale,
        Paint()..color = const Color(0xff9cf4ff).withValues(alpha: .55),
      );
    }
    final labels = mode == _OrbitalMode.hour
        ? List<int>.generate(12, (i) {
            final h = i == 0 ? 12 : i;
            return pm ? (h == 12 ? 24 : h + 12) : h;
          })
        : List<int>.generate(12, (i) => i * 5);
    for (var i = 0; i < labels.length; i++) {
      final pos = mode == _OrbitalMode.hour ? i : i * 5;
      final angle =
          pos * math.pi * 2 / (mode == _OrbitalMode.hour ? 12 : 60) -
          math.pi / 2;
      final point = c + Offset(math.cos(angle), math.sin(angle)) * labelRadius;
      final text = mode == _OrbitalMode.minute
          ? labels[i].toString().padLeft(2, '0')
          : labels[i].toString();
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: pos == selectedPosition
                ? const Color(0xffe8fdff)
                : const Color(0xff9cdced),
            fontSize: (mode == _OrbitalMode.hour ? 13 : 10.5) * scale,
            fontFamily: 'ShareTechMono',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, point - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitalClockPainter old) =>
      old.pm != pm ||
      old.mode != mode ||
      old.hour != hour ||
      old.minute != minute;
}

TimeOfDay timeOfDayFromClock(
  String? value, {
  TimeOfDay fallback = const TimeOfDay(hour: 9, minute: 0),
}) {
  final parts = value?.split(':');
  if (parts?.length != 2) return fallback;
  final hour = int.tryParse(parts![0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return fallback;
  }
  return TimeOfDay(hour: hour, minute: minute);
}

String clockFromTimeOfDay(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
