import 'package:flutter/material.dart';

import '../../../core/services/toast_queue.dart';
import '../../../design/theme.dart';

class ToastBanner extends StatelessWidget {
  final ToastData data;
  const ToastBanner({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BuddyTheme.actionPink, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Row(children: [
          Text(data.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.title, style: BuddyTheme.pixel(size: 13, weight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(data.detail, style: BuddyTheme.pixel(size: 11, color: BuddyTheme.darkInk.withValues(alpha: 0.7))),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
