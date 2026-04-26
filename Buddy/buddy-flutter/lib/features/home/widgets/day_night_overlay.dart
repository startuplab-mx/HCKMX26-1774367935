import 'package:flutter/material.dart';

class DayNightOverlay extends StatelessWidget {
  final DateTime now;
  const DayNightOverlay({super.key, required this.now});

  @override
  Widget build(BuildContext context) {
    final h = now.hour + now.minute / 60.0;
    // Curve: 6h sunrise, 18h sunset.
    // 0..6 night, 6..8 sunrise, 8..18 day, 18..20 sunset, 20..24 night.
    final ({Color top, Color bottom, double opacity}) tint;
    if (h < 6 || h >= 20) {
      tint = (top: const Color(0xFF1A237E), bottom: const Color(0xFF000000), opacity: 0.55);
    } else if (h < 8) {
      final t = (h - 6) / 2;
      tint = (
        top: Color.lerp(const Color(0xFF1A237E), const Color(0xFFFFB74D), t)!,
        bottom: Color.lerp(const Color(0xFF000000), Colors.transparent, t)!,
        opacity: 0.50 - t * 0.45,
      );
    } else if (h < 18) {
      tint = (top: Colors.transparent, bottom: Colors.transparent, opacity: 0.0);
    } else {
      final t = (h - 18) / 2;
      tint = (
        top: Color.lerp(const Color(0xFFFF6F00), const Color(0xFF1A237E), t)!,
        bottom: Color.lerp(Colors.transparent, const Color(0xFF000000), t)!,
        opacity: 0.10 + t * 0.45,
      );
    }
    if (tint.opacity == 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              tint.top.withValues(alpha: tint.opacity),
              tint.bottom.withValues(alpha: tint.opacity),
            ],
          ),
        ),
      ),
    );
  }
}
