import 'package:flutter/material.dart';

import '../../../design/theme.dart';

class PixelButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const PixelButton({super.key, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: BuddyTheme.buttonBG,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BuddyTheme.buttonStroke, width: 2),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
