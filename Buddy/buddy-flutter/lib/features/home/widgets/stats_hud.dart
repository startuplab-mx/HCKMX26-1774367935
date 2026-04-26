import 'package:flutter/material.dart';
import '../../../models/pet_stats.dart';
import 'stat_ring.dart';

class StatsHud extends StatelessWidget {
  final PetStats stats;
  const StatsHud({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatRing(
            icon: Icons.restaurant,
            color: const Color(0xFFFFB347),
            value: stats.hunger,
            label: 'Hambre',
          ),
          const SizedBox(width: 10),
          StatRing(
            icon: Icons.bolt,
            color: const Color(0xFF4FC3F7),
            value: stats.energy,
            label: 'Energía',
          ),
          const SizedBox(width: 10),
          StatRing(
            icon: Icons.favorite,
            color: const Color(0xFFE04848),
            value: stats.happiness,
            label: 'Feliz',
          ),
          const SizedBox(width: 10),
          StatRing(
            icon: Icons.water_drop,
            color: const Color(0xFF66BB6A),
            value: stats.hygiene,
            label: 'Limpio',
          ),
        ],
      ),
    );
  }
}
