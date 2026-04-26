import 'package:flutter/material.dart';

import '../../../design/theme.dart';
import 'pixel_button.dart';

class TopBar extends StatelessWidget {
  final int coins;
  final int level;
  final VoidCallback onInfo;
  final VoidCallback onSettings;

  const TopBar({
    super.key,
    required this.coins,
    required this.level,
    required this.onInfo,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          PixelButton(
            onTap: () {},
            child: Stack(alignment: Alignment.center, children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8B848),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                width: 8, height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4D470),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Text('$coins', style: BuddyTheme.pixel(size: 18, weight: FontWeight.bold)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: BuddyTheme.buttonBG,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: BuddyTheme.buttonStroke, width: 1.5),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Lv', style: BuddyTheme.pixel(size: 12, color: BuddyTheme.darkInk.withValues(alpha: 0.7))),
              const SizedBox(width: 4),
              Text('$level', style: BuddyTheme.pixel(size: 16, weight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(width: 8),
          PixelButton(
            onTap: onInfo,
            child: Text('i', style: BuddyTheme.pixel(size: 20, weight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          PixelButton(
            onTap: onSettings,
            child: const Text('⚙', style: TextStyle(fontSize: 22)),
          ),
        ],
      ),
    );
  }
}
