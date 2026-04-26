import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../design/theme.dart';

class StatRing extends StatefulWidget {
  final IconData icon;
  final Color color;
  final int value; // 0..100
  final double size;
  final String label;

  const StatRing({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.size = 56,
  });

  @override
  State<StatRing> createState() => _StatRingState();
}

class _StatRingState extends State<StatRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late int _displayed;
  Animation<double>? _tween;

  @override
  void initState() {
    super.initState();
    _displayed = widget.value;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.value < 25) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant StatRing old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _tween = Tween<double>(
        begin: old.value.toDouble(),
        end: widget.value.toDouble(),
      ).animate(CurvedAnimation(
        parent: AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 400),
        )..forward(),
        curve: Curves.easeOut,
      ))..addListener(() {
          if (mounted) setState(() => _displayed = _tween!.value.round());
        });
    }
    if (widget.value < 25 && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (widget.value >= 25 && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final scale = 1.0 + _pulse.value * 0.08;
        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: widget.size,
            height: widget.size + 22,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: widget.size,
                      height: widget.size,
                      child: CustomPaint(
                        painter: _RingPainter(
                          value: _displayed / 100.0,
                          color: widget.color,
                        ),
                      ),
                    ),
                    Container(
                      width: widget.size - 16,
                      height: widget.size - 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9E6),
                        border: Border.all(color: const Color(0xFF3E2723), width: 2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        size: widget.size * 0.42,
                        color: widget.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$_displayed',
                  style: BuddyTheme.pixel(
                    size: 11,
                    color: Colors.white,
                    weight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value; // 0..1
  final Color color;
  _RingPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 3;

    final track = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, track);

    final fill = Paint()
      ..color = value < 0.25 ? Colors.redAccent : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final start = -math.pi / 2;
    final sweep = math.pi * 2 * value.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      fill,
    );

    final outer = Paint()
      ..color = const Color(0xFF3E2723)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius + 3, outer);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color;
}
