import 'package:flutter/material.dart';

import '../../../design/theme.dart';

/// Joystick analógico. Reporta `Offset(dx, dy)` normalizado a [-1, 1].
class Joystick extends StatefulWidget {
  final ValueChanged<Offset> onChange;
  final double baseSize;
  final double knobSize;

  const Joystick({
    super.key,
    required this.onChange,
    this.baseSize = 96,
    this.knobSize = 44,
  });

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  Offset _knob = Offset.zero;

  double get _maxRadius => (widget.baseSize - widget.knobSize) / 2;

  void _update(Offset delta) {
    final dist = delta.distance;
    final clamped = dist <= _maxRadius ? delta : delta * (_maxRadius / dist);
    setState(() => _knob = clamped);
    widget.onChange(Offset(_knob.dx / _maxRadius, _knob.dy / _maxRadius));
  }

  void _release() {
    setState(() => _knob = Offset.zero);
    widget.onChange(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) {
        final center = Offset(widget.baseSize / 2, widget.baseSize / 2);
        _update(d.localPosition - center);
      },
      onPanUpdate: (d) {
        final center = Offset(widget.baseSize / 2, widget.baseSize / 2);
        _update(d.localPosition - center);
      },
      onPanEnd: (_) => _release(),
      onPanCancel: _release,
      child: SizedBox(
        width: widget.baseSize,
        height: widget.baseSize,
        child: CustomPaint(
          painter: _JoystickPainter(knobOffset: _knob, knobSize: widget.knobSize),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final Offset knobOffset;
  final double knobSize;

  _JoystickPainter({required this.knobOffset, required this.knobSize});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final basePaint = Paint()..color = Colors.white.withValues(alpha: 0.25);
    final baseStroke = Paint()
      ..color = BuddyTheme.darkInk.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, size.width / 2, basePaint);
    canvas.drawCircle(center, size.width / 2 - 1, baseStroke);

    final knobPaint = Paint()..color = BuddyTheme.actionPink;
    final knobStroke = Paint()
      ..color = BuddyTheme.actionPinkDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final knobCenter = center + knobOffset;
    canvas.drawCircle(knobCenter, knobSize / 2, knobPaint);
    canvas.drawCircle(knobCenter, knobSize / 2 - 1, knobStroke);
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter old) =>
      old.knobOffset != knobOffset || old.knobSize != knobSize;
}
