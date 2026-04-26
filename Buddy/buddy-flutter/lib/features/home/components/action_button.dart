import 'package:flutter/material.dart';

import '../../../design/theme.dart';

class ActionCircleButton extends StatelessWidget {
  final String label;
  final double size;
  final VoidCallback onTap;

  const ActionCircleButton({
    super.key,
    required this.label,
    this.size = 62,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: BuddyTheme.actionPink,
          shape: BoxShape.circle,
          border: Border.all(color: BuddyTheme.actionPinkDark, width: 3),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: BuddyTheme.pixel(
            size: size * 0.42,
            weight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
