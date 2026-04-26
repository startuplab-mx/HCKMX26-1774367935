import 'package:flutter/material.dart';

import '../../../design/theme.dart';
import '../../../models/pet.dart';

class LCDCard extends StatelessWidget {
  final Pet pet;
  const LCDCard({super.key, required this.pet});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 170,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BuddyTheme.lcdOuter,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BuddyTheme.lcdStroke.withValues(alpha: 0.4), width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(),
            const SizedBox(width: 12),
            Container(width: 2, color: BuddyTheme.lcdStroke),
            const SizedBox(width: 12),
            Expanded(child: _stats()),
          ],
        ),
      ),
    );
  }

  Widget _avatar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80, height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: BuddyTheme.lcdStroke, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(pet.character.emoji, style: const TextStyle(fontSize: 36)),
        ),
        const SizedBox(height: 4),
        Row(children: [
          Text(pet.name, style: BuddyTheme.pixel(size: 18, weight: FontWeight.bold, color: BuddyTheme.lcdInk)),
          const SizedBox(width: 4),
          const Text('✏', style: TextStyle(fontSize: 12)),
        ]),
      ],
    );
  }

  Widget _stats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _row('Age', '${pet.ageInDays} Days'),
        _row('Mood', _hearts(pet.moodLevel, 3)),
        _row('Satiety', _dots(pet.satietyLevel, 2)),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: BuddyTheme.pixel(size: 16, color: BuddyTheme.lcdInk)),
        Text(
          value,
          style: BuddyTheme.pixel(
            size: 16,
            color: label == 'Mood' ? const Color(0xFFE04878) : BuddyTheme.lcdInk,
          ),
        ),
      ],
    );
  }

  String _hearts(int filled, int total) =>
      List.generate(total, (i) => i < filled ? '♥' : '♡').join(' ');

  String _dots(int filled, int total) =>
      List.generate(total, (i) => i < filled ? '●' : '○').join(' ');
}
