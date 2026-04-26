import 'package:flutter/material.dart';
import '../../../design/theme.dart';

class HotSpot extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool urgent;

  const HotSpot({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.urgent = false,
  });

  @override
  State<HotSpot> createState() => _HotSpotState();
}

class _HotSpotState extends State<HotSpot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bob,
      builder: (_, __) {
        final dy = _bob.value * -6;
        final glow = widget.urgent ? (0.6 + 0.4 * _bob.value) : 0.0;
        return Transform.translate(
          offset: Offset(0, dy + (_pressed ? 4 : 0)),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) {
              setState(() => _pressed = false);
              widget.onTap();
            },
            onTapCancel: () => setState(() => _pressed = false),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E6),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.urgent
                          ? Colors.redAccent
                          : const Color(0xFF3E2723),
                      width: 4,
                    ),
                    boxShadow: [
                      const BoxShadow(
                        color: Colors.black54,
                        offset: Offset(0, 4),
                        blurRadius: 0,
                      ),
                      if (glow > 0)
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: glow),
                          blurRadius: 18,
                          spreadRadius: 4,
                        ),
                    ],
                  ),
                  child: Icon(
                    widget.icon,
                    color: const Color(0xFF3E2723),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.label,
                    style: BuddyTheme.pixel(
                      size: 11,
                      color: Colors.white,
                      weight: FontWeight.bold,
                    ),
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
